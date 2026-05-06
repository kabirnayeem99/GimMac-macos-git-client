import Foundation

struct Repository: Equatable {
    let url: URL

    var displayName: String {
        url.lastPathComponent
    }
}

struct StoredRepository: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let path: String
    let gitIdentifier: String?
    let currentlySelected: Bool
    let lastOpenedAt: Date
    let createdAt: Date
    let updatedAt: Date
    let existsOnDisk: Bool

    var url: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }
}
