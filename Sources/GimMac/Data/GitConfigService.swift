import Foundation

final class GitConfigService: GitConfigReading, GitConfigWriting, Sendable {
    private let client: GitClientProtocol
    private let homeURL: URL

    init(client: GitClientProtocol) {
        self.client = client
        self.homeURL = FileManager.default.homeDirectoryForCurrentUser
    }

    func globalUserName() async throws -> String? {
        try await readGlobalConfig("user.name")
    }

    func globalUserEmail() async throws -> String? {
        try await readGlobalConfig("user.email")
    }

    func setGlobalUserName(_ name: String) async throws {
        try await writeGlobalConfig("user.name", value: name)
    }

    func setGlobalUserEmail(_ email: String) async throws {
        try await writeGlobalConfig("user.email", value: email)
    }

    private func readGlobalConfig(_ key: String) async throws -> String? {
        do {
            let result = try await client.run(["config", "--global", key], in: homeURL, timeout: 5)
            let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        } catch let error as GitAppError {
            // `git config --global <key>` exits 1 when the key is not set.
            if case .commandFailed(_, let exitCode, _, _) = error, exitCode == 1 {
                return nil
            }
            throw error
        }
    }

    private func writeGlobalConfig(_ key: String, value: String) async throws {
        _ = try await client.run(["config", "--global", key, value], in: homeURL, timeout: 5)
    }
}
