# changes — Implementation Plan

Based on the GimMac vs GitHub Desktop comparison (2026-05-21).
Organised by phase. Each phase builds on the previous.

---

## Phase 1 — HIGH priority (foundational correctness)

### P1.1 — Undo last commit is non-functional

**Why:** `CommitBox.swift:66` has `Button("Undo") {}` with an empty closure — no domain call is wired, so the UI implies a capability that does nothing.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `undoLastCommit(in:)` to `CommitProviding` |
| `Sources/GimMac/Data/GitServices.swift` | Implement in `GitCommitProvider` via `git reset HEAD~1 --soft` |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `isSyncing: Bool` computed from `primaryAction`; add `undoCommit() async` |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | Wire Undo button action; disable when `isSyncing || isCommitting` |

**New logic:**
```swift
// GitServiceProtocols.swift — extend CommitProviding
protocol CommitProviding: Sendable {
    func commit(in: URL, paths: [String], summary: String, description: String?) async throws
    func undoLastCommit(in repositoryURL: URL) async throws
}

// RepositoryStoreViewModel.swift
var isSyncing: Bool {
    switch primaryAction {
    case .fetch, .pull, .push, .forcePush, .sync: return true
    default: return false
    }
}

func undoCommit() async {
    guard let repo = selectedRepository else { return }
    do {
        try await commitProvider.undoLastCommit(in: repo.url)
        await refreshRepositoryScreenData()
    } catch { errorMessage = error.localizedDescription }
}

// CommitBox.swift
Button("Undo") { Task { await viewModel.undoCommit() } }
    .disabled(viewModel.isSyncing || viewModel.isCommitting)
```

---

### P1.2 — No-changes view is static and context-blind

**Why:** `MainContent.swift` hardcodes four suggestion cards regardless of repository state; `RepositoryStoreViewModel` already holds `primaryAction: RepositoryPrimaryAction` encoding the correct action (push, pull, publish, etc.) but it is never passed to the view.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/Changes/MainContent.swift` | Accept `viewModel: RepositoryStoreViewModel`; derive highlighted suggestion from `primaryAction` |
| `Sources/GimMac/Presentation/Changes/HeaderSection.swift` | Parameterise `title`, `subtitle`, and `icon` instead of hardcoding strings |
| `Sources/GimMac/Presentation/AppShell/RepositoryScreen.swift` | Pass `viewModel` to `MainContent` call-site |

**New logic:**
```swift
// MainContent.swift
struct MainContent: View {
    let viewModel: RepositoryStoreViewModel

    private var remoteAction: (title: String, subtitle: String, button: String)? {
        switch viewModel.primaryAction {
        case .push(let remote, let n):
            return ("Push \(n) commit\(n == 1 ? "" : "s") to \(remote)",
                    "You have \(n) local commit\(n == 1 ? "" : "s") waiting to be pushed.",
                    "Push \(remote)")
        case .pull(let remote, let n):
            return ("Pull \(n) commit\(n == 1 ? "" : "s") from \(remote)",
                    "The remote has changes not yet on your machine.", "Pull \(remote)")
        case .publishRepository:
            return ("Publish this repository", "Only available locally.", "Publish repository")
        case .publishBranch(let remote):
            return ("Publish branch to \(remote)", "This branch has no upstream yet.", "Publish branch")
        default: return nil
        }
    }
    // render remoteAction as the highlighted SuggestionCard, then static Open/Finder cards
}
```

---

### P1.3 — Conflict-file guard missing from commit path

**Why:** `ChangedFile.hasConflict` exists in the Domain but `commitChanges()` never inspects it; committing a file with unresolved conflict markers produces a broken commit.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `hasCheckedConflicts: Bool` computed property; guard it in `commitChanges()` |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | Render inline warning banner when `viewModel.hasCheckedConflicts` |

**New logic:**
```swift
// RepositoryStoreViewModel.swift
var hasCheckedConflicts: Bool {
    changedFiles
        .filter { changedFilesHandler.isChecked($0.path) }
        .contains { $0.hasConflict }
}

func commitChanges() async {
    guard canCommitChanges, !hasCheckedConflicts, let repo = selectedRepository else { return }
    // ...existing logic unchanged
}

// CommitBox.swift — above commit button
if viewModel.hasCheckedConflicts {
    Label("Resolve all conflicts before committing.", systemImage: "exclamationmark.triangle.fill")
        .font(.system(size: 11))
        .foregroundStyle(.orange)
}
```

---

### P1.4 — Discard changes not implemented

**Why:** There is no way to undo working-tree edits; discard with a confirmation guard is a core file-row action in every Git GUI and is required to prevent accidental data loss when the user chooses to abandon work.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `DiscardProviding` protocol |
| `Sources/GimMac/Data/GitServices.swift` | Add `GitDiscardProvider`: `git checkout HEAD -- <path>` for tracked files, `git clean -f -- <path>` for untracked |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `discardChanges(path: String) async` |
| `Sources/GimMac/Presentation/Shared/ChangedFileRow.swift` | Add `onDiscardChanges: () -> Void` callback parameter |
| `Sources/GimMac/Presentation/Changes/Sidebar.swift` | Pass callback from file list rows; own `@State var pendingDiscardPath: String?`; show `.confirmationDialog` |

**New logic:**
```swift
// Domain/GitServiceProtocols.swift
protocol DiscardProviding: Sendable {
    func discardChanges(in repositoryURL: URL, for path: String, status: GitFileStatus) async throws
}

// Data/GitServices.swift
func discardChanges(in repositoryURL: URL, for path: String, status: GitFileStatus) async throws {
    let args: [String] = status == .untracked
        ? ["clean", "-f", "--", path]
        : ["checkout", "HEAD", "--", path]
    let result = try await client.run(args, in: repositoryURL)
    if result.exitCode != 0 { throw GitAppError.commandFailed(result.stderr) }
}

// Sidebar.swift — confirmation guard
.confirmationDialog("Discard changes to \"\(pendingDiscardPath ?? "")\"?",
                    isPresented: $showDiscardConfirm, titleVisibility: .visible) {
    Button("Discard Changes", role: .destructive) {
        guard let path = pendingDiscardPath else { return }
        Task { await viewModel.discardChanges(path: path) }
    }
}
```

---

## Phase 2 — MEDIUM priority

### P2.1 — No "select all / deselect all" toggle

**Why:** The sidebar header row displays a static count label but has no tri-state toggle, forcing per-file toggling when many files are changed; GitHub Desktop places a global checkbox in the list header.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/ViewModels/ChangedFilesHandler.swift` | Add `selectAll(paths:)`, `deselectAll()` |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `selectAllChangedFiles()`, `deselectAllChangedFiles()` forwarding to handler |
| `Sources/GimMac/Presentation/Changes/Sidebar.swift` | Replace static icon in header row with tappable tri-state toggle |

**New logic:**
```swift
// ChangedFilesHandler.swift
func selectAll(paths: [String]) { checkedPaths = Set(paths) }
func deselectAll() { checkedPaths = [] }

// Sidebar.swift — header row leading element
let allChecked = viewModel.checkedChangedFilePaths.count == viewModel.changedFilesCount
Button {
    allChecked
        ? viewModel.deselectAllChangedFiles()
        : viewModel.selectAllChangedFiles()
} label: {
    Image(systemName: allChecked ? "checkmark.square.fill" : "square")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
}
.buttonStyle(.plain)
```

---

### P2.2 — File row context menu missing

**Why:** Users have no right-click action surface on file rows; at minimum Reveal in Finder and Discard Changes are expected in any native Git client, and P1.4 already adds the discard infrastructure.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/Shared/ChangedFileRow.swift` | Add `onDiscardChanges: () -> Void` and `onRevealInFinder: () -> Void` callbacks; attach `.contextMenu` |
| `Sources/GimMac/Presentation/Changes/Sidebar.swift` | Supply both callbacks when constructing `ChangedFileRow` |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `revealInFinder(path: String)` using `NSWorkspace` |

**New logic:**
```swift
// ChangedFileRow.swift
.contextMenu {
    Button("Discard Changes…", action: onDiscardChanges)
    Divider()
    Button("Reveal in Finder", action: onRevealInFinder)
}

// RepositoryStoreViewModel.swift
@MainActor
func revealInFinder(path: String) {
    guard let repo = selectedRepository else { return }
    NSWorkspace.shared.activateFileViewerSelecting([repo.url.appending(path: path)])
}
```

---

### P2.3 — Commit warnings for detached HEAD and unborn branch

**Why:** When `tip` is `.detached` or `.unborn`, a commit is syntactically valid but likely a user error; GimMac silently allows it with no explanation, while GitHub Desktop shows an inline warning above the commit button.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/CommitWarningKind.swift` | New — `enum CommitWarningKind` with `detachedHead` and `unborn` cases |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `commitWarning: CommitWarningKind?` computed from `tip` |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | Render warning banner when `viewModel.commitWarning != nil` |

**New logic:**
```swift
// Domain/CommitWarningKind.swift
enum CommitWarningKind: Equatable {
    case detachedHead
    case unborn
    var message: String {
        switch self {
        case .detachedHead:
            return "You are in a detached HEAD state. This commit will not belong to any branch."
        case .unborn:
            return "This branch has not been created yet. Your first commit will create it."
        }
    }
}

// RepositoryStoreViewModel.swift
var commitWarning: CommitWarningKind? {
    switch tip {
    case .detached: return .detachedHead
    case .unborn:   return .unborn
    default:        return nil
    }
}
```

---

### P2.4 — Stash entry not surfaced

**Why:** GitHub Desktop shows a stash panel at the sidebar bottom when a stash exists and promotes it as the primary suggested action when there are no changes; without this, users have no in-app path to stash or restore work-in-progress.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/StashEntry.swift` | New — `struct StashEntry: Identifiable, Equatable` |
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `StashProviding` protocol |
| `Sources/GimMac/Domain/RepositoryScreenSnapshot.swift` | Add `stashEntry: StashEntry?` |
| `Sources/GimMac/Data/GitServices.swift` | Add `GitStashProvider` — `git stash list --format=...` |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `stashEntry: StashEntry?`, `applyStash() async`, `dropStash() async` |
| `Sources/GimMac/Presentation/Changes/Sidebar.swift` | Render stash panel at the bottom when `viewModel.stashEntry != nil` |
| `Sources/GimMac/Presentation/Changes/MainContent.swift` | When stash exists and no changes, render "View stashed changes" as highlighted suggestion |

**New logic:**
```swift
// Domain/StashEntry.swift
struct StashEntry: Identifiable, Equatable {
    let id: String          // e.g. "stash@{0}"
    let message: String
    let branchName: String
}

// Domain/GitServiceProtocols.swift
protocol StashProviding: Sendable {
    func fetchStash(in repositoryURL: URL) async throws -> StashEntry?
    func applyStash(in repositoryURL: URL) async throws
    func dropStash(in repositoryURL: URL) async throws
}
```

---

## Phase 3 — LOW priority

### P3.1 — Commit summary length counter and warning

**Why:** Commit summaries beyond 72 characters are truncated in most Git log viewers; GitHub Desktop shows a live character count and turns it red at that threshold.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/ViewModels/CommitFormHandler.swift` | Add `summaryCharacterCount: Int`, `summaryExceedsRecommendedLength: Bool` |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | Overlay character count on summary field; tint red when limit exceeded |

**New logic:**
```swift
// CommitFormHandler.swift
var summaryCharacterCount: Int { commitSummary.count }
var summaryExceedsRecommendedLength: Bool { summaryCharacterCount > 72 }

// CommitBox.swift — trailing overlay on the summary TextField
.overlay(alignment: .trailing) {
    Text("\(viewModel.summaryCharacterCount)")
        .font(.system(size: 10))
        .foregroundStyle(viewModel.summaryExceedsRecommendedLength ? .red : .tertiary)
        .padding(.trailing, 6)
}
```

---

### P3.2 — Amend last commit mode

**Why:** Amending the previous commit is a common workflow for fixing a summary typo or adding missed files; it requires a toggle that repopulates the commit form and passes `--amend` to git.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `isAmend: Bool` parameter to `CommitProviding.commit` |
| `Sources/GimMac/Data/GitServices.swift` | Append `--amend` flag when `isAmend == true` |
| `Sources/GimMac/Presentation/ViewModels/CommitFormHandler.swift` | Add `isAmendMode: Bool`, `toggleAmend()` |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `toggleAmendMode()`; prefill form from `commits.first` on entry |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | Add amend toggle button beside the commit button |

**New logic:**
```swift
// CommitFormHandler.swift
private(set) var isAmendMode = false
func toggleAmend() { isAmendMode.toggle() }

// RepositoryStoreViewModel.swift
func toggleAmendMode() {
    commitForm.toggleAmend()
    if commitForm.isAmendMode, let last = commits.first {
        commitForm.prefill(summary: last.summary, body: last.body)
    }
}
```

---

### P3.3 — Commit options: skip hooks and sign-off

**Why:** Some teams use commit hooks for linting/testing that must be bypassed for WIP commits (`--no-verify`); several open-source projects require a `Signed-off-by` trailer (`--signoff`).

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `CommitOptions` struct; update `CommitProviding.commit` signature |
| `Sources/GimMac/Data/GitServices.swift` | Append `--no-verify` / `--signoff` from `CommitOptions` |
| `Sources/GimMac/Presentation/ViewModels/CommitFormHandler.swift` | Add `skipHooks: Bool`, `signOff: Bool` |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | Add options menu (⋯ button) with toggles |

**New logic:**
```swift
// Domain/GitServiceProtocols.swift
struct CommitOptions {
    var skipHooks: Bool = false
    var signOff: Bool = false
    var isAmend: Bool = false
}

protocol CommitProviding: Sendable {
    func commit(in: URL, paths: [String], summary: String,
                description: String?, options: CommitOptions) async throws
    func undoLastCommit(in: URL) async throws
}
```

---

## Files Changed (full list across all phases)

| File | Phases | Type |
|---|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | P1.1, P1.4, P2.4, P3.2, P3.3 | Modify |
| `Sources/GimMac/Domain/CommitWarningKind.swift` | P2.3 | New |
| `Sources/GimMac/Domain/StashEntry.swift` | P2.4 | New |
| `Sources/GimMac/Domain/RepositoryScreenSnapshot.swift` | P2.4 | Modify |
| `Sources/GimMac/Data/GitServices.swift` | P1.1, P1.4, P2.4, P3.2, P3.3 | Modify |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | P1.1, P1.3, P1.4, P2.1, P2.2, P2.3, P2.4, P3.2 | Modify |
| `Sources/GimMac/Presentation/ViewModels/ChangedFilesHandler.swift` | P2.1 | Modify |
| `Sources/GimMac/Presentation/ViewModels/CommitFormHandler.swift` | P3.1, P3.2, P3.3 | Modify |
| `Sources/GimMac/Presentation/Changes/CommitBox.swift` | P1.1, P1.3, P2.3, P3.1, P3.2, P3.3 | Modify |
| `Sources/GimMac/Presentation/Changes/MainContent.swift` | P1.2, P2.4 | Modify |
| `Sources/GimMac/Presentation/Changes/HeaderSection.swift` | P1.2 | Modify |
| `Sources/GimMac/Presentation/Changes/Sidebar.swift` | P1.4, P2.1, P2.2, P2.4 | Modify |
| `Sources/GimMac/Presentation/Shared/ChangedFileRow.swift` | P1.4, P2.2 | Modify |
| `Sources/GimMac/Presentation/AppShell/RepositoryScreen.swift` | P1.2 | Modify |

---

## Implementation Order

```
P1.1 → P1.2 → P1.3 → P1.4 → P2.1 → P2.2 → P2.3 → P2.4 → P3.1 → P3.2 → P3.3
```

P1.4 (discard infrastructure) must land before P2.2 (context menu), which reuses the
discard callback. P2.1 (select-all) must land before P2.2 (context menu on rows) since
both touch `ChangedFilesHandler`.

---

## Verification Steps (per phase)

| Phase | Test |
|---|---|
| P1.1 | Make a commit; press Undo; `git log --oneline` should show the previous HEAD; button must be disabled while `primaryAction` is `.fetch`/`.push`/`.pull` |
| P1.2 | On a repo 1 commit ahead: highlighted card reads "Push 1 commit to origin". On a repo with no remote: card reads "Publish this repository". |
| P1.3 | Create a file with `<<<<<<< HEAD` conflict markers; stage it; commit button must be disabled and the orange warning label must be visible. |
| P1.4 | Edit a tracked file; right-click → Discard Changes; cancel → file still modified. Confirm → `git status` shows clean. Repeat for an untracked file. |
| P2.1 | With 4 changed files unchecked: click the header toggle → all 4 rows fill their checkbox. Click again → all unchecked. |
| P2.2 | Right-click any file row → "Reveal in Finder" opens Finder with the file selected at its full path. |
| P2.3 | Run `git checkout --detach HEAD` then open the Changes tab; warning banner text must be visible above the commit button. |
| P2.4 | Run `git stash`; reopen app; stash panel visible at sidebar bottom. No-changes view shows "View stashed changes" as the primary action. |
| P3.1 | Type 73 characters in the summary field; the character counter must turn red. |
| P3.2 | Toggle Amend; form fills with last commit message; commit; `git log --oneline` still shows the same number of commits. |
| P3.3 | Enable Sign-off; commit; `git log -1 --format=%b` output contains `Signed-off-by: Name <email>`. |
