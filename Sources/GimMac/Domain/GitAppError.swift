import Foundation

enum GitAppError: Error, Equatable, LocalizedError {
    case gitNotFound
    case repositoryNotFound
    case notARepository
    case permissionDenied
    case timeout(command: [String], seconds: TimeInterval)
    case cancelled(command: [String])
    case commandFailed(command: [String], exitCode: Int32, stdout: String, stderr: String)
    case invalidOutput(command: [String], details: String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "Git executable was not found on this Mac."
        case .repositoryNotFound:
            return "The selected repository path could not be accessed."
        case .notARepository:
            return "The selected folder is not a Git repository."
        case .permissionDenied:
            return "Permission was denied while running Git in this repository."
        case let .timeout(command, seconds):
            return "Git command timed out after \(Int(seconds))s: git \(command.joined(separator: " "))"
        case let .cancelled(command):
            return "Git command was cancelled: git \(command.joined(separator: " "))"
        case let .commandFailed(command, _, _, stderr):
            let message = stderr.isEmpty ? "Git command failed." : stderr
            return "\(message) (git \(command.joined(separator: " ")))"
        case let .invalidOutput(command, details):
            return "Git returned invalid output for \(command.joined(separator: " ")): \(details)"
        }
    }
}
