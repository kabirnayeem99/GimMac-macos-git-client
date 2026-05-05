import XCTest
@testable import GimMac

final class ProcessGitClientTests: XCTestCase {
    func testRunReturnsRunnerResult() async throws {
        let runner = MockRunner(result: .success(GitCommandResult(stdout: "ok", stderr: "", exitCode: 0)))
        let sut = ProcessGitClient(runner: runner)

        let result = try await sut.run(["status"], in: URL(fileURLWithPath: "/tmp"), timeout: 1)

        XCTAssertEqual(result.stdout, "ok")
    }

    func testRunTimesOutAndCancelsCommand() async {
        let runner = MockRunner(result: .success(GitCommandResult(stdout: "", stderr: "", exitCode: 0)), delayNanoseconds: 2_000_000_000)
        let sut = ProcessGitClient(runner: runner)

        do {
            _ = try await sut.run(["status"], in: URL(fileURLWithPath: "/tmp"), timeout: 0.05)
            XCTFail("Expected timeout error")
        } catch let error as GitAppError {
            guard case .timeout = error else {
                XCTFail("Expected timeout, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let cancelledCount = await runner.cancelCallCount
        XCTAssertEqual(cancelledCount, 1)
    }

    func testRunCancellationMapsToCancelledError() async {
        let runner = MockRunner(result: .success(GitCommandResult(stdout: "", stderr: "", exitCode: 0)), delayNanoseconds: 2_000_000_000)
        let sut = ProcessGitClient(runner: runner)

        let task = Task {
            try await sut.run(["status"], in: URL(fileURLWithPath: "/tmp"), timeout: 5)
        }

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch let error as GitAppError {
            guard case .cancelled(let command) = error else {
                XCTFail("Expected cancelled error")
                return
            }
            XCTAssertEqual(command, ["status"])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

actor MockRunner: GitCommandRunning {
    private let result: Result<GitCommandResult, Error>
    private let delayNanoseconds: UInt64
    private(set) var cancelCallCount = 0

    init(result: Result<GitCommandResult, Error>, delayNanoseconds: UInt64 = 0) {
        self.result = result
        self.delayNanoseconds = delayNanoseconds
    }

    func execute(id: UUID, arguments: [String], repositoryURL: URL) async throws -> GitCommandResult {
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        if Task.isCancelled {
            throw CancellationError()
        }

        return try result.get()
    }

    func cancel(id: UUID) {
        cancelCallCount += 1
    }
}
