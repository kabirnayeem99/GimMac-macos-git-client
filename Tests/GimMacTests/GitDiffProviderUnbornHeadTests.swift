import XCTest
@testable import GimMac

/// Drives `rev-parse --verify HEAD` outcomes so we can assert unborn-head
/// detection only fires for a genuinely missing HEAD, not for any failure
/// (audit Issue 8).
private actor UnbornFakeClient: GitClientProtocol {
    enum Behavior {
        case success
        case fail(stderr: String, exit: Int32)
        case timeout
    }

    private let behavior: Behavior
    init(_ behavior: Behavior) { self.behavior = behavior }

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        switch behavior {
        case .success:
            return GitCommandResult(stdout: "deadbeef\n", stderr: "", exitCode: 0)
        case let .fail(stderr, exit):
            throw GitAppError.commandFailed(command: arguments, exitCode: exit, stdout: "", stderr: stderr)
        case .timeout:
            throw GitAppError.timeout(command: arguments, seconds: timeout)
        }
    }
}

final class GitDiffProviderUnbornHeadTests: XCTestCase {
    private let repoURL = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)

    private func isUnborn(_ behavior: UnbornFakeClient.Behavior) async -> Bool {
        await GitDiffProvider.isUnbornHead(client: UnbornFakeClient(behavior), repositoryURL: repoURL)
    }

    func testResolvedHeadIsNotUnborn() async {
        let result = await isUnborn(.success)
        XCTAssertFalse(result)
    }

    func testUnknownRevisionStderrIsUnborn() async {
        let stderr = "fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree."
        let result = await isUnborn(.fail(stderr: stderr, exit: 128))
        XCTAssertTrue(result)
    }

    func testNeededSingleRevisionStderrIsUnborn() async {
        let result = await isUnborn(.fail(stderr: "fatal: Needed a single revision", exit: 128))
        XCTAssertTrue(result)
    }

    func testPermissionFailureIsNotUnborn() async {
        let result = await isUnborn(.fail(stderr: "fatal: could not read: Permission denied", exit: 128))
        XCTAssertFalse(result)
    }

    func testTimeoutIsNotUnborn() async {
        let result = await isUnborn(.timeout)
        XCTAssertFalse(result)
    }
}
