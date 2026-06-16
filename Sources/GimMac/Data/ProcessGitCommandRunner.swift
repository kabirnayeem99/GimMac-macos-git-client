import Foundation

/// Actor that actually spawns `Process` instances to run Git commands. Tracks
/// in-flight processes so cancellation can terminate the underlying task.
actor ProcessGitCommandRunner: GitCommandRunning {
    private var inFlight: [UUID: Process] = [:]
    /// Concurrent so unrelated Git commands (status, history, branch reads) are
    /// not serialized behind a single long-running command (clone, merge tool,
    /// large diff, blob read).
    private let queue = DispatchQueue(
        label: "com.gimmac.git-runner",
        qos: .userInitiated,
        attributes: .concurrent
    )

    func execute(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> GitCommandResult {
        let process = Self.makeProcess(arguments: arguments, repositoryURL: repositoryURL, extraEnvironment: extraEnvironment)
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
                        let output = try Self.runDrainingPipes(process, stdout: stdout, stderr: stderr)
                        let outString = String(data: output.stdout, encoding: .utf8) ?? ""
                        let errString = String(data: output.stderr, encoding: .utf8) ?? ""

                        if output.status == 0 {
                            continuation.resume(returning: GitCommandResult(stdout: outString, stderr: errString, exitCode: 0))
                            return
                        }

                        continuation.resume(throwing: GitAppErrorMapper.map(
                            command: arguments,
                            exitCode: output.status,
                            stdout: outString,
                            stderr: errString
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

    func executeData(id: UUID, arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) async throws -> Data {
        let process = Self.makeProcess(arguments: arguments, repositoryURL: repositoryURL, extraEnvironment: extraEnvironment)
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
                        let output = try Self.runDrainingPipes(process, stdout: stdout, stderr: stderr)

                        if output.status == 0 {
                            continuation.resume(returning: output.stdout)
                            return
                        }

                        continuation.resume(throwing: GitAppErrorMapper.map(
                            command: arguments,
                            exitCode: output.status,
                            stdout: "",
                            stderr: String(data: output.stderr, encoding: .utf8) ?? ""
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

    private static func makeProcess(arguments: [String], repositoryURL: URL, extraEnvironment: [String: String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = repositoryURL
        var env = gitEnvironment()
        env.merge(extraEnvironment) { _, new in new }
        process.environment = env
        return process
    }

    /// Runs `process` and drains stdout and stderr concurrently. Sequential
    /// draining can deadlock: a subprocess that fills the pipe Git is not reading
    /// blocks before exit, so `waitUntilExit()` never returns.
    private struct ProcessOutput {
        let stdout: Data
        let stderr: Data
        let status: Int32
    }

    private static func runDrainingPipes(_ process: Process, stdout: Pipe, stderr: Pipe) throws -> ProcessOutput {
        try process.run()

        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()
        let ioQueue = DispatchQueue.global(qos: .userInitiated)

        group.enter()
        ioQueue.async {
            outBox.set(stdout.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.enter()
        ioQueue.async {
            errBox.set(stderr.fileHandleForReading.readDataToEndOfFile())
            group.leave()
        }
        group.wait()

        process.waitUntilExit()
        return ProcessOutput(stdout: outBox.get(), stderr: errBox.get(), status: process.terminationStatus)
    }

    private static func gitEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin"]
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let merged = (extra + existing.components(separatedBy: ":"))
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        env["PATH"] = merged.joined(separator: ":")
        // Force a stable locale so Git emits canonical English stderr, which
        // `GitAppErrorMapper` matches on. Non-English LANG/LC_* would otherwise
        // defeat typed-error classification.
        env["LANG"] = "C"
        env["LC_ALL"] = "C"
        return env
    }
}

/// Lock-guarded box so the two pipe-draining closures can publish their `Data`
/// back to the caller without an unsynchronized shared `var`.
private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func set(_ value: Data) {
        lock.lock()
        data = value
        lock.unlock()
    }

    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
