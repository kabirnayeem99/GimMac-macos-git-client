import XCTest

final class ArchitectureBoundaryTests: XCTestCase {
    func testDomainLayerDoesNotImportAppKit() throws {
        let domainFiles = try swiftFiles(in: "Sources/GimMac/Domain")
        XCTAssertFalse(domainFiles.isEmpty, "Expected Domain files to exist.")

        for file in domainFiles {
            let contents = try String(contentsOfFile: file)
            XCTAssertFalse(
                contents.contains("import AppKit"),
                "Domain must not import AppKit: \(file)"
            )
        }
    }

    func testDataLayerDoesNotImportAppKit() throws {
        let dataFiles = try swiftFiles(in: "Sources/GimMac/Data")
        XCTAssertFalse(dataFiles.isEmpty, "Expected Data files to exist.")

        for file in dataFiles {
            let contents = try String(contentsOfFile: file)
            XCTAssertFalse(
                contents.contains("import AppKit"),
                "Data layer must not import AppKit: \(file)"
            )
        }
    }

    func testPresentationLayerDoesNotImportDataLayerTypes() throws {
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
                XCTFail("Presentation must not depend on Data concrete type '\(marker)': \(file)")
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
        let items = try fileManager.contentsOfDirectory(atPath: directory)

        return items
            .filter { $0.hasSuffix(".swift") }
            .map { "\(directory)/\($0)" }
            .sorted()
    }
}
