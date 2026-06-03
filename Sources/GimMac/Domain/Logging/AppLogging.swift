protocol AppLogging: Sendable {
    func log(level: LogLevel, category: LogCategory, message: String, metadata: [String: String])
}

extension AppLogging {
    func debug(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }

    func info(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }

    func warning(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }

    func error(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .error, category: category, message: message, metadata: metadata)
    }
}
