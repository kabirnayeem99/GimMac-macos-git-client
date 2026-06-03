enum LogCategory: String, Codable, Sendable {
    case git        = "git"
    case staging    = "staging"
    case commit     = "commit"
    case branch     = "branch"
    case diff       = "diff"
    case repository = "repository"
}
