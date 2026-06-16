import Foundation

@MainActor
extension RepositoryStoreViewModel {
    func signalSyncOutcome(_ outcome: OpOutcome) {
        syncOutcome = outcome
        syncOutcomeResetTask?.cancel()
        syncOutcomeResetTask = resetOutcome(after: .seconds(1.2)) { [weak self] in
            self?.syncOutcome = .none
        }
    }

    func signalCommitOutcome(_ outcome: OpOutcome) {
        commitOutcome = outcome
        commitOutcomeResetTask?.cancel()
        commitOutcomeResetTask = resetOutcome(after: .seconds(1.2)) { [weak self] in
            self?.commitOutcome = .none
        }
    }

    func signalHistoryOutcome(_ outcome: OpOutcome) {
        historyOutcome = outcome
        historyOutcomeResetTask?.cancel()
        historyOutcomeResetTask = resetOutcome(after: .seconds(1.2)) { [weak self] in
            self?.historyOutcome = .none
        }
    }

    func signalConflictContinueOutcome(_ outcome: OpOutcome) {
        conflictContinueOutcome = outcome
        conflictOutcomeResetTask?.cancel()
        conflictOutcomeResetTask = resetOutcome(after: .seconds(1.2)) { [weak self] in
            self?.conflictContinueOutcome = .none
        }
    }

    func signalRecentlyResolvedConflict(_ file: ConflictedFileStatus) {
        recentlyResolvedConflict = file
        recentlyResolvedConflictResetTask?.cancel()
        recentlyResolvedConflictResetTask = resetOutcome(after: .seconds(0.9)) { [weak self] in
            self?.recentlyResolvedConflict = nil
        }
    }

    func resetOperationOutcomes() {
        syncOutcomeResetTask?.cancel()
        commitOutcomeResetTask?.cancel()
        historyOutcomeResetTask?.cancel()
        conflictOutcomeResetTask?.cancel()
        recentlyResolvedConflictResetTask?.cancel()
        syncOutcome = .none
        commitOutcome = .none
        historyOutcome = .none
        conflictContinueOutcome = .none
        recentlyResolvedConflict = nil
    }

    private func resetOutcome(
        after duration: Duration,
        reset: @escaping @MainActor @Sendable () -> Void
    ) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(for: duration)
                reset()
            } catch {
                // Cancellation means a newer outcome owns the reset timer.
            }
        }
    }
}
