import Foundation

enum GitCommandBuilder {
    static func revParseHeadShort() -> [String] {
        ["rev-parse", "--short", "HEAD"]
    }

    static func withPath(_ command: [String], path: String) -> [String] {
        command + ["--", path]
    }
}
