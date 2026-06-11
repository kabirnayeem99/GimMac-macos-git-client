import XCTest
@testable import GimMac

/// Exercises the full `RepositoryCreationOrchestrator` pipeline against a real
/// Git binary: `git init` → scaffold files → "Initial commit".
final class RepositoryCreationIntegrationTests: XCTestCase {
    private var parentDir: URL!

    override func setUpWithError() throws {
        parentDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("gimmac-create-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: parentDir)
    }

    private func makeOrchestrator() -> RepositoryCreationOrchestrator {
        let client = ProcessGitClient()
        return RepositoryCreationOrchestrator(
            initProvider: IdentitySeedingInitProvider(client: client),
            scaffolding: FileRepositoryScaffolding(),
            catalog: StubTemplateCatalog(),
            commitProvider: GitCommitProvider(client: client, logger: GimMacLogger()),
            configReader: StubConfigReader(),
            currentYear: { "2026" }
        )
    }

    func testCreatesRepositoryWithAllOptionsAndInitialCommit() async throws {
        let repo = parentDir.appendingPathComponent("FullRepo", isDirectory: true)
        let options = RepositoryCreationOptions(
            name: "FullRepo",
            description: "A test project",
            includeReadme: true,
            gitIgnoreTemplateName: "Swift",
            licenseName: "MIT License",
            makeInitialCommit: true
        )

        try await makeOrchestrator().createRepository(with: options, at: repo)

        // Working-tree files.
        XCTAssertEqual(try contents(of: repo, "README.md"), "# FullRepo\nA test project\n")
        XCTAssertEqual(try contents(of: repo, ".gitignore"), "build/\n")
        XCTAssertEqual(
            try contents(of: repo, ".gitattributes"),
            "# Auto detect text files and perform LF normalization\n* text=auto\n"
        )
        XCTAssertEqual(try contents(of: repo, "LICENSE"), "MIT 2026 Ada Lovelace\n")
        // .git/description (not part of the working tree).
        XCTAssertEqual(try contents(of: repo, ".git/description"), "A test project")

        // Exactly one commit, summary "Initial commit".
        XCTAssertEqual(try git(["log", "--pretty=%s"], in: repo), "Initial commit")
        // Clean working tree — everything was committed.
        XCTAssertEqual(try git(["status", "--porcelain"], in: repo), "")
    }

    func testCreatesBareRepositoryWhenInitialCommitDisabled() async throws {
        let repo = parentDir.appendingPathComponent("NoCommitRepo", isDirectory: true)
        let options = RepositoryCreationOptions(
            name: "NoCommitRepo",
            includeReadme: true,
            makeInitialCommit: false
        )

        try await makeOrchestrator().createRepository(with: options, at: repo)

        XCTAssertEqual(try contents(of: repo, "README.md"), "# NoCommitRepo\n")
        // No commit was made — `git log` exits non-zero on an unborn branch.
        XCTAssertThrowsError(try git(["log", "--pretty=%s"], in: repo))
        // README + .gitattributes are present but untracked.
        XCTAssertTrue(try git(["status", "--porcelain"], in: repo).contains("README.md"))
    }

    // MARK: - Helpers

    private func contents(of repo: URL, _ relativePath: String) throws -> String {
        try String(contentsOf: repo.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Run git and return trimmed stdout; throws on non-zero exit.
    @discardableResult
    private func git(_ args: [String], in directory: URL) throws -> String {
        let process = Process()
        process.currentDirectoryURL = directory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let output = String(
            data: stdout.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        if process.terminationStatus != 0 {
            throw GitTestError.nonZeroExit(args)
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum GitTestError: Error { case nonZeroExit([String]) }
}

// MARK: - Test doubles

/// Runs a real `git init` then seeds a deterministic local identity so the
/// initial commit succeeds regardless of the machine's global git config.
private struct IdentitySeedingInitProvider: RepositoryInitProviding {
    let client: GitClientProtocol

    func initRepository(at directoryURL: URL) async throws {
        _ = try await client.run(["init"], in: directoryURL, timeout: 15)
        _ = try await client.run(["config", "user.name", "Ada Lovelace"], in: directoryURL, timeout: 5)
        _ = try await client.run(["config", "user.email", "ada@example.com"], in: directoryURL, timeout: 5)
        _ = try await client.run(["config", "commit.gpgsign", "false"], in: directoryURL, timeout: 5)
    }
}

private struct StubTemplateCatalog: RepositoryTemplateCatalog {
    func gitIgnoreTemplateNames() async -> [String] { ["Swift"] }

    func gitIgnoreTemplate(named name: String) async throws -> String {
        guard name == "Swift" else {
            throw GitAppError.scaffoldingFailed(file: ".gitignore", reason: "unknown: \(name)")
        }
        return "build/\n"
    }

    func licenses() async -> [LicenseTemplate] {
        [LicenseTemplate(name: "MIT License", featured: true, body: "MIT {year} {fullname}\n")]
    }
}

private struct StubConfigReader: GitConfigReading {
    func globalUserName() async throws -> String? { "Ada Lovelace" }
    func globalUserEmail() async throws -> String? { "ada@example.com" }
}
