import XCTest
@testable import GimMac

private actor PhaseABRecordingGitClient: GitClientProtocol {
    enum StubbedError: Error {
        case unexpectedCommand([String])
    }

    private(set) var calls: [[String]] = []
    private let resultsByCommand: [String: Result<GitCommandResult, Error>]

    init(resultsByCommand: [String: Result<GitCommandResult, Error>] = [:]) {
        self.resultsByCommand = resultsByCommand
    }

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitCommandResult {
        calls.append(arguments)
        if let result = resultsByCommand[arguments.joined(separator: "\u{1F}")] {
            return try result.get()
        }
        return GitCommandResult(stdout: "", stderr: "", exitCode: 0)
    }

    var recordedCalls: [[String]] { calls }
}

final class GitPhaseABSafetyTests: XCTestCase {
    private let repositoryURL = URL(fileURLWithPath: "/tmp/repo", isDirectory: true)

    func testBranchOperatorSeparatesUserControlledRefsFromOptions() async throws {
        let client = PhaseABRecordingGitClient()
        let sut = GitBranchOperator(client: client)
        let branch = makeBranch(name: "-danger")

        _ = try await sut.createBranch(named: "--force", from: .commit(sha: "abc123"), noTrack: true, in: repositoryURL)
        try await sut.switchBranch(to: branch, in: repositoryURL)
        try await sut.deleteLocalBranch(branch, force: true, in: repositoryURL)
        _ = try await sut.renameBranch(branch, to: "--rename-target", force: false, in: repositoryURL)
        try await sut.renameCurrentBranch(from: "--old", to: "--new", in: repositoryURL)

        let calls = await client.recordedCalls
        XCTAssertEqual(calls[0], ["branch", "--no-track", "--", "--force", "abc123"])
        XCTAssertEqual(calls[1], ["switch", "--", "-danger"])
        XCTAssertEqual(calls[2], ["branch", "-D", "--", "-danger"])
        XCTAssertEqual(calls[3], ["branch", "-m", "--", "-danger", "--rename-target"])
        XCTAssertEqual(calls[4], ["branch", "-M", "--", "--old", "--new"])
    }

    func testMergeAndRebaseOperationsSeparateRefsFromOptions() async throws {
        let client = PhaseABRecordingGitClient(resultsByCommand: [
            ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"].joined(separator: "\u{1F}"): .success(
                GitCommandResult(stdout: "origin/main\n", stderr: "", exitCode: 0)
            )
        ])

        let mergeService = GitMergeService(client: client)
        let rebaseService = GitRebaseService(client: client)
        let updateService = GitUpdateFromDefaultService(client: client)

        _ = try await mergeService.merge(branch: "--topic", noVerify: true, in: repositoryURL)
        _ = try await mergeService.squashMerge(branch: "--topic", noVerify: false, in: repositoryURL)
        _ = try await rebaseService.rebase(base: "--base", target: "--target", in: repositoryURL)
        try await updateService.mergeDefaultBranch(into: makeBranch(name: "feature"), in: repositoryURL)
        try await updateService.rebaseOntoDefaultBranch(makeBranch(name: "feature"), in: repositoryURL)

        let calls = await client.recordedCalls
        XCTAssertEqual(calls[0], ["merge", "--no-verify", "--", "--topic"])
        XCTAssertEqual(calls[1], ["merge", "--squash", "--", "--topic"])
        XCTAssertEqual(calls[2], ["commit", "--no-edit"])
        XCTAssertEqual(calls[3], ["rebase", "--", "--base", "--target"])
        XCTAssertEqual(calls[5], ["merge", "--", "origin/main"])
        XCTAssertEqual(calls[7], ["rebase", "--", "origin/main"])
    }

    func testTagCreationSeparatesTagNameAndCommitFromOptions() async throws {
        let client = PhaseABRecordingGitClient()
        let sut = GitTagProvider(client: client)
        let commit = makeCommit(id: "--head")

        try await sut.createTag(named: "--release", message: nil, at: commit, in: repositoryURL)
        try await sut.createTag(named: "--annotated", message: "v2", at: commit, in: repositoryURL)

        let calls = await client.recordedCalls
        XCTAssertEqual(calls[0], ["tag", "--", "--release", "--head"])
        XCTAssertEqual(calls[1], ["tag", "-a", "-m", "v2", "--", "--annotated", "--head"])
    }

    func testCherryPickCancellationDoesNotAbortInProgressOperation() async throws {
        let cancellation = Result<GitCommandResult, Error>.failure(CancellationError())
        let client = PhaseABRecordingGitClient(resultsByCommand: [
            ["cherry-pick", "abc123"].joined(separator: "\u{1F}"): cancellation
        ])
        let sut = GitCherryPickProvider(client: client)

        do {
            try await sut.cherryPick(commits: [makeCommit(id: "abc123")], in: repositoryURL)
            XCTFail("Expected cancellation to be rethrown")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        let calls = await client.recordedCalls
        XCTAssertEqual(calls, [["cherry-pick", "abc123"]])
    }

    func testSquashFailureAbortsRebaseBeforeRethrowing() async throws {
        let client = PhaseABRecordingGitClient(resultsByCommand: [
            ["log", "--format=%P", "-n", "1", "c1"].joined(separator: "\u{1F}"): .success(
                GitCommandResult(stdout: "", stderr: "", exitCode: 0)
            ),
            ["log", "--format=%H%x00%s", "--reverse", "HEAD"].joined(separator: "\u{1F}"): .success(
                GitCommandResult(stdout: "c1\u{0}one\nc2\u{0}two\n", stderr: "", exitCode: 0)
            ),
            ["rebase", "-i", "--root"].joined(separator: "\u{1F}"): .failure(
                GitAppError.commandFailed(command: ["rebase", "-i", "--root"], exitCode: 1, stdout: "", stderr: "conflict")
            )
        ])
        let sut = GitSquashProvider(client: client)

        do {
            try await sut.squash(commits: [makeCommit(id: "c2"), makeCommit(id: "c1")], message: "squashed", in: repositoryURL)
            XCTFail("Expected squash to fail")
        } catch let error as GitAppError {
            guard case .commandFailed = error else {
                return XCTFail("Expected commandFailed, got \(error)")
            }
        }

        let calls = await client.recordedCalls
        XCTAssertEqual(calls.suffix(2), [["rebase", "-i", "--root"], ["rebase", "--abort"]])
    }

    func testHistoryProviderAppliesDefaultLimitWhenCallerPassesNil() async throws {
        let client = PhaseABRecordingGitClient()
        let sut = GitHistoryProvider(client: client)

        _ = try await sut.fetchHistory(in: repositoryURL, maxCount: nil, skip: 25)

        let calls = await client.recordedCalls
        XCTAssertEqual(calls, [["log", "--format=\(GitLogParser.logFormat)", "-n", "200", "--skip=25"]])
    }

    private func makeBranch(name: String) -> Branch {
        Branch(
            name: name,
            ref: "refs/heads/\(name)",
            tip: .init(
                sha: "abc123",
                shortSHA: "abc123",
                authorName: "Test",
                summary: "Summary",
                date: .distantPast
            ),
            type: .local,
            upstream: nil
        )
    }

    private func makeCommit(id: String) -> Commit {
        Commit(
            id: id,
            shortHash: String(id.prefix(7)),
            authorName: "Test",
            authorEmail: "test@example.com",
            date: .distantPast,
            summary: "Summary",
            body: nil
        )
    }
}
