import XCTest
@testable import GimMac

final class FileRepositoryScaffoldingTests: XCTestCase {
    private var repoURL: URL!
    private let sut = FileRepositoryScaffolding()

    override func setUpWithError() throws {
        repoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("gimmac-scaffold-tests-\(UUID().uuidString)", isDirectory: true)
        // Include a `.git` directory so writeGitDescription has somewhere to land.
        try FileManager.default.createDirectory(
            at: repoURL.appendingPathComponent(".git"),
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: repoURL)
    }

    private func read(_ relativePath: String) throws -> String {
        try String(contentsOf: repoURL.appendingPathComponent(relativePath), encoding: .utf8)
    }

    // MARK: - README

    func testWritesReadmeWithTitleOnlyWhenNoDescription() async throws {
        try await sut.writeReadme(name: "MyRepo", description: nil, in: repoURL)
        XCTAssertEqual(try read("README.md"), "# MyRepo\n")
    }

    func testWritesReadmeWithDescriptionParagraph() async throws {
        try await sut.writeReadme(name: "MyRepo", description: "A cool project", in: repoURL)
        XCTAssertEqual(try read("README.md"), "# MyRepo\nA cool project\n")
    }

    func testTreatsWhitespaceOnlyDescriptionAsAbsent() async throws {
        try await sut.writeReadme(name: "MyRepo", description: "   \n  ", in: repoURL)
        XCTAssertEqual(try read("README.md"), "# MyRepo\n")
    }

    // MARK: - .gitignore / .gitattributes

    func testWritesGitIgnoreVerbatim() async throws {
        try await sut.writeGitIgnore(contents: "build/\n*.log\n", in: repoURL)
        XCTAssertEqual(try read(".gitignore"), "build/\n*.log\n")
    }

    func testWritesGitAttributesWithLFNormalization() async throws {
        try await sut.writeGitAttributes(in: repoURL)
        XCTAssertEqual(
            try read(".gitattributes"),
            "# Auto detect text files and perform LF normalization\n* text=auto\n"
        )
    }

    // MARK: - .git/description

    func testWritesGitDescription() async throws {
        try await sut.writeGitDescription("My project description", in: repoURL)
        XCTAssertEqual(try read(".git/description"), "My project description")
    }

    // MARK: - LICENSE token substitution

    func testSubstitutesCurlyTokensInLicense() async throws {
        let license = LicenseTemplate(
            name: "Test",
            featured: false,
            body: "Copyright (c) {year} {fullname} <{email}> — {project}\n"
        )
        let fields = LicenseFields(fullname: "Ada Lovelace", email: "ada@example.com", project: "Engine", year: "2026")
        try await sut.writeLicense(license, fields: fields, in: repoURL)
        XCTAssertEqual(try read("LICENSE"), "Copyright (c) 2026 Ada Lovelace <ada@example.com> — Engine\n")
    }

    func testNormalizesSquareBracketTokensBeforeSubstituting() async throws {
        let license = LicenseTemplate(
            name: "Test",
            featured: false,
            body: "Copyright [year] [fullname]\n"
        )
        let fields = LicenseFields(fullname: "Grace Hopper", email: "", project: "", year: "1999")
        try await sut.writeLicense(license, fields: fields, in: repoURL)
        XCTAssertEqual(try read("LICENSE"), "Copyright 1999 Grace Hopper\n")
    }

    func testSubstituteTokensIsPure() {
        let result = FileRepositoryScaffolding.substituteTokens(
            in: "{project} by {fullname}, {year}",
            fields: LicenseFields(fullname: "Linus", email: "x@y.z", project: "Kernel", year: "1991")
        )
        XCTAssertEqual(result, "Kernel by Linus, 1991")
    }
}
