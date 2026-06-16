import Foundation
import Observation

/// Drives the Prompts pane of Settings: which destructive actions ask for
/// confirmation, the uncommitted-changes branch-switch strategy, and the
/// commit-length warning. Native equivalent of GitHub Desktop's `Prompts`
/// preferences panel (`ui/preferences/prompts.tsx`). Each property writes
/// through to `AppSettingsStoring` on change.
@MainActor
@Observable
final class PromptsSettingsViewModel {
    var confirmRepositoryRemoval: Bool { didSet { store.confirmRepositoryRemoval = confirmRepositoryRemoval } }
    var confirmDiscardChanges: Bool { didSet { store.confirmDiscardChanges = confirmDiscardChanges } }
    var confirmDiscardChangesPermanently: Bool {
        didSet { store.confirmDiscardChangesPermanently = confirmDiscardChangesPermanently }
    }
    var confirmDiscardStash: Bool { didSet { store.confirmDiscardStash = confirmDiscardStash } }
    var confirmCheckoutCommit: Bool { didSet { store.confirmCheckoutCommit = confirmCheckoutCommit } }
    var confirmForcePush: Bool { didSet { store.confirmForcePush = confirmForcePush } }
    var confirmUndoCommit: Bool { didSet { store.confirmUndoCommit = confirmUndoCommit } }
    var confirmCommitFilteredChanges: Bool {
        didSet { store.confirmCommitFilteredChanges = confirmCommitFilteredChanges }
    }
    var uncommittedChangesStrategy: UncommittedChangesStrategy {
        didSet { store.uncommittedChangesStrategy = uncommittedChangesStrategy }
    }
    var showCommitLengthWarning: Bool { didSet { store.showCommitLengthWarning = showCommitLengthWarning } }

    private let store: any AppSettingsStoring

    init(store: any AppSettingsStoring) {
        self.store = store
        confirmRepositoryRemoval = store.confirmRepositoryRemoval
        confirmDiscardChanges = store.confirmDiscardChanges
        confirmDiscardChangesPermanently = store.confirmDiscardChangesPermanently
        confirmDiscardStash = store.confirmDiscardStash
        confirmCheckoutCommit = store.confirmCheckoutCommit
        confirmForcePush = store.confirmForcePush
        confirmUndoCommit = store.confirmUndoCommit
        confirmCommitFilteredChanges = store.confirmCommitFilteredChanges
        uncommittedChangesStrategy = store.uncommittedChangesStrategy
        showCommitLengthWarning = store.showCommitLengthWarning
    }
}
