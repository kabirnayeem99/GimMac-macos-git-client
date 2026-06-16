import Foundation

struct Commit: Identifiable, Equatable, Sendable {
    let id: String // full hash
    let shortHash: String
    let authorName: String
    let authorEmail: String
    let date: Date
    let summary: String
    let body: String?

    var authorDisplayName: String {
        return authorName
    }
}
