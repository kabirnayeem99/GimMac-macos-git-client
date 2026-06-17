protocol AppLogging: Sendable {
    func tag(_ name: String, parent: LogFlowTag?, metadata: [String: String]) -> LogFlowTag
    func log(level: LogLevel, category: LogCategory, message: String, metadata: [String: String])
    func log(level: LogLevel, category: LogCategory, message: String, metadata: [String: String], tag: LogFlowTag?)
}

extension AppLogging {
    func tag(_ name: String, parent: LogFlowTag? = nil, metadata: [String: String] = [:]) -> LogFlowTag {
        LogFlowTag(name: name, parent: parent, metadata: metadata)
    }

    func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        metadata: [String: String],
        tag: LogFlowTag?
    ) {
        var taggedMetadata = metadata
        if let tag {
            taggedMetadata["flow.name"] = tag.name
            taggedMetadata["trace_id"] = tag.traceID
            taggedMetadata["span_id"] = tag.spanID
            if let parentSpanID = tag.parentSpanID {
                taggedMetadata["parent_span_id"] = parentSpanID
            }
        }
        log(level: level, category: category, message: message, metadata: taggedMetadata)
    }

    func debug(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }

    func debug(_ message: String, category: LogCategory, metadata: [String: String] = [:], tag: LogFlowTag?) {
        log(level: .debug, category: category, message: message, metadata: metadata, tag: tag)
    }

    func info(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }

    func info(_ message: String, category: LogCategory, metadata: [String: String] = [:], tag: LogFlowTag?) {
        log(level: .info, category: category, message: message, metadata: metadata, tag: tag)
    }

    func warning(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }

    func warning(_ message: String, category: LogCategory, metadata: [String: String] = [:], tag: LogFlowTag?) {
        log(level: .warning, category: category, message: message, metadata: metadata, tag: tag)
    }

    func error(_ message: String, category: LogCategory, metadata: [String: String] = [:]) {
        log(level: .error, category: category, message: message, metadata: metadata)
    }

    func error(_ message: String, category: LogCategory, metadata: [String: String] = [:], tag: LogFlowTag?) {
        log(level: .error, category: category, message: message, metadata: metadata, tag: tag)
    }
}
