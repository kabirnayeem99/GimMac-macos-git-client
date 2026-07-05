import XCTest
@testable import GimMac

final class ProcessGitCommandRunnerTests: XCTestCase {
    func testCancellationEscalatesToSigkillWhenProcessIgnoresTerminate() async throws {
        let tempDir = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let pidFileURL = tempDir.appendingPathComponent("git.pid")
        try makeIgnoringGitExecutable(at: tempDir.appendingPathComponent("git"), pidFileURL: pidFileURL)

        let runner = ProcessGitCommandRunner(killGracePeriodNanoseconds: 50_000_000)
        let task = Task {
            try await runner.execute(
                id: UUID(),
                arguments: ["status"],
                repositoryURL: tempDir,
                extraEnvironment: ["PATH": tempDir.path]
            )
        }

        let pid = try await waitForPID(at: pidFileURL)
        task.cancel()
        _ = try? await task.value

        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(isProcessRunning(pid: pid), "Expected SIGKILL escalation to stop the git subprocess")
    }

    private func makeTemporaryDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeIgnoringGitExecutable(at scriptURL: URL, pidFileURL: URL) throws {
        let script = """
        #!/bin/sh
        echo $$ > "\(pidFileURL.path)"
        trap '' TERM
        while true; do
          sleep 1
        done
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private func waitForPID(at pidFileURL: URL) async throws -> Int32 {
        for _ in 0..<50 {
            if let contents = try? String(contentsOf: pidFileURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = Int32(contents) {
                return pid
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for fake git pid file")
        return -1
    }

    private func isProcessRunning(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0
    }
}
