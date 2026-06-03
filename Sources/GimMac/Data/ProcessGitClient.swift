import Foundation

protocol GitCommandRunning: Sendable {
    func execute(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> GitCommandResult
    func cancel(id: UUID) async
}

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

actor ProcessGitCommandRunner: GitCommandRunning {
    private var inFlight: [UUID: Process] = [:]
    private let queue = DispatchQueue(label: "com.gimmac.git-runner", qos: .userInitiated)

    func execute(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = repositoryURL
        var env = Self.gitEnvironment()
        env.merge(extraEnvironment) { _, new in new }
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        inFlight[id] = process
        defer { inFlight[id] = nil }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    do {
                        try process.run()
                        process.waitUntilExit()

                        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                        if process.terminationStatus == 0 {
                            continuation.resume(returning: GitCommandResult(stdout: out, stderr: err, exitCode: 0))
                            return
                        }

                        continuation.resume(throwing: GitAppErrorMapper.map(
                            command: arguments,
                            exitCode: process.terminationStatus,
                            stdout: out,
                            stderr: err
                        ))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    func cancel(id: UUID) {
        guard let process = inFlight[id], process.isRunning else { return }
        process.terminate()
    }

    private static func gitEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let merged = (extra + existing.components(separatedBy: ":"))
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        env["PATH"] = merged.joined(separator: ":")
        return env
    }
}
