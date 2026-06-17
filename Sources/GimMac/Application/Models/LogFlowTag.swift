import Foundation

struct LogFlowTag: Codable, Equatable, Sendable {
    let name: String
    let traceID: String
    let spanID: String
    let parentSpanID: String?
    let startedRuntimeMilliseconds: Double
    let metadata: [String: String]

    init(
        name: String,
        parent: LogFlowTag? = nil,
        metadata: [String: String] = [:],
        runtimeMilliseconds: Double = ProcessInfo.processInfo.systemUptime * 1_000
    ) {
        self.name = name
        self.traceID = parent?.traceID ?? Self.makeTraceID()
        self.spanID = Self.makeSpanID()
        self.parentSpanID = parent?.spanID
        self.startedRuntimeMilliseconds = runtimeMilliseconds
        self.metadata = metadata
    }

    private static func makeTraceID() -> String {
        (UUID().uuidString + UUID().uuidString)
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefixString(length: 32)
    }

    private static func makeSpanID() -> String {
        UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
            .prefixString(length: 16)
    }
}

private extension StringProtocol {
    func prefixString(length: Int) -> String {
        String(prefix(length))
    }
}
