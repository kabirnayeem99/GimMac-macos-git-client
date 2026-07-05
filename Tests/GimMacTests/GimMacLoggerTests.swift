import XCTest
@testable import GimMac

final class GimMacLoggerTests: XCTestCase {
    func testWritesRuntimeAndOpenTelemetryFieldsOnBackgroundFlush() async throws {
        let fileURL = makeLogFileURL()
        let logger = GimMacLogger(
            fileURL: fileURL,
            configuration: .init(isEnabled: true, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
        )

        logger.info("Loaded repository", category: .repository, metadata: ["repository": "GimMac"])
        await logger.flush()

        let entry = try readEntries(from: fileURL).first
        XCTAssertEqual(entry?.kind, .event)
        XCTAssertEqual(entry?.message, "Loaded repository")
        XCTAssertEqual(entry?.severityText, LogLevel.info.rawValue)
        XCTAssertEqual(entry?.severityNumber, 9)
        XCTAssertEqual(entry?.body, "Loaded repository")
        XCTAssertEqual(entry?.attributes?["repository"], "GimMac")
        XCTAssertEqual(entry?.attributes?["log.category"], LogCategory.repository.rawValue)
        XCTAssertNotNil(entry?.runtimeMilliseconds)
        XCTAssertNotNil(entry?.timeUnixNano)
        XCTAssertNotNil(entry?.observedTimeUnixNano)
    }

    func testDisabledLoggerDoesNotWriteFile() async {
        let fileURL = makeLogFileURL()
        let logger = GimMacLogger(
            fileURL: fileURL,
            configuration: .init(isEnabled: false, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
        )

        logger.error("Should not write", category: .repository)
        await logger.flush()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testTaggedLogsCarryTraceAndSpanFields() async throws {
        let fileURL = makeLogFileURL()
        let logger = GimMacLogger(
            fileURL: fileURL,
            configuration: .init(isEnabled: true, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
        )
        let tag = logger.tag("commit-flow", metadata: ["phase": "stage"])

        logger.info("Staging files", category: .staging, metadata: ["count": "2"], tag: tag)
        await logger.flush()

        let entry = try XCTUnwrap(readEntries(from: fileURL).first)
        XCTAssertEqual(entry.traceID, tag.traceID)
        XCTAssertEqual(entry.spanID, tag.spanID)
        XCTAssertEqual(entry.attributes?["flow.name"], "commit-flow")
        XCTAssertEqual(entry.attributes?["flow.phase"], "stage")
        XCTAssertEqual(entry.attributes?["count"], "2")
    }

    func testGitCommandLoggingIsAppendedWithGitAttributes() async throws {
        let fileURL = makeLogFileURL()
        let logger = GimMacLogger(
            fileURL: fileURL,
            configuration: .init(isEnabled: true, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
        )
        let repositoryURL = URL(fileURLWithPath: "/tmp/GimMacRepo", isDirectory: true)

        await logger.logGitCommand(
            ["status", "--short"],
            in: repositoryURL,
            result: GitCommandResult(stdout: " M README.md", stderr: "", exitCode: 0)
        )
        await logger.flush()

        let entry = try XCTUnwrap(readEntries(from: fileURL).first)
        XCTAssertEqual(entry.kind, .git)
        XCTAssertEqual(entry.message, "git status --short")
        XCTAssertEqual(entry.repositoryPath, repositoryURL.path)
        XCTAssertEqual(entry.attributes?["git.repository_path"], repositoryURL.path)
        XCTAssertEqual(entry.attributes?["git.exit_code"], "0")
    }

    func testGitCommandLoggingRedactsCredentialsInArgumentsAndOutput() async throws {
        let fileURL = makeLogFileURL()
        let logger = GimMacLogger(
            fileURL: fileURL,
            configuration: .init(isEnabled: true, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
        )
        let repositoryURL = URL(fileURLWithPath: "/tmp/GimMacRepo", isDirectory: true)
        let remote = "https://user:secret-token@example.com/repo.git"

        await logger.logGitCommand(
            ["clone", remote],
            in: repositoryURL,
            result: GitCommandResult(
                stdout: "origin\t\(remote) (fetch)",
                stderr: "fatal: could not read access_token=abcdef",
                exitCode: 1
            )
        )
        await logger.flush()

        let entry = try XCTUnwrap(readEntries(from: fileURL).first)
        XCTAssertFalse(entry.message.contains("secret-token"))
        XCTAssertFalse(entry.stdout?.contains("secret-token") ?? false)
        XCTAssertFalse(entry.stderr?.contains("abcdef") ?? false)
        XCTAssertTrue(entry.message.contains("<redacted>"))
        XCTAssertTrue(entry.stdout?.contains("<redacted>") ?? false)
        XCTAssertTrue(entry.stderr?.contains("<redacted>") ?? false)
    }

    func testGitEventLoggingRedactsSensitiveMetadata() async throws {
        let fileURL = makeLogFileURL()
        let logger = GimMacLogger(
            fileURL: fileURL,
            configuration: .init(isEnabled: true, writesToConsole: false, maxEntries: 2_000, rotationInterval: 250)
        )

        logger.log(
            level: .debug,
            category: .git,
            message: "Phase update https://user:secret-token@example.com/repo.git",
            metadata: ["git.command": "git clone https://user:secret-token@example.com/repo.git"]
        )
        await logger.flush()

        let entry = try XCTUnwrap(readEntries(from: fileURL).first)
        XCTAssertFalse(entry.message.contains("secret-token"))
        XCTAssertFalse(entry.metadata["git.command"]?.contains("secret-token") ?? false)
        XCTAssertTrue(entry.message.contains("<redacted>"))
        XCTAssertTrue(entry.metadata["git.command"]?.contains("<redacted>") ?? false)
    }

    func testDecodesOlderLogEntryWithoutNewTelemetryFields() throws {
        let json = """
        {"kind":"event","timestamp":"2026-06-17T12:00:00.000Z","level":"INFO","category":"repository","message":"old","metadata":{}}
        """

        let entry = try JSONDecoder().decode(LogEntry.self, from: Data(json.utf8))

        XCTAssertEqual(entry.message, "old")
        XCTAssertNil(entry.runtimeMilliseconds)
        XCTAssertNil(entry.timeUnixNano)
        XCTAssertNil(entry.traceID)
    }

    private func makeLogFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("gimmac.jsonl", isDirectory: false)
    }

    private func readEntries(from fileURL: URL) throws -> [LogEntry] {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        return try contents
            .split(whereSeparator: \.isNewline)
            .map { line in
                try JSONDecoder().decode(LogEntry.self, from: Data(String(line).utf8))
            }
    }
}
