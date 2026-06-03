import Foundation

enum GitAppErrorMapper {
    static func map(
        command: [String],
        exitCode: Int32,
        stdout: String,
        stderr: String
    ) -> GitAppError {
        let normalized = stderr.lowercased()

        if normalized.contains("not a git repository") {
            return .notARepository
        }

        if normalized.contains("permission denied") {
            return .permissionDenied
        }

        if normalized.contains("gpg failed to sign") || normalized.contains("cannot run gpg")
            || normalized.contains("secret key not available") || normalized.contains("failed to write commit object") {
            return .signingFailed
        }

        if (normalized.contains("no such file or directory") && normalized.contains(".git"))
            || normalized.contains("could not open '.git") {
            return .repositoryNotFound
        }

        return .commandFailed(command: command, exitCode: exitCode, stdout: stdout, stderr: stderr)
    }

    static func mapProcessError(command: [String], error: Error) -> GitAppError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileNoSuchFileError {
            return .gitNotFound
        }

        if let gitError = error as? GitAppError {
            return gitError
        }

        return .commandFailed(command: command, exitCode: -1, stdout: "", stderr: error.localizedDescription)
    }
}
