import Foundation

struct CommitFile: Identifiable, Equatable, Sendable {
    var id: String { path }
    let path: String
    let status: GitFileStatus
}
