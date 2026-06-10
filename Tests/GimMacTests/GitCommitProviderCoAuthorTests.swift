import XCTest
@testable import GimMac

/// Records every git invocation so we can assert on the commit argument vector.
private actor RecordingGitClient: GitClientProtocol {
    private(set) var calls: [[String]] = []

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        calls.append(arguments)
        return GitCommandResult(stdout: "", stderr: "", exitCode: 0)
    }

    var commitCall: [String]? {
        calls.first { $0.first == "commit" }
    }
}

final class GitCommitProviderCoAuthorTests: XCTestCase {
    private let repoURL = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)

    private func makeSUT(_ client: RecordingGitClient) -> GitCommitProvider {
        GitCommitProvider(client: client, logger: GimMacLogger())
    }

    func testNoTrailerWhenNoCoAuthors() async throws {
        let client = RecordingGitClient()
        try await makeSUT(client).commit(
            in: repoURL, paths: ["a.txt"], summary: "Subject", description: nil, options: CommitOptions()
        )
        let commit = await client.commitCall
        XCTAssertEqual(commit, ["commit", "-m", "Subject"])
    }

    func testSingleCoAuthorAppendsTrailerParagraph() async throws {
        let client = RecordingGitClient()
        let options = CommitOptions(coAuthors: [CommitAuthor(name: "Jane Doe", email: "jane@example.com")])
        try await makeSUT(client).commit(
            in: repoURL, paths: ["a.txt"], summary: "Subject", description: nil, options: options
        )
        let commit = await client.commitCall
        XCTAssertEqual(
            commit,
            ["commit", "-m", "Subject", "-m", "Co-authored-by: Jane Doe <jane@example.com>"]
        )
    }

    func testMultipleCoAuthorsJoinedInOneTrailerParagraph() async throws {
        let client = RecordingGitClient()
        let options = CommitOptions(coAuthors: [
            CommitAuthor(name: "Jane Doe", email: "jane@example.com"),
            CommitAuthor(name: "John Roe", email: "john@example.com")
        ])
        try await makeSUT(client).commit(
            in: repoURL, paths: ["a.txt"], summary: "Subject", description: "Body", options: options
        )
        let commit = await client.commitCall
        XCTAssertEqual(commit, [
            "commit", "-m", "Subject", "-m", "Body",
            "-m", "Co-authored-by: Jane Doe <jane@example.com>\nCo-authored-by: John Roe <john@example.com>"
        ])
    }

    func testTrailerComesBeforeFlags() async throws {
        let client = RecordingGitClient()
        let options = CommitOptions(
            signOff: true,
            coAuthors: [CommitAuthor(name: "Jane Doe", email: "jane@example.com")]
        )
        try await makeSUT(client).commit(
            in: repoURL, paths: ["a.txt"], summary: "Subject", description: nil, options: options
        )
        let commit = await client.commitCall
        XCTAssertEqual(commit, [
            "commit", "-m", "Subject",
            "-m", "Co-authored-by: Jane Doe <jane@example.com>",
            "--signoff"
        ])
    }
}
