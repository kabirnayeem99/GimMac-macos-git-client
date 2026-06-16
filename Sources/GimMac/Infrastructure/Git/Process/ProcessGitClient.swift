import Foundation

/// `GitClientProtocol` wrapper around a `GitCommandRunning` runner. Adds
/// timeout/cancellation wiring and consistent error mapping/logging.
final class ProcessGitClient: GitClientProtocol, Sendable {
    private let runner: GitCommandRunning
    let logger: GimMacLogger

    init(
        runner: GitCommandRunning = ProcessGitCommandRunner(),
        logger: GimMacLogger = GimMacLogger()
    ) {
        self.runner = runner
        self.logger = logger
    }

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval = 10) async throws -> GitCommandResult {
        try await runCommand(arguments, in: repositoryURL, extraEnvironment: [:], timeout: timeout)
    }

    func run(_ arguments: [String], in repositoryURL: URL, extraEnvironment: [String: String], timeout: TimeInterval) async throws -> GitCommandResult {
        try await runCommand(arguments, in: repositoryURL, extraEnvironment: extraEnvironment, timeout: timeout)
    }

    func runReturningData(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> Data {
        let commandID = UUID()
        do {
            let data = try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    try await self.runner.executeData(id: commandID, arguments: arguments, repositoryURL: repositoryURL, extraEnvironment: [:])
                }
                group.addTask {
                    let nanoseconds = timeout > 0 && timeout.isFinite ? UInt64(timeout * 1_000_000_000) : 0
                    try await Task.sleep(nanoseconds: nanoseconds)
                    await self.runner.cancel(id: commandID)
                    throw GitAppError.timeout(command: arguments, seconds: timeout)
                }
                guard let first = try await group.next() else {
                    throw GitAppError.commandFailed(command: arguments, exitCode: -1, stdout: "", stderr: "No result returned.")
                }
                group.cancelAll()
                return first
            }
            return data
        } catch let error as GitAppError {
            await logger.logGitCommandFailure(arguments, in: repositoryURL, error: error)
            throw error
        } catch is CancellationError {
            await runner.cancel(id: commandID)
            let cancelled = GitAppError.cancelled(command: arguments)
            await logger.logGitCommandFailure(arguments, in: repositoryURL, error: cancelled)
            throw cancelled
        } catch {
            let mappedError = GitAppErrorMapper.mapProcessError(command: arguments, error: error)
            await logger.logGitCommandFailure(arguments, in: repositoryURL, error: mappedError)
            throw mappedError
        }
    }

    private func runCommand(
        _ arguments: [String],
        in repositoryURL: URL,
        extraEnvironment: [String: String],
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        let commandID = UUID()

        do {
            let result = try await withThrowingTaskGroup(of: GitCommandResult.self) { group in
                group.addTask {
                    try await self.runner.execute(id: commandID, arguments: arguments, repositoryURL: repositoryURL, extraEnvironment: extraEnvironment)
                }
                group.addTask {
                    let nanoseconds = timeout > 0 && timeout.isFinite ? UInt64(timeout * 1_000_000_000) : 0
                    try await Task.sleep(nanoseconds: nanoseconds)
                    await self.runner.cancel(id: commandID)
                    throw GitAppError.timeout(command: arguments, seconds: timeout)
                }
                guard let firstResult = try await group.next() else {
                    throw GitAppError.commandFailed(command: arguments, exitCode: -1, stdout: "", stderr: "No result returned.")
                }
                group.cancelAll()
                return firstResult
            }
            await logger.logGitCommand(arguments, in: repositoryURL, result: result)
            return result
        } catch let error as GitAppError {
            await logger.logGitCommandFailure(arguments, in: repositoryURL, error: error)
            throw error
        } catch is CancellationError {
            await runner.cancel(id: commandID)
            let cancelled = GitAppError.cancelled(command: arguments)
            await logger.logGitCommandFailure(arguments, in: repositoryURL, error: cancelled)
            throw cancelled
        } catch {
            let mappedError = GitAppErrorMapper.mapProcessError(command: arguments, error: error)
            await logger.logGitCommandFailure(arguments, in: repositoryURL, error: mappedError)
            throw mappedError
        }
    }
}
