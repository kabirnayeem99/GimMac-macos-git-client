import XCTest
@testable import GimMac

final class GitAppErrorMapperTests: XCTestCase {
    func testMapsNotARepository() {
        let error = GitAppErrorMapper.map(
            command: ["status"],
            exitCode: 128,
            stdout: "",
            stderr: "fatal: not a git repository (or any of the parent directories): .git"
        )

        XCTAssertEqual(error, .notARepository)
    }

    func testMapsPermissionDenied() {
        let error = GitAppErrorMapper.map(
            command: ["status"],
            exitCode: 1,
            stdout: "",
            stderr: "permission denied"
        )

        XCTAssertEqual(error, .permissionDenied)
    }

    func testFallsBackToCommandFailed() {
        let error = GitAppErrorMapper.map(
            command: ["status"],
            exitCode: 2,
            stdout: "out",
            stderr: "generic"
        )

        XCTAssertEqual(
            error,
            .commandFailed(command: ["status"], exitCode: 2, stdout: "out", stderr: "generic")
        )
    }
}
