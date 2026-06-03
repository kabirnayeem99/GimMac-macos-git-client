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
    case bareRepository
    case unsafeRepository(path: String)
    case signingFailed

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
        case .bareRepository:
            return "This is a bare Git repository and cannot be opened."
        case let .unsafeRepository(path):
            return "Git refused to open \(path) due to unsafe ownership. Run: git config --global --add safe.directory \(path)"
        case .signingFailed:
            return "Git could not sign the commit. Check that gpg (or your configured signing tool) is installed and your signing key is available."
        }
    }
}
