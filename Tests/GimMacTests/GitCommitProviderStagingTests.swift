import XCTest
@testable import GimMac

/// Fails staging for a configured path so we can assert the commit provider does
/// not silently commit a partial selection (audit Issue 7).
private actor StagingFakeClient: GitClientProtocol {
    private let failPath: String?
    private(set) var calls: [[String]] = []

    init(failPath: String? = nil) {
        self.failPath = failPath
    }

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        calls.append(arguments)
        if let failPath, arguments.first == "add", arguments.last == failPath {
            throw GitAppError.commandFailed(
                command: arguments, exitCode: 128, stdout: "", stderr: "fatal: pathspec error"
            )
        }
        return GitCommandResult(stdout: "", stderr: "", exitCode: 0)
    }

    var didCommit: Bool { calls.contains { $0.first == "commit" } }
}

final class GitCommitProviderStagingTests: XCTestCase {
    private let repoURL = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)

    private func makeSUT(_ client: StagingFakeClient) -> GitCommitProvider {
        GitCommitProvider(client: client, logger: GimMacLogger())
    }

    func testThrowsAndDoesNotCommitWhenAnyPathFailsToStage() async throws {
        let client = StagingFakeClient(failPath: "bad.txt")
        let sut = makeSUT(client)

        do {
            try await sut.commit(
                in: repoURL,
                paths: ["good.txt", "bad.txt"],
                summary: "Subject",
                description: nil,
                options: CommitOptions()
            )
            XCTFail("Expected commit to throw when a selected path cannot be staged")
        } catch let error as GitAppError {
            guard case let .commandFailed(_, _, _, stderr) = error else {
                return XCTFail("Expected .commandFailed, got \(error)")
            }
            XCTAssertTrue(stderr.contains("bad.txt"), "Error should name the unstaged path")
        }

        let committed = await client.didCommit
        XCTAssertFalse(committed, "No commit must run when staging is incomplete")
    }

    func testCommitsWhenAllPathsStage() async throws {
        let client = StagingFakeClient()
        let sut = makeSUT(client)

        try await sut.commit(
            in: repoURL,
            paths: ["a.txt", "b.txt"],
            summary: "Subject",
            description: nil,
            options: CommitOptions()
        )

        let committed = await client.didCommit
        XCTAssertTrue(committed, "A fully-staged selection should commit")
    }
}
