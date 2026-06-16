enum LogCategory: String, Codable, Sendable {
    case git
    case staging
    case commit
    case branch
    case diff
    case repository
}
