import XCTest

final class ArchitectureBoundaryTests: XCTestCase {
    func testApplicationModelsAndPortsDoNotImportAppKit() throws {
        let applicationFiles = try swiftFiles(in: "Sources/GimMac/Application")
        XCTAssertFalse(applicationFiles.isEmpty, "Expected Application files to exist.")

        for file in applicationFiles {
            let contents = try String(contentsOfFile: file)
            XCTAssertFalse(
                contents.contains("import AppKit"),
                "Application must not import AppKit: \(file)"
            )
        }
    }

    func testInfrastructureDoesNotImportAppKit() throws {
        let infrastructureFiles = try swiftFiles(in: "Sources/GimMac/Infrastructure")
            .filter { !$0.contains("/Infrastructure/Platform/") }
        XCTAssertFalse(infrastructureFiles.isEmpty, "Expected Infrastructure files to exist.")

        for file in infrastructureFiles {
            let contents = try String(contentsOfFile: file)
            XCTAssertFalse(
                contents.contains("import AppKit"),
                "Infrastructure must not import AppKit outside Platform: \(file)"
            )
        }
    }

    func testPresentationLayerDoesNotImportInfrastructureConcreteTypes() throws {
        let presentationFiles = try swiftFiles(in: "Sources/GimMac/Presentation")
        XCTAssertFalse(presentationFiles.isEmpty, "Expected Presentation files to exist.")

        let forbiddenMarkers = [
            "ProcessGitClient",
            "LocalGitRepositoryInspector",
            "GitAppErrorMapper",
            "GitCommandBuilder"
        ]

        for file in presentationFiles {
            let contents = try String(contentsOfFile: file)
            for marker in forbiddenMarkers where contents.contains(marker) {
                XCTFail("Presentation must not depend on Infrastructure concrete type '\(marker)': \(file)")
            }
        }
    }

    private func swiftFiles(in relativeDirectory: String) throws -> [String] {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = repoRoot.appendingPathComponent(relativeDirectory).path

        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? String }
            .filter { $0.hasSuffix(".swift") }
            .map { "\(directory)/\($0)" }
            .sorted()
    }
}
