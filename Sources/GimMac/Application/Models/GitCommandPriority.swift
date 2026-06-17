import Foundation

enum GitCommandPriority: String, Sendable {
    case userInteractive
    case visible
    case background
}
