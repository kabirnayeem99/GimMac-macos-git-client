import Foundation

/// `GitClientProtocol` wrapper around a `GitCommandRunning` runner. Adds
/// timeout/cancellation wiring and consistent error mapping/logging.
final class ProcessGitClient: GitClientProtocol, Sendable {
    private let runner: GitCommandRunning
    private let scheduler: GitCommandScheduler
    let logger: GimMacLogger

    init(
        runner: GitCommandRunning = ProcessGitCommandRunner(),
        scheduler: GitCommandScheduler = .shared,
        logger: GimMacLogger = GimMacLogger()
    ) {
        self.runner = runner
        self.scheduler = scheduler
        self.logger = logger
    }
}

extension ProcessGitClient {
    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval = 10) async throws -> GitCommandResult {
        try await run(arguments, in: repositoryURL, priority: .visible, timeout: timeout)
    }

    func run(
        _ arguments: [String],
        in repositoryURL: URL,
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        try await runCommand(arguments, in: repositoryURL, extraEnvironment: [:], priority: priority, timeout: timeout)
    }

    func run(_ arguments: [String], in repositoryURL: URL, extraEnvironment: [String: String], timeout: TimeInterval) async throws -> GitCommandResult {
        try await runCommand(arguments, in: repositoryURL, extraEnvironment: extraEnvironment, priority: .visible, timeout: timeout)
    }

    func runReturningData(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> Data {
        try await runReturningData(arguments, in: repositoryURL, priority: .visible, timeout: timeout)
    }

    func runReturningData(
        _ arguments: [String],
        in repositoryURL: URL,
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> Data {
        let commandID = UUID()
        let startedAt = ProcessInfo.processInfo.systemUptime
        let tag = logger.tag("git.command", metadata: [
            "command_id": commandID.uuidString,
            "mode": "data",
            "priority": priority.rawValue,
            "repository": repositoryURL.lastPathComponent
        ])
        let context = GitCommandPhaseContext(
            arguments: arguments,
            repositoryURL: repositoryURL,
            commandID: commandID,
            priority: priority,
            startedAt: startedAt,
            tag: tag
        )
        await logger.logGitCommandStarted(
            .init(
                arguments: arguments,
                repositoryURL: repositoryURL,
                commandID: commandID,
                timeout: timeout,
                extraEnvironment: [:]
            ),
            tag: tag
        )
        do {
            let permit = try await scheduler.acquire(priority: priority)
            defer { Task { await scheduler.release(priority: permit.priority) } }
            logCommandPhase(
                "Git data command scheduler acquired",
                metadata: ["git.queue_wait_ms": Self.formatMilliseconds(permit.queueWaitMilliseconds)],
                context: context
            )
            logCommandPhase(
                "Git data command task group entered",
                context: context
            )
            let data = try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    let runnerStartedAt = ProcessInfo.processInfo.systemUptime
                    self.logCommandPhase(
                        "Git data command runner await started",
                        context: context
                    )
                    do {
                        let data = try await self.runner.executeData(
                            id: commandID,
                            arguments: arguments,
                            repositoryURL: repositoryURL,
                            extraEnvironment: [:]
                        )
                        self.logCommandPhase(
                            "Git data command runner await finished",
                            phaseDurationMilliseconds: Self.durationMilliseconds(since: runnerStartedAt),
                            context: context
                        )
                        return data
                    } catch {
                        self.logCommandPhase(
                            "Git data command runner await failed",
                            phaseDurationMilliseconds: Self.durationMilliseconds(since: runnerStartedAt),
                            metadata: ["reason": error.localizedDescription],
                            context: context
                        )
                        throw error
                    }
                }
                group.addTask {
                    self.logCommandPhase(
                        "Git data command timeout watcher started",
                        metadata: ["timeout_seconds": String(timeout)],
                        context: context
                    )
                    let nanoseconds = timeout > 0 && timeout.isFinite ? UInt64(timeout * 1_000_000_000) : 0
                    try await Task.sleep(nanoseconds: nanoseconds)
                    await self.runner.cancel(id: commandID)
                    throw GitAppError.timeout(command: arguments, seconds: timeout)
                }
                guard let first = try await group.next() else {
                    throw GitAppError.commandFailed(command: arguments, exitCode: -1, stdout: "", stderr: "No result returned.")
                }
                self.logCommandPhase(
                    "Git data command first task returned",
                    context: context
                )
                group.cancelAll()
                return first
            }
            logCommandPhase(
                "Git data command task group finished",
                metadata: ["bytes": String(data.count)],
                context: context
            )
            await logger.logGitCommand(
                arguments,
                in: repositoryURL,
                result: GitCommandResult(stdout: "<\(data.count) bytes>", stderr: "", exitCode: 0),
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            return data
        } catch let error as GitAppError {
            await logger.logGitCommandFailure(
                arguments,
                in: repositoryURL,
                error: error,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            throw error
        } catch is CancellationError {
            await runner.cancel(id: commandID)
            let cancelled = GitAppError.cancelled(command: arguments)
            await logger.logGitCommandFailure(
                arguments,
                in: repositoryURL,
                error: cancelled,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            throw cancelled
        } catch {
            let mappedError = GitAppErrorMapper.mapProcessError(command: arguments, error: error)
            await logger.logGitCommandFailure(
                arguments,
                in: repositoryURL,
                error: mappedError,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            throw mappedError
        }
    }

    private func runCommand(
        _ arguments: [String],
        in repositoryURL: URL,
        extraEnvironment: [String: String],
        priority: GitCommandPriority,
        timeout: TimeInterval
    ) async throws -> GitCommandResult {
        let commandID = UUID()
        let startedAt = ProcessInfo.processInfo.systemUptime
        let tag = logger.tag("git.command", metadata: [
            "command_id": commandID.uuidString,
            "mode": "text",
            "priority": priority.rawValue,
            "repository": repositoryURL.lastPathComponent
        ])
        let context = GitCommandPhaseContext(
            arguments: arguments,
            repositoryURL: repositoryURL,
            commandID: commandID,
            priority: priority,
            startedAt: startedAt,
            tag: tag
        )
        await logger.logGitCommandStarted(
            .init(
                arguments: arguments,
                repositoryURL: repositoryURL,
                commandID: commandID,
                timeout: timeout,
                extraEnvironment: extraEnvironment
            ),
            tag: tag
        )

        do {
            let permit = try await scheduler.acquire(priority: priority)
            defer { Task { await scheduler.release(priority: permit.priority) } }
            logCommandPhase(
                "Git text command scheduler acquired",
                metadata: ["git.queue_wait_ms": Self.formatMilliseconds(permit.queueWaitMilliseconds)],
                context: context
            )
            logCommandPhase(
                "Git text command task group entered",
                context: context
            )
            let result = try await withThrowingTaskGroup(of: GitCommandResult.self) { group in
                group.addTask {
                    let runnerStartedAt = ProcessInfo.processInfo.systemUptime
                    self.logCommandPhase(
                        "Git text command runner await started",
                        context: context
                    )
                    do {
                        let result = try await self.runner.execute(
                            id: commandID,
                            arguments: arguments,
                            repositoryURL: repositoryURL,
                            extraEnvironment: extraEnvironment
                        )
                        self.logCommandPhase(
                            "Git text command runner await finished",
                            phaseDurationMilliseconds: Self.durationMilliseconds(since: runnerStartedAt),
                            metadata: ["exit_code": String(result.exitCode)],
                            context: context
                        )
                        return result
                    } catch {
                        self.logCommandPhase(
                            "Git text command runner await failed",
                            phaseDurationMilliseconds: Self.durationMilliseconds(since: runnerStartedAt),
                            metadata: ["reason": error.localizedDescription],
                            context: context
                        )
                        throw error
                    }
                }
                group.addTask {
                    self.logCommandPhase(
                        "Git text command timeout watcher started",
                        metadata: ["timeout_seconds": String(timeout)],
                        context: context
                    )
                    let nanoseconds = timeout > 0 && timeout.isFinite ? UInt64(timeout * 1_000_000_000) : 0
                    try await Task.sleep(nanoseconds: nanoseconds)
                    await self.runner.cancel(id: commandID)
                    throw GitAppError.timeout(command: arguments, seconds: timeout)
                }
                guard let firstResult = try await group.next() else {
                    throw GitAppError.commandFailed(command: arguments, exitCode: -1, stdout: "", stderr: "No result returned.")
                }
                self.logCommandPhase(
                    "Git text command first task returned",
                    context: context
                )
                group.cancelAll()
                return firstResult
            }
            logCommandPhase(
                "Git text command task group finished",
                metadata: [
                    "exit_code": String(result.exitCode),
                    "stdout_bytes": String(result.stdout.utf8.count),
                    "stderr_bytes": String(result.stderr.utf8.count)
                ],
                context: context
            )
            await logger.logGitCommand(
                arguments,
                in: repositoryURL,
                result: result,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            return result
        } catch let error as GitAppError {
            await logger.logGitCommandFailure(
                arguments,
                in: repositoryURL,
                error: error,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            throw error
        } catch is CancellationError {
            await runner.cancel(id: commandID)
            let cancelled = GitAppError.cancelled(command: arguments)
            await logger.logGitCommandFailure(
                arguments,
                in: repositoryURL,
                error: cancelled,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            throw cancelled
        } catch {
            let mappedError = GitAppErrorMapper.mapProcessError(command: arguments, error: error)
            await logger.logGitCommandFailure(
                arguments,
                in: repositoryURL,
                error: mappedError,
                durationMilliseconds: Self.durationMilliseconds(since: startedAt),
                commandID: commandID,
                tag: tag
            )
            throw mappedError
        }
    }

    private static func durationMilliseconds(since startedAt: TimeInterval) -> Double {
        max(0, (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
    }

    private struct GitCommandPhaseContext {
        let arguments: [String]
        let repositoryURL: URL
        let commandID: UUID
        let priority: GitCommandPriority
        let startedAt: TimeInterval
        let tag: LogFlowTag?
    }

    private func logCommandPhase(
        _ message: String,
        phaseDurationMilliseconds: Double? = nil,
        metadata: [String: String] = [:],
        context: GitCommandPhaseContext
    ) {
        var details = metadata
        details["git.command_id"] = context.commandID.uuidString
        details["git.command"] = "git " + context.arguments.joined(separator: " ")
        details["git.elapsed_ms"] = Self.formatMilliseconds(Self.durationMilliseconds(since: context.startedAt))
        details["git.priority"] = context.priority.rawValue
        details["repository"] = context.repositoryURL.lastPathComponent
        if let phaseDurationMilliseconds {
            details["git.phase_duration_ms"] = Self.formatMilliseconds(phaseDurationMilliseconds)
        }
        logger.debug(message, category: .git, metadata: details, tag: context.tag)
    }

    private static func formatMilliseconds(_ milliseconds: Double) -> String {
        String(format: "%.3f", milliseconds)
    }
}
