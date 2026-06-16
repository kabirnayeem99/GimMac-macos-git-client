import Foundation

enum GitCommandBuilder {
    static func revParseHeadShort() -> [String] {
        ["rev-parse", "--short", "HEAD"]
    }

    static func statusPorcelainV1() -> [String] {
        ["status", "--porcelain=v1", "-z"]
    }

    static func withPath(_ command: [String], path: String) -> [String] {
        command + ["--", path]
    }
}
