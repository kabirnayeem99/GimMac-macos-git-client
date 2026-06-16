import Foundation

/// Stages selected paths and creates a commit. Handles amend, co-author trailers,
/// hook skipping, and sign-off without changing Git's default message behavior.
final class GitCommitProvider: CommitProviding, Sendable {
    private let client: GitClientProtocol
    private let logger: any AppLogging

    init(client: GitClientProtocol, logger: any AppLogging) {
        self.client = client
        self.logger = logger
    }

    func commit(
        in repositoryURL: URL,
        paths: [String],
        summary: String,
        description: String?,
        options: CommitOptions
    ) async throws {
        let normalizedPaths = Array(Set(paths)).sorted()
        guard options.isAmend || !normalizedPaths.isEmpty else { return }

        logger.info(
            "Staging \(normalizedPaths.count) file(s)",
            category: .staging,
            metadata: ["repository": repositoryURL.lastPathComponent, "amend": "\(options.isAmend)"]
        )

        var stagedPaths: [String] = []
        var failedPaths: [String] = []
        for path in normalizedPaths {
            do {
                _ = try await client.run(["add", "-A", "--", path], in: repositoryURL, timeout: 15)
                stagedPaths.append(path)
                logger.debug("Staged", category: .staging, metadata: ["path": path])
            } catch {
                failedPaths.append(path)
                logger.warning(
                    "Failed to stage path",
                    category: .staging,
                    metadata: ["path": path, "reason": error.localizedDescription]
                )
            }
        }

        logger.info(
            "Staged \(stagedPaths.count) of \(normalizedPaths.count) file(s)",
            category: .staging,
            metadata: ["files": stagedPaths.joined(separator: ", ")]
        )

        // Do not commit a partial selection: the user expects every selected
        // path in the commit. Surface a typed error instead of silently
        // dropping the files that could not be staged.
        guard failedPaths.isEmpty else {
            throw GitAppError.commandFailed(
                command: ["add", "--"] + failedPaths,
                exitCode: -1,
                stdout: "",
                stderr: "Could not stage \(failedPaths.count) selected path(s): \(failedPaths.joined(separator: ", "))"
            )
        }

        var args = ["commit", "-m", summary]
        if let description, !description.isEmpty { args += ["-m", description] }
        // Co-authors as a trailing `-m` paragraph. Git keeps each `-m` as its own
        // paragraph (blank-line separated); the trailer lines land in the final
        // paragraph, which is the trailer block git recognises.
        if !options.coAuthors.isEmpty {
            let trailer = options.coAuthors.map(\.trailerLine).joined(separator: "\n")
            args += ["-m", trailer]
        }
        if options.isAmend { args.append("--amend") }
        if options.skipHooks { args.append("--no-verify") }
        if options.signOff { args.append("--signoff") }

        _ = try await client.run(args, in: repositoryURL, timeout: 20)
    }

    func undoLastCommit(in repositoryURL: URL) async throws {
        _ = try await client.run(["reset", "--soft", "HEAD~1"], in: repositoryURL, timeout: 15)
    }
}
