import Foundation
import Observation

@MainActor
@Observable
final class CommitFormHandler {
    var commitSummary = ""
    var commitDescription = ""
    private(set) var isCommitting = false
    private(set) var isAmendMode = false
    var skipHooks = false
    var signOff = false

    var trimmedSummary: String { commitSummary.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDescription: String { commitDescription.trimmingCharacters(in: .whitespacesAndNewlines) }

    var summaryCharacterCount: Int { commitSummary.count }
    var summaryExceedsRecommendedLength: Bool { summaryCharacterCount > 72 }

    func prefill(summary: String, body: String?) {
        if commitSummary.isEmpty { commitSummary = summary }
        if commitDescription.isEmpty { commitDescription = body ?? "" }
    }

    func reset() {
        commitSummary = ""
        commitDescription = ""
        isAmendMode = false
    }

    func setCommitting(_ value: Bool) {
        isCommitting = value
    }

    func toggleAmend() {
        isAmendMode.toggle()
    }
}
