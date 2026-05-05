import Foundation

protocol GitCommandRunning: Sendable {
    func execute(id: UUID, arguments: [String], repositoryURL: URL) async throws -> GitCommandResult
    func cancel(id: UUID) async
}

final class ProcessGitClient: GitClientProtocol, @unchecked Sendable {
    private let runner: GitCommandRunning

    init(runner: GitCommandRunning = ProcessGitCommandRunner()) {
        self.runner = runner
    }

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval = 10) async throws -> GitCommandResult {
        let commandID = UUID()

        do {
            return try await withThrowingTaskGroup(of: GitCommandResult.self) { group in
                group.addTask {
                    try await self.runner.execute(id: commandID, arguments: arguments, repositoryURL: repositoryURL)
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
        } catch let error as GitAppError {
            throw error
        } catch is CancellationError {
            await runner.cancel(id: commandID)
            throw GitAppError.cancelled(command: arguments)
        } catch {
            throw GitAppErrorMapper.mapProcessError(command: arguments, error: error)
        }
    }
}

actor ProcessGitCommandRunner: GitCommandRunning {
    private var inFlight: [UUID: Process] = [:]

    func execute(id: UUID, arguments: [String], repositoryURL: URL) async throws -> GitCommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = repositoryURL

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        inFlight[id] = process

        defer {
            inFlight[id] = nil
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try process.run()
                        process.waitUntilExit()

                        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
                        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                        let out = String(data: stdoutData, encoding: .utf8) ?? ""
                        let err = String(data: stderrData, encoding: .utf8) ?? ""

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
            Task {
                await self.cancel(id: id)
            }
        }
    }

    func cancel(id: UUID) {
        guard let process = inFlight[id], process.isRunning else {
            return
        }
        process.terminate()
    }
}
