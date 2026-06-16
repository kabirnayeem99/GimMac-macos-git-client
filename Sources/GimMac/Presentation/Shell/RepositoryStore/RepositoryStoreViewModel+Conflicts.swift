import Foundation

// Merge-conflict resolution: drives the conflicts sheet for an in-progress
// merge / rebase / cherry-pick. The per-file resolution flows through
// `ConflictResolutionProviding`; the continue/abort half dispatches to the
// merge / rebase / cherry-pick services by the current primary action.
//
// Native equivalent of GitHub Desktop's conflicts dialog (`conflicts-dialog.tsx`
// + `stage.ts`), replacing the previous punt-to-terminal alerts.

@MainActor
extension RepositoryStoreViewModel {
    /// The operation that produced the conflicts, derived from the primary
    /// action the repo-screen state machine resolved. `nil` when not conflicted.
    private var conflictOperation: ConflictState? {
        switch primaryAction {
        case .merge: return .merge
        case .rebase: return .rebase
        case .cherryPick: return .cherryPick
        default: return nil
        }
    }

    /// Title shown in the conflicts sheet header.
    var conflictOperationLabel: String {
        guard let operation = conflictOperation else { return "Resolve Conflicts" }
        switch operation {
        case .merge: return "Merge"
        case .rebase: return "Rebase"
        case .cherryPick: return "Cherry-Pick"
        case .none: return "Resolve Conflicts"
        }
    }

    var resolvedConflictCount: Int {
        max(0, initialConflictCount - conflictedFiles.count)
    }

    var canContinueConflictOperation: Bool {
        !isConflictActionInProgress && conflictedFiles.isEmpty && initialConflictCount > 0
    }

    // MARK: - Presentation

    /// Open the conflicts sheet and load the current unmerged file set.
    func beginConflictResolution() async {
        guard conflictResolver != nil, selectedRepository != nil else { return }
        isResolvingConflicts = true
        await loadConflicts(resetBaseline: true)
        conflictMergeToolName = await currentMergeToolName()
    }

    /// Dismiss the sheet without aborting the operation (the repo stays
    /// mid-merge/rebase; the user can resume from the primary action button).
    func cancelConflictResolution() {
        signalConflictContinueOutcome(.none)
        recentlyResolvedConflict = nil
        isResolvingConflicts = false
    }

    // MARK: - Loading

    private func loadConflicts(resetBaseline: Bool) async {
        guard let resolver = conflictResolver, let repository = selectedRepository else { return }
        do {
            let files = try await resolver.conflictedFiles(in: repository.url)
            conflictedFiles = files
            if resetBaseline { initialConflictCount = files.count }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func currentMergeToolName() async -> String? {
        guard let resolver = conflictResolver, let repository = selectedRepository else { return nil }
        return await resolver.mergeToolName(in: repository.url)
    }

    // MARK: - Per-file actions

    func resolveConflict(_ file: ConflictedFileStatus, using resolution: ManualConflictResolution) async {
        await runConflictAction(resolvedFile: file) { resolver, url in
            try await resolver.stageManualConflictResolution(
                file.path, summary: file.summary, resolution: resolution, in: url
            )
        }
    }

    /// Accept the deletion for a both-deleted conflict (`git rm`).
    func acceptConflictDeletion(_ file: ConflictedFileStatus) async {
        await runConflictAction(resolvedFile: file) { resolver, url in
            try await resolver.removeConflictedFile(file.path, in: url)
        }
    }

    /// Mark a hand-edited file as resolved (`git add`).
    func markConflictResolved(_ file: ConflictedFileStatus) async {
        await runConflictAction(resolvedFile: file) { resolver, url in
            try await resolver.markResolved(file.path, in: url)
        }
    }

    func openConflictInMergeTool(_ file: ConflictedFileStatus) async {
        await runConflictAction { resolver, url in
            try await resolver.openInMergeTool(file.path, in: url)
        }
    }

    /// Shared scaffolding for a per-file action: gate UI, run, reload the set,
    /// surface errors. Does not reset the baseline count.
    private func runConflictAction(
        resolvedFile: ConflictedFileStatus? = nil,
        _ action: (ConflictResolutionProviding, URL) async throws -> Void
    ) async {
        guard let resolver = conflictResolver, let repository = selectedRepository,
              !isConflictActionInProgress else { return }
        isConflictActionInProgress = true
        errorMessage = nil
        defer { isConflictActionInProgress = false }
        do {
            try await action(resolver, repository.url)
            if let resolvedFile {
                signalRecentlyResolvedConflict(resolvedFile)
            }
            await loadConflicts(resetBaseline: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Continue / Abort

    func continueConflictOperation() async {
        guard let operation = conflictOperation,
              let repository = selectedRepository,
              !isConflictActionInProgress else { return }
        isConflictActionInProgress = true
        errorMessage = nil
        defer { isConflictActionInProgress = false }

        do {
            switch operation {
            case .merge:
                guard let mergeService else { return }
                try await mergeService.createMergeCommit(in: repository.url)
            case .rebase:
                guard let rebaseService else { return }
                if try await rebaseService.continueRebase(in: repository.url) == .conflicts {
                    await finishOrReload(repository: repository)
                    return
                }
            case .cherryPick:
                guard let cherryPickProvider else { return }
                if try await cherryPickProvider.continueCherryPick(in: repository.url) == .conflicts {
                    await finishOrReload(repository: repository)
                    return
                }
            case .none:
                return
            }
            signalConflictContinueOutcome(.success)
            try? await Task.sleep(for: .milliseconds(800))
            isResolvingConflicts = false
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func abortConflictOperation() async {
        guard let operation = conflictOperation,
              let repository = selectedRepository,
              !isConflictActionInProgress else { return }
        isConflictActionInProgress = true
        errorMessage = nil
        defer { isConflictActionInProgress = false }

        do {
            switch operation {
            case .merge: try await mergeService?.abortMerge(in: repository.url)
            case .rebase: try await rebaseService?.abortRebase(in: repository.url)
            case .cherryPick: try await cherryPickProvider?.abortCherryPick(in: repository.url)
            case .none: return
            }
            isResolvingConflicts = false
            await refreshRepositoryScreenData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// After a rebase/cherry-pick step that stopped on the next commit's
    /// conflicts: refresh and reload the new conflict set, keeping the sheet open.
    private func finishOrReload(repository: Repository) async {
        signalConflictContinueOutcome(.none)
        await refreshRepositoryScreenData()
        await loadConflicts(resetBaseline: true)
    }
}
