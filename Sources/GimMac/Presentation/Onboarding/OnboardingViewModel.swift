import Foundation
import Observation

enum OnboardingStep: Equatable, CaseIterable {
    case welcome
    case configureGit
}

@Observable
@MainActor
final class OnboardingViewModel {
    var step: OnboardingStep = .welcome
    var name: String = ""
    var email: String = ""
    var isSaving: Bool = false
    var errorMessage: String?
    var completionOutcome: OpOutcome = .none

    var onComplete: (@MainActor () -> Void)?

    private let configReader: GitConfigReading
    private let configWriter: GitConfigWriting

    init(configReader: GitConfigReading, configWriter: GitConfigWriting) {
        self.configReader = configReader
        self.configWriter = configWriter
    }

    func loadExistingConfig() async {
        name = (try? await configReader.globalUserName()) ?? ""
        email = (try? await configReader.globalUserEmail()) ?? ""
    }

    func advance() { step = .configureGit }
    func goBack() { step = .welcome }

    var canFinish: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        completionOutcome = .none
        do {
            let trimName = name.trimmingCharacters(in: .whitespaces)
            let trimEmail = email.trimmingCharacters(in: .whitespaces)
            if !trimName.isEmpty { try await configWriter.setGlobalUserName(trimName) }
            if !trimEmail.isEmpty { try await configWriter.setGlobalUserEmail(trimEmail) }
            completionOutcome = .success
        } catch {
            errorMessage = error.localizedDescription
            completionOutcome = .failure
        }
        isSaving = false
    }

    func clearCompletionOutcome() {
        completionOutcome = .none
    }

    func skip() { onComplete?() }
}
