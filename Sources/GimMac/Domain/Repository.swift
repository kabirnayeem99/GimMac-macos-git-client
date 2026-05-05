import Foundation

struct Repository: Equatable {
    let url: URL

    var displayName: String {
        url.lastPathComponent
    }
}
