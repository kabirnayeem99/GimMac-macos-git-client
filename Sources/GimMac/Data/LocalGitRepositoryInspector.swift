import Foundation

enum RepositoryInspectionError: Error, LocalizedError {
    case commandFailed(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .invalidOutput:
            return "Received invalid Git output."
        }
    }
}

struct LocalGitRepositoryInspector: RepositoryInspecting, Sendable {
    func inspectRepository(at url: URL) async throws -> RepositoryState {
        let branch = try runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], at: url)
        if branch == "HEAD" {
            let shortSHA = try runGitCommand(["rev-parse", "--short", "HEAD"], at: url)
            return RepositoryState(currentBranch: nil, detachedHeadShortSHA: shortSHA)
        }
        return RepositoryState(currentBranch: branch, detachedHeadShortSHA: nil)
    }

    private func runGitCommand(_ arguments: [String], at repositoryURL: URL) throws -> String {
        let process = Process()
        process.currentDirectoryURL = repositoryURL
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw RepositoryInspectionError.commandFailed(err.isEmpty ? "Git command failed." : err)
        }

        guard !out.isEmpty else {
            throw RepositoryInspectionError.invalidOutput
        }
        return out
    }
}
