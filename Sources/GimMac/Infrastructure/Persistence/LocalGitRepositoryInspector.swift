import Foundation

final class LocalGitRepositoryInspector: RepositoryInspecting {
    private let gitClient: GitClientProtocol
    private let logger: (any AppLogging)?

    init(gitClient: GitClientProtocol, logger: (any AppLogging)? = nil) {
        self.gitClient = gitClient
        self.logger = logger
    }

    func inspectRepository(at url: URL) async throws -> RepositoryInspectionResult {
        let startedAt = Self.nowMilliseconds()
        let tag = logger?.tag("repository.inspect", parent: nil, metadata: [
            "repository": url.lastPathComponent,
            "path": url.path
        ])
        logger?.debug(
            "Repository inspector started",
            category: .repository,
            metadata: ["repository": url.lastPathComponent, "path": url.path],
            tag: tag
        )

        let typeResult = await runInspectionCommand(
            ["rev-parse", "--is-bare-repository", "--show-cdup", "--git-dir"],
            in: url,
            timeout: 5,
            step: "repository-type",
            tag: tag
        )
        var gitDir: String?
        var worktreePrefix: String?
        if let typeResult {
            logger?.debug(
                "Repository inspector parsed repository type",
                category: .repository,
                metadata: [
                    "repository": url.lastPathComponent,
                    "stdout_bytes": String(typeResult.stdout.utf8.count),
                    "stderr_bytes": String(typeResult.stderr.utf8.count),
                    "exit_code": String(typeResult.exitCode)
                ],
                tag: tag
            )
            if typeResult.exitCode == 128 && typeResult.stderr.contains("dubious ownership") {
                logFinished(url: url, outcome: "unsafe", startedAt: startedAt, tag: tag)
                throw GitAppError.unsafeRepository(path: url.path)
            }
            let lines = typeResult.stdout.components(separatedBy: "\n")
            let isBare = lines.first == "true"
            worktreePrefix = lines.dropFirst().first?.nonEmpty
            gitDir = lines.dropFirst(2).first?.nonEmpty
            if isBare {
                logFinished(url: url, outcome: "bare", startedAt: startedAt, tag: tag)
                throw GitAppError.bareRepository
            }
            if typeResult.exitCode != 0 || typeResult.stdout.isEmpty {
                logFinished(url: url, outcome: "not-a-repository", startedAt: startedAt, tag: tag)
                throw GitAppError.notARepository
            }
        }

        let headStateResult = await runInspectionCommand(
            ["status", "--porcelain=v2", "--branch", "--untracked-files=no"],
            in: url,
            timeout: 10,
            step: "head-state",
            tag: tag
        )
        let headState = Self.parseHeadState(headStateResult?.stdout ?? "")
        let branch = headState.branch
        logger?.debug(
            "Repository inspector parsed branch",
            category: .repository,
            metadata: ["repository": url.lastPathComponent, "branch": branch],
            tag: tag
        )

        let headHash = headState.headSHA
        logger?.debug(
            "Repository inspector parsed HEAD",
            category: .repository,
            metadata: [
                "repository": url.lastPathComponent,
                "has_head": String(headHash != nil),
                "branch": branch
            ],
            tag: tag
        )

        if !branch.isEmpty, let sha = headHash {
            logFinished(url: url, outcome: "valid", startedAt: startedAt, tag: tag)
            return result(
                tip: .valid(branch: BranchSummary(name: branch, upstream: nil, sha: sha)),
                branchName: branch,
                headSHA: sha,
                context: .init(gitDir: gitDir, isBare: false, worktreePrefix: worktreePrefix, url: url)
            )
        }

        if !branch.isEmpty, headHash == nil {
            logFinished(url: url, outcome: "unborn-branch", startedAt: startedAt, tag: tag)
            return result(
                tip: .unborn(ref: branch),
                branchName: branch,
                headSHA: nil,
                context: .init(gitDir: gitDir, isBare: false, worktreePrefix: worktreePrefix, url: url)
            )
        }

        if branch.isEmpty, let sha = headHash {
            // Carry the full SHA in the model (matches GitHub Desktop's
            // IDetachedHead.currentSha); the branch UI shortens it for display.
            logFinished(url: url, outcome: "detached", startedAt: startedAt, tag: tag)
            return result(
                tip: .detached(sha: sha),
                branchName: nil,
                headSHA: sha,
                context: .init(gitDir: gitDir, isBare: false, worktreePrefix: worktreePrefix, url: url)
            )
        }

        if let symRef = await runInspectionCommand(
            ["symbolic-ref", "HEAD"],
            in: url,
            timeout: 5,
            step: "symbolic-head",
            tag: tag
        ) {
            let ref = symRef.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if ref.hasPrefix("refs/heads/") {
                let branchName = String(ref.dropFirst("refs/heads/".count))
                logFinished(url: url, outcome: "unborn-symbolic-ref", startedAt: startedAt, tag: tag)
                return result(
                    tip: .unborn(ref: branchName),
                    branchName: branchName,
                    headSHA: nil,
                    context: .init(gitDir: gitDir, isBare: false, worktreePrefix: worktreePrefix, url: url)
                )
            }
        }

        logFinished(url: url, outcome: "invalid-output", startedAt: startedAt, tag: tag)
        throw GitAppError.invalidOutput(command: ["branch", "--show-current"], details: "Cannot determine HEAD state")
    }

    private func runInspectionCommand(
        _ arguments: [String],
        in url: URL,
        timeout: TimeInterval,
        step: String,
        tag: LogFlowTag?
    ) async -> GitCommandResult? {
        let startedAt = Self.nowMilliseconds()
        logger?.debug(
            "Repository inspector command await started",
            category: .repository,
            metadata: [
                "repository": url.lastPathComponent,
                "step": step,
                "command": "git " + arguments.joined(separator: " ")
            ],
            tag: tag
        )

        do {
            let result = try await gitClient.run(arguments, in: url, priority: .userInteractive, timeout: timeout)
            logger?.debug(
                "Repository inspector command await finished",
                category: .repository,
                metadata: [
                    "repository": url.lastPathComponent,
                    "step": step,
                    "exit_code": String(result.exitCode),
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
            return result
        } catch {
            logger?.debug(
                "Repository inspector command await failed",
                category: .repository,
                metadata: [
                    "repository": url.lastPathComponent,
                    "step": step,
                    "reason": error.localizedDescription,
                    "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
                ],
                tag: tag
            )
            return nil
        }
    }

    private func logFinished(url: URL, outcome: String, startedAt: Double, tag: LogFlowTag?) {
        logger?.info(
            "Repository inspector finished",
            category: .repository,
            metadata: [
                "repository": url.lastPathComponent,
                "outcome": outcome,
                "duration_ms": Self.formatMilliseconds(Self.elapsedMilliseconds(since: startedAt))
            ],
            tag: tag
        )
    }

    private func result(
        tip: TipState,
        branchName: String?,
        headSHA: String?,
        context: InspectionResultContext
    ) -> RepositoryInspectionResult {
        let worktreeRoot: URL?
        if let worktreePrefix = context.worktreePrefix, !worktreePrefix.isEmpty {
            worktreeRoot = context.url.appendingPathComponent(worktreePrefix).standardizedFileURL
        } else {
            worktreeRoot = context.url.standardizedFileURL
        }

        return RepositoryInspectionResult(
            tip: tip,
            branchName: branchName,
            headSHA: headSHA,
            gitDir: context.gitDir,
            isBare: context.isBare,
            worktreeRoot: worktreeRoot,
            inspectedAt: Date()
        )
    }

    private struct InspectionResultContext {
        let gitDir: String?
        let isBare: Bool
        let worktreePrefix: String?
        let url: URL
    }

    private static func nowMilliseconds() -> Double {
        ProcessInfo.processInfo.systemUptime * 1_000
    }

    private static func elapsedMilliseconds(since startedAt: Double) -> Double {
        max(0, nowMilliseconds() - startedAt)
    }

    private static func formatMilliseconds(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
    }

    private static func parseHeadState(_ stdout: String) -> HeadState {
        var branch = ""
        var headSHA: String?
        for line in stdout.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("# branch.head ") {
                let value = String(line.dropFirst("# branch.head ".count))
                branch = value == "(detached)" ? "" : value
            } else if line.hasPrefix("# branch.oid ") {
                let value = String(line.dropFirst("# branch.oid ".count))
                headSHA = value == "(initial)" ? nil : value.nonEmpty
            }
        }
        return HeadState(branch: branch, headSHA: headSHA)
    }

    private struct HeadState {
        let branch: String
        let headSHA: String?
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
