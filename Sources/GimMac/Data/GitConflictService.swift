import Foundation

/// Per-file conflict resolution. Mirrors GitHub Desktop's `stage.ts`,
/// `diff-check.ts`, and the unmerged-entry classification in `status.ts`.
///
/// Classification reads the porcelain v1 `XY` code directly (same source GitHub
/// Desktop uses), so it stays consistent with `GitStatusParser`'s conflict
/// detection without switching the rest of the app to porcelain v2.
final class GitConflictService: ConflictResolutionProviding, Sendable {
    private let client: GitClientProtocol

    /// Backstop timeout for `git mergetool`. The tool is interactive and blocks
    /// until the user closes it, so this is intentionally long — it is a safety
    /// limit for a crashed/abandoned tool, not the primary stop. Cancellation
    /// (task cancellation propagated through the runner) is how the UI aborts a
    /// merge-tool session promptly.
    private static let mergeToolTimeout: TimeInterval = 3600

    init(client: GitClientProtocol) {
        self.client = client
    }

    // MARK: - Detection

    func conflictedFiles(in repositoryURL: URL) async throws -> [ConflictedFileStatus] {
        let result = try await client.run(
            ["status", "--porcelain", "-z"], in: repositoryURL, timeout: 30
        )
        let markerCounts = await conflictMarkerCounts(in: repositoryURL)

        // `-z` separates entries with NUL. Rename entries carry a second NUL
        // (old path); conflicts never rename, so a simple split is safe here.
        let entries = result.stdout.split(separator: "\0", omittingEmptySubsequences: true)
        return entries.compactMap { entry -> ConflictedFileStatus? in
            guard entry.count >= 4 else { return nil }
            let chars = Array(entry)
            let code = String(chars[0...1])
            // Porcelain prefixes the path with "XY " (code + single space).
            let path = String(entry.dropFirst(3))
            guard let summary = Self.summary(forXY: code) else { return nil }

            if summary.hasConflictMarkers {
                return .withMarkers(
                    path: path,
                    summary: summary,
                    conflictMarkerCount: markerCounts[path] ?? 0
                )
            }
            return .manual(path: path, summary: summary)
        }
    }

    /// Maps the unmerged `XY` porcelain codes to a conflict summary. Returns
    /// `nil` for any non-conflict code so callers can filter normal changes out.
    private static func summary(forXY code: String) -> UnmergedEntrySummary? {
        switch code {
        case "UU": return .bothModified
        case "AA": return .bothAdded
        case "DD": return .bothDeleted
        case "AU": return .addedByUs
        case "UA": return .addedByThem
        case "DU": return .deletedByUs
        case "UD": return .deletedByThem
        default: return nil
        }
    }

    /// Counts leftover conflict markers per file via `git diff --check`.
    /// `git diff --check` exits 2 when markers exist, printing lines of the form
    /// `path:line: leftover conflict marker`. A non-throwing best-effort helper —
    /// marker counts are display-only, so failures degrade to an empty map.
    private func conflictMarkerCounts(in repositoryURL: URL) async -> [String: Int] {
        let output: String
        do {
            let result = try await client.run(["diff", "--check"], in: repositoryURL, timeout: 30)
            output = result.stdout
        } catch let error as GitAppError {
            // Exit code 2 (markers found) surfaces as commandFailed; the listing
            // is on stdout.
            guard case let .commandFailed(_, _, stdout, _) = error else { return [:] }
            output = stdout
        } catch {
            return [:]
        }

        var counts: [String: Int] = [:]
        for line in output.split(separator: "\n") {
            guard line.hasSuffix("leftover conflict marker"),
                  let range = line.range(of: ": leftover conflict marker") else { continue }
            let prefix = line[line.startIndex..<range.lowerBound] // "path:line"
            guard let lastColon = prefix.lastIndex(of: ":") else { continue }
            let path = String(prefix[prefix.startIndex..<lastColon])
            counts[path, default: 0] += 1
        }
        return counts
    }

    // MARK: - Resolution

    func stageManualConflictResolution(
        _ path: String,
        summary: UnmergedEntrySummary,
        resolution: ManualConflictResolution,
        in repositoryURL: URL
    ) async throws {
        // The chosen side's entry decides the staging command: a deletion is
        // staged with `git rm`, anything else is checked out then `git add`ed.
        // Mirrors GitHub Desktop's `stageManualConflictResolution`.
        let chosenIsDeletion = Self.chosenSideIsDeletion(summary: summary, resolution: resolution)
        if chosenIsDeletion {
            try await removeConflictedFile(path, in: repositoryURL)
            return
        }
        _ = try await client.run(
            ["checkout", "--\(resolution.rawValue)", "--", path], in: repositoryURL, timeout: 30
        )
        try await markResolved(path, in: repositoryURL)
    }

    /// Whether keeping `resolution`'s side means the file ends up deleted.
    private static func chosenSideIsDeletion(
        summary: UnmergedEntrySummary,
        resolution: ManualConflictResolution
    ) -> Bool {
        // (ours-deletes, theirs-deletes) per conflict kind.
        let (oursDeletes, theirsDeletes): (Bool, Bool)
        switch summary {
        case .bothModified, .bothAdded: (oursDeletes, theirsDeletes) = (false, false)
        case .bothDeleted: (oursDeletes, theirsDeletes) = (true, true)
        case .addedByUs: (oursDeletes, theirsDeletes) = (false, true)   // AU: them deleted
        case .addedByThem: (oursDeletes, theirsDeletes) = (true, false)  // UA: us deleted
        case .deletedByUs: (oursDeletes, theirsDeletes) = (true, false)  // DU: us deleted
        case .deletedByThem: (oursDeletes, theirsDeletes) = (false, true) // UD: them deleted
        }
        return resolution == .ours ? oursDeletes : theirsDeletes
    }

    func markResolved(_ path: String, in repositoryURL: URL) async throws {
        _ = try await client.run(["add", "--", path], in: repositoryURL, timeout: 30)
    }

    func removeConflictedFile(_ path: String, in repositoryURL: URL) async throws {
        _ = try await client.run(["rm", "--", path], in: repositoryURL, timeout: 30)
    }

    // MARK: - Merge tool

    func mergeToolName(in repositoryURL: URL) async -> String? {
        guard let result = try? await client.run(
            ["config", "--get", "merge.tool"], in: repositoryURL, timeout: 10
        ) else { return nil }
        let name = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    func openInMergeTool(_ path: String, in repositoryURL: URL) async throws {
        // Security: a merge tool is an executable path. Honoring a
        // repository-local `merge.tool` / `mergetool.<t>.cmd` would run code
        // chosen by the repo, which the app's trust model forbids. Resolve the
        // tool from global config only and refuse repo-local overrides.
        let localOverride = try? await client.run(
            ["config", "--local", "--get-regexp", "^(merge\\.tool|mergetool\\..*\\.cmd)$"],
            in: repositoryURL, timeout: 10
        )
        if let localOverride, !localOverride.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw GitAppError.commandFailed(
                command: ["mergetool"],
                exitCode: 1,
                stdout: "",
                stderr: "This repository defines its own merge tool in .git/config, which GimMac will not run. "
                    + "Resolve the conflict in your editor, or set a merge tool in your global Git config."
            )
        }

        guard let tool = await globalMergeToolName(in: repositoryURL) else {
            throw GitAppError.commandFailed(
                command: ["mergetool"],
                exitCode: 1,
                stdout: "",
                stderr: "No merge tool is configured. Set one with `git config --global merge.tool <tool>`."
            )
        }

        // Force the globally-resolved tool and trust its exit code so git stages
        // the file on a clean exit. `git mergetool` blocks until the tool closes.
        _ = try await client.run(
            ["-c", "merge.tool=\(tool)", "mergetool", "--no-prompt", "--", path],
            in: repositoryURL, timeout: Self.mergeToolTimeout
        )
    }

    private func globalMergeToolName(in repositoryURL: URL) async -> String? {
        guard let result = try? await client.run(
            ["config", "--global", "--get", "merge.tool"], in: repositoryURL, timeout: 10
        ) else { return nil }
        let name = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
