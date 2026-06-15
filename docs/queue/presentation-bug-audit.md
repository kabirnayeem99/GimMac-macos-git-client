# Presentation Bug Audit

Scope: `Sources/GimMac/Presentation` only.

This document consolidates the Engineering Lead audit plus parallel specialist reviews for concrete
bugs, UI issues, accessibility gaps, and state-management risks. Findings are de-duplicated and
ordered by severity.

## Major

### 1. Repository selection can publish stale state from an older selection

- Files:
  - `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel+Repository.swift`
  - `Sources/GimMac/Presentation/AppShell/MainSplitViewController.swift`
- Lines:
  - `RepositoryStoreViewModel+Repository.swift:7-24, 83-121`
  - `MainSplitViewController.swift:19-22, 118-120`
- Evidence:
  - `selectRepository(at:)` updates shared UI state after multiple `await` points.
  - `refreshRepositoryScreenData()` reads mutable `selectedRepository` instead of a captured request.
  - Callers start untracked `Task`s for repository selection.
- User impact:
  - Quickly switching repositories can let an older async load overwrite `tip`, `changedFiles`,
    `commits`, `errorMessage`, or loading state for the currently selected repository.
- Suggested fix:
  - Add a repository-selection generation token or captured URL check after each `await`.
  - Cancel or replace any in-flight repository-selection task.

### 2. Changed-file diff selection can show stale diff content for the wrong file

- Files:
  - `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel+FileActions.swift`
  - `Sources/GimMac/Presentation/ViewModels/DiffHandler.swift`
  - `Sources/GimMac/Presentation/Changes/Sidebar.swift`
  - `Sources/GimMac/Presentation/History/ChangedFilesColumn.swift`
- Lines:
  - `RepositoryStoreViewModel+FileActions.swift:13-18`
  - `DiffHandler.swift:26-52`
  - `Sidebar.swift:386-393`
  - `ChangedFilesColumn.swift:9-16`
- Evidence:
  - `selectChangedFile(path:)` starts a new `Task` each selection.
  - `DiffHandler.loadDiff` does not cancel prior requests and does not verify the selected path is
    still current after the async fetch completes.
- User impact:
  - Rapid selection changes can render file A's diff after the user has already selected file B.
- Suggested fix:
  - Store and cancel the in-flight diff task, or pass a request ID/path and guard it after each
    `await` before publishing the diff.

### 3. History diff can be overwritten by an older commit when the selected path is the same

- Files:
  - `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel+History.swift`
  - `Sources/GimMac/Presentation/ViewModels/HistoryHandler.swift`
- Lines:
  - `RepositoryStoreViewModel+History.swift:20-38, 68-81`
  - `HistoryHandler.swift:107-124`
- Evidence:
  - Changing commits cancels `historyLoadTask`, but does not cancel `historyFileDiffTask`.
  - `HistoryHandler.loadDiff` guards only on `selectedCommitFilePath == path`, not on `commitSHA`.
- User impact:
  - If two commits both select the same file path, a late diff from the older commit can replace the
    visible diff for the newer commit.
- Suggested fix:
  - Cancel `historyFileDiffTask` when changing commits.
  - Track and validate the active `(commitSHA, path)` pair before assigning `diffDocument`.

### 4. Branch view model can write branch state for the wrong repository after retargeting

- File: `Sources/GimMac/Presentation/ViewModels/BranchesViewModel.swift`
- Lines: `105-123, 147-166, 171-186`
- Evidence:
  - `setRepository(_:, currentBranchName:)` retargets the view model.
  - `loadBranches()`, `switchBranch(to:)`, and stash-resolution flows capture `repositoryURL`, await,
    then assign state without confirming the view model still targets the same repository.
- User impact:
  - Branch list, current branch indicator, or pending state can update with data from a previously
    selected repository.
- Suggested fix:
  - Capture `repositoryURL` per operation and verify it still matches after each `await`.
  - Add cancellation or a generation counter for branch loads and switch operations.

### 5. Branch row state does not refresh when only current or pending state changes

- File: `Sources/GimMac/Presentation/Branches/BranchesViewController.swift`
- Lines: `139-155, 166-188, 321-327`
- Evidence:
  - `render()` observes `currentBranchName`, `lastOutcome`, and `pendingBranchName`.
  - Visible-row reconfiguration is nested under `if newRows != renderedBranches`, so transient row
    state is not refreshed unless the array contents also change.
- User impact:
  - Current-branch indicators, pending progress, or success state can fail to update after a switch.
- Suggested fix:
  - Reconfigure visible rows whenever transient state changes, not only when the branch array changes.

### 6. Branch toolbar popover is mouse-only and not keyboard or VoiceOver accessible

- File: `Sources/GimMac/Presentation/Branches/BranchesPopoverPresenter.swift`
- Lines: `14-37, 100-136`
- Evidence:
  - The presenter uses a custom `ClickableContainerView`.
  - Interaction is implemented through `mouseDown(with:)` only.
  - No button role, keyboard activation, or accessibility press action is exposed.
- User impact:
  - Keyboard users and VoiceOver users may be unable to focus or open the branch picker.
- Suggested fix:
  - Replace the host with `NSButton`/SwiftUI `Button`, or make the custom view focusable with button
    accessibility role and Return/Space activation.

### 7. Switch-branch dirty-working-tree sheet can clip or compress its action buttons

- File: `Sources/GimMac/Presentation/Branches/StashAndSwitchSheetController.swift`
- Lines: `34, 48-61, 75-82`
- Evidence:
  - The sheet width is fixed at `420`.
  - Three long action buttons are laid out in a single horizontal row with no wrapping or alternate
    layout.
- User impact:
  - Button titles can compress, clip, or overlap, especially with longer strings or localization.
- Suggested fix:
  - Use a vertical button stack, widen the sheet, or move the destructive secondary action to a
    separate row/menu.

### 8. Reorder commits sheet relies on drag-only reordering

- File: `Sources/GimMac/Presentation/History/ReorderCommitsSheet.swift`
- Lines: `23, 28-45`
- Evidence:
  - The instructions say `Drag to set the new order`.
  - Reordering is implemented with `.onMove` only.
  - There are no Move Up/Move Down controls or keyboard alternatives.
- User impact:
  - Users who cannot use drag-and-drop cannot complete the reorder workflow.
- Suggested fix:
  - Add keyboard-accessible Move Up/Move Down actions and accessibility labels while keeping drag and
    drop.

### 9. Stash management allows overlapping apply, pop, and drop operations

- Files:
  - `Sources/GimMac/Presentation/ViewModels/StashManagementViewModel.swift`
  - `Sources/GimMac/Presentation/Stash/StashManagementViewController.swift`
- Lines:
  - `StashManagementViewModel.swift:58-80`
  - `StashManagementViewController.swift:244-249, 257-264, 267-279`
- Evidence:
  - `perform(...)` sets `activeAction` but does not guard against an action already being active.
  - The controller enables action buttons based only on selection and starts new tasks immediately.
- User impact:
  - Double-activation can run concurrent stash operations against the same entry, causing failures or
    misleading UI state.
- Suggested fix:
  - Guard `activeAction == nil` in the view model and disable stash action buttons while an operation
    is in progress.

## Medium

### 10. Branch comparison task is not owned or cancelled when the sheet closes

- File: `Sources/GimMac/Presentation/Branches/CompareBranchWindowController.swift`
- Lines: `139-166`
- Evidence:
  - `viewDidAppear()` starts `Task { await runComparison() }`.
  - The task is not stored or cancelled on dismissal.
- User impact:
  - Slow comparisons can keep a dismissed sheet alive longer than necessary and update UI after the
    user has closed it.
- Suggested fix:
  - Store the task, cancel it in `viewWillDisappear` or `deinit`, and check cancellation before UI
    updates.

### 11. Repository Settings observation loop can overwrite in-progress text edits

- File: `Sources/GimMac/Presentation/RepositorySettings/RepositorySettingsWindowController.swift`
- Lines: `124-130, 153-170, 223-226`
- Evidence:
  - `syncUIFromViewModel()` writes field values back into `NSTextField`s on each observation update.
  - `remoteURLChanged(_:)` only pushes edits into the view model on field action/end editing.
- User impact:
  - Unrelated state updates such as loading or LFS refresh can reset a user's partially typed remote
    URL or branch rename text.
- Suggested fix:
  - Avoid overwriting fields while they are being edited.
  - Enable action buttons only when trimmed values are non-empty and meaningfully changed.

### 12. Branch rename sheet can overflow with long current branch names

- File: `Sources/GimMac/Presentation/Branches/RenameBranchWindowController.swift`
- Lines: `38, 45-46, 87-88`
- Evidence:
  - The sheet has a fixed width of `380`.
  - The current branch label embeds the full branch name and lacks a trailing constraint or truncation.
- User impact:
  - Long branch names can render past the sheet bounds or clip, reducing clarity before rename.
- Suggested fix:
  - Add trailing constraints and use truncation or wrapping for the current branch label.

## Minor

### 13. Branch list shows a blank table for empty or no-results states

- File: `Sources/GimMac/Presentation/Branches/BranchesViewController.swift`
- Lines: `54-110, 159-195, 333-335`
- Evidence:
  - The UI has no explicit placeholder for zero filtered or loaded branches.
  - Zero rows simply render an empty table.
- User impact:
  - Users get no explanation when a filter matches nothing or when no branch data is available.
- Suggested fix:
  - Add a distinct empty-state overlay for `No matching branches` and `No branches found`.

## Notes

- Scope was limited to `Sources/GimMac/Presentation`.
- This is a code-review audit only. No build, test, or runtime verification was performed in this pass.
