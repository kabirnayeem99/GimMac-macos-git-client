import Foundation
import Observation

@MainActor
@Observable
final class CommitFormHandler {
    var commitSummary = ""
    var commitDescription = ""
    private(set) var isCommitting = false

    var trimmedSummary: String { commitSummary.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDescription: String { commitDescription.trimmingCharacters(in: .whitespacesAndNewlines) }

    func prefill(summary: String, body: String?) {
        if commitSummary.isEmpty { commitSummary = summary }
        if commitDescription.isEmpty { commitDescription = body ?? "" }
    }

    func reset() {
        commitSummary = ""
        commitDescription = ""
    }

    func setCommitting(_ value: Bool) {
        isCommitting = value
    }
}
