# history — Implementation Plan

Based on the GimMac vs GitHub Desktop comparison (2026-05-21).
Organised by phase. Each phase builds on the previous.

---

## Phase 1 — HIGH priority (foundational correctness)

### P1.1 — `Commit.date` is missing; sidebar fails to compile

**Why:** `CommitHistorySidebar.swift:36` calls `commit.date` in the subtitle string but `Commit` has no `date` property — the 15-line struct ends after `body` and `authorDisplayName`.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/Commit.swift` | Add `let date: Date` stored property |
| `Sources/GimMac/Data/GitHistoryParser.swift` | Parse `%ai` (ISO-8601 author date) from log format string and assign to `date` |

**New logic:**
```swift
// Domain/Commit.swift
struct Commit: Identifiable, Equatable, Sendable {
    let id: String
    let shortHash: String
    let authorName: String
    let authorEmail: String
    let date: Date          // NEW
    let summary: String
    let body: String?

    var authorDisplayName: String { authorName }
}
```

---

### P1.2 — History file list shows working-tree changes, not commit files

**Why:** `ChangedFilesColumn` binds to `viewModel.changedFiles`, which is populated from `RepositoryScreenSnapshot.changedFiles` (working-tree status). When the History tab is active, the column must show files touched by the selected commit, not unstaged edits.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `CommitInspecting` protocol |
| `Sources/GimMac/Domain/CommitFile.swift` | New — `CommitFile` value type |
| `Sources/GimMac/Data/GitServices.swift` | Implement `GitCommitInspector` using `git diff-tree --no-commit-id -r --name-status <sha>` |
| `Sources/GimMac/Presentation/ViewModels/HistoryHandler.swift` | Add `commitFiles: [CommitFile]`, `isLoadingCommitFiles: Bool`; add `loadFiles(for:in:)` async |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Inject `CommitInspecting`; expose `historyFiles: [CommitFile]`; call `historyHandler.loadFiles` on commit selection |
| `Sources/GimMac/Presentation/History/HistoryRepositoryScreen.swift` | Pass history-specific data to file column; replace `ChangedFilesColumn` with `HistoryFilesColumn` |
| `Sources/GimMac/Presentation/History/HistoryFilesColumn.swift` | New — read-only file list bound to `historyFiles` |

**New logic:**
```swift
// Domain/CommitFile.swift
struct CommitFile: Identifiable, Equatable, Sendable {
    var id: String { path }
    let path: String
    let status: GitFileStatus
}

// Domain/GitServiceProtocols.swift
protocol CommitInspecting: Sendable {
    func fetchFiles(for commitSHA: String, in repositoryURL: URL) async throws -> [CommitFile]
}

// Presentation/ViewModels/HistoryHandler.swift
@MainActor @Observable
final class HistoryHandler {
    private(set) var selectedIndex = 0
    private(set) var commitFiles: [CommitFile] = []
    private(set) var isLoadingCommitFiles = false
    private(set) var selectedCommitFilePath: String?

    func selectCommit(at index: Int) { selectedIndex = index }

    func loadFiles(for commitSHA: String, using inspector: CommitInspecting, in url: URL) async {
        isLoadingCommitFiles = true
        defer { isLoadingCommitFiles = false }
        commitFiles = (try? await inspector.fetchFiles(for: commitSHA, in: url)) ?? []
        selectedCommitFilePath = commitFiles.first?.path
    }

    func selectedCommit(in commits: [Commit]) -> Commit? {
        guard !commits.isEmpty else { return nil }
        return commits[min(max(selectedIndex, 0), commits.count - 1)]
    }
}

// RepositoryStoreViewModel — add to selectHistoryCommit:
func selectHistoryCommit(at index: Int) {
    historyHandler.selectCommit(at: index)
    guard let repo = selectedRepository,
          let sha = selectedCommit?.id else { return }
    Task { await historyHandler.loadFiles(for: sha, using: commitInspector, in: repo.url) }
}

var historyFiles: [CommitFile] { historyHandler.commitFiles }
```

---

### P1.3 — History diff loads working-tree diff instead of commit diff

**Why:** `DiffHandler.loadDiff(in:changedFiles:)` calls `diffProvider.fetchDiff(in:for:)` which runs `git diff HEAD -- <file>` (working tree). Selecting a file in the History panel must show `git show <sha>:<file>` diff, not the unstaged diff.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `fetchCommitDiff(in:for:commitSHA:)` to `DiffProviding` |
| `Sources/GimMac/Data/GitServices.swift` | Implement via `git diff <sha>^..<sha> -- <path>` |
| `Sources/GimMac/Presentation/ViewModels/HistoryHandler.swift` | Add `diffDocument: DiffDocument`, `isLoadingDiff: Bool`; add `loadDiff(for:commitSHA:using:in:)` async |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Expose `historyDiffDocument`, `isLoadingHistoryDiff`; add `selectHistoryFile(path:)` |
| `Sources/GimMac/Presentation/History/HistoryRepositoryScreen.swift` | Wire `DiffViewer` to history-specific diff state |

**New logic:**
```swift
// Domain/GitServiceProtocols.swift — extend DiffProviding
protocol DiffProviding: Sendable {
    func fetchDiff(in repositoryURL: URL, for path: String) async throws -> DiffDocument
    func fetchCommitDiff(in repositoryURL: URL, for path: String, commitSHA: String) async throws -> DiffDocument
}

// Presentation/ViewModels/HistoryHandler.swift — extend
func loadDiff(for path: String, commitSHA: String, using provider: DiffProviding, in url: URL) async {
    selectedCommitFilePath = path
    isLoadingDiff = true
    defer { isLoadingDiff = false }
    diffDocument = (try? await provider.fetchCommitDiff(in: url, for: path, commitSHA: commitSHA)) ?? .empty
}

// RepositoryStoreViewModel
var historyDiffDocument: DiffDocument { historyHandler.diffDocument }
var isLoadingHistoryDiff: Bool { historyHandler.isLoadingDiff }

func selectHistoryFile(path: String) {
    guard let repo = selectedRepository,
          let sha = selectedCommit?.id else { return }
    Task { await historyHandler.loadDiff(for: path, commitSHA: sha, using: diffProvider, in: repo.url) }
}
```

---

### P1.4 — `HistoryFilesColumn` must be read-only (no staging checkboxes)

**Why:** `ChangedFilesColumn` renders `ChangedFileRow` with a checkbox toggle — a staging operation that is meaningless and misleading in the History context. The new `HistoryFilesColumn` must omit all staging controls.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/History/HistoryFilesColumn.swift` | New — list of `CommitFile` rows; no checkbox; tap calls `viewModel.selectHistoryFile(path:)` |
| `Sources/GimMac/Presentation/Shared/ChangedFileRow.swift` | No change needed; `HistoryFilesColumn` renders its own simpler row |

**New logic:**
```swift
// Presentation/History/HistoryFilesColumn.swift
struct HistoryFilesColumn: View {
    let viewModel: RepositoryStoreViewModel

    var body: some View {
        VStack(spacing: 0) {
            CommitDetailsHeader(viewModel: viewModel)
            sectionHeader
            fileList
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var fileList: some View {
        List(viewModel.historyFiles) { file in
            HistoryFileRow(file: file,
                           isSelected: file.path == viewModel.historyHandler.selectedCommitFilePath)
                .onTapGesture { viewModel.selectHistoryFile(path: file.path) }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
```

---

## Phase 2 — MEDIUM priority

### P2.1 — Commit body not displayed in details header

**Why:** `CommitDetailsHeader` renders only `commit.summary`. GitHub Desktop's `ExpandableCommitSummary` shows the full body and lets it expand to take over the diff pane. GimMac needs at minimum a non-expanding body text block.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/History/CommitDetailsHeader.swift` | Add scrollable `Text(commit.body)` below the author row; hide when `body == nil` |

**New logic:**
```swift
// CommitDetailsHeader — inside VStack after author HStack
if let body = viewModel.selectedCommit?.body, !body.isEmpty {
    Text(body)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
}
```

---

### P2.2 — Unpushed indicator shows for all commits regardless of push status

**Why:** `CommitRow.swift:~35` always renders the arrow.up indicator. `Commit` has no `isLocalCommit` field so there is no way to gate the indicator on actual push status.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/Commit.swift` | Add `let isLocalCommit: Bool` |
| `Sources/GimMac/Data/GitHistoryParser.swift` | Determine `isLocalCommit` by comparing SHA against `git log @{u}..HEAD --format=%H` (unpushed SHAs); default `false` when no upstream |
| `Sources/GimMac/Presentation/History/CommitRow.swift` | Gate the arrow.up badge on `commit.isLocalCommit` |

**New logic:**
```swift
// Domain/Commit.swift
struct Commit: Identifiable, Equatable, Sendable {
    // ... existing fields ...
    let isLocalCommit: Bool   // true = not yet pushed to upstream
}

// CommitRow.swift — replace unconditional badge
if commit.isLocalCommit {
    Image(systemName: "arrow.up")
        .font(.system(size: 11, weight: .bold))
        .padding(5)
        .background(.white.opacity(0.18))
        .clipShape(Circle())
}
```

---

### P2.3 — No empty-list state for history

**Why:** When `viewModel.commits` is empty (new repo or unborn branch), `CommitHistorySidebar` renders a blank `List` with no message. GitHub Desktop shows "No history".

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/History/CommitHistorySidebar.swift` | Add `ContentUnavailableView` / overlay when `viewModel.commits.isEmpty` |

**New logic:**
```swift
// CommitHistorySidebar — replace bare List with:
if viewModel.commits.isEmpty {
    ContentUnavailableView("No history", systemImage: "clock.arrow.circlepath",
        description: Text("No commits yet on this branch."))
} else {
    List(viewModel.commits.indices, id: \.self) { index in
        // existing row …
    }
}
```

---

### P2.4 — No context menu on commit rows

**Why:** GitHub Desktop exposes copy SHA, revert commit, create branch from commit, and undo last commit via right-click. GimMac has no context menu on `CommitRow`.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/History/CommitRow.swift` | Add `.contextMenu` modifier |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Expose `copyCommitSHA(at:)`, `revertCommit(at:)` (revert is P2; can stub with `// TODO`) |

**New logic:**
```swift
// CommitRow.swift — add to row view
.contextMenu {
    Button("Copy SHA") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(commit.id, forType: .string)
    }
    if isFirst {  // passed as param
        Button("Undo Commit") { onUndoCommit?() }
    }
    Divider()
    Button("Revert Commit…") { onRevertCommit?() }
}
```

---

### P2.5 — No context menu on history file rows

**Why:** GitHub Desktop allows "Copy file path", "Reveal in Finder", and "Open in external editor" from the history file list. GimMac has `revealInFinder` already on the ViewModel but it is not surfaced in history.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/History/HistoryFilesColumn.swift` | Add `.contextMenu` to each file row using `viewModel.revealInFinder(path:)` |

**New logic:**
```swift
HistoryFileRow(...)
    .contextMenu {
        Button("Reveal in Finder") { viewModel.revealInFinder(path: file.path) }
        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.path, forType: .string)
        }
    }
```

---

## Phase 3 — LOW priority

### P3.1 — `Commit` has no `tags` field; tag badges absent from commit rows

**Why:** GitHub Desktop renders tag badges (`octicons.tag`) beside commits that have associated Git tags. `Commit` has no `tags: [String]` field and `CommitRow` shows no tag badges.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/Commit.swift` | Add `let tags: [String]` (default `[]`) |
| `Sources/GimMac/Data/GitHistoryParser.swift` | Populate via `git tag --points-at <sha>` per commit, or add `%(refname:short)` to `for-each-ref` pass |
| `Sources/GimMac/Presentation/History/CommitRow.swift` | Render tag chips when `!commit.tags.isEmpty` |

**New logic:**
```swift
// CommitRow — add after unpushed indicator
ForEach(commit.tags, id: \.self) { tag in
    Label(tag, systemImage: "tag.fill")
        .font(.system(size: 9, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.quaternary)
        .clipShape(Capsule())
}
```

---

### P3.2 — No diff options (side-by-side, hide whitespace) in history diff

**Why:** GitHub Desktop's `DiffHeader` shows side-by-side toggle and hide-whitespace toggle in history mode. GimMac's `DiffViewer` has no such controls.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/Diff/DiffHeader.swift` | Add side-by-side and hide-whitespace toggle buttons |
| `Sources/GimMac/Presentation/ViewModels/DiffHandler.swift` | Add `showSideBySide: Bool`, `hideWhitespace: Bool` state; re-load diff on change |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Expose `toggleSideBySideDiff()`, `toggleHideWhitespace()` forwarded to `diffHandler` |

---

### P3.3 — Multi-commit selection not supported

**Why:** GitHub Desktop supports Shift+click / Cmd+click to select multiple commits for cherry-pick and squash operations. `HistoryHandler` tracks only a single `selectedIndex: Int`.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Presentation/ViewModels/HistoryHandler.swift` | Replace `selectedIndex: Int` with `selectedIndices: Set<Int>` |
| `Sources/GimMac/Presentation/History/CommitHistorySidebar.swift` | Wire Shift+click / Cmd+click gestures |
| `Sources/GimMac/Presentation/History/CommitRow.swift` | Accept `isSelected: Bool` derived from set membership |

---

### P3.4 — No branch comparison mode

**Why:** GitHub Desktop's Compare sidebar lets users pick a branch to compare ahead/behind commits. GimMac has no compare UI.

**File changes:**

| File | Change |
|---|---|
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | Add `CompareProviding` with `compareAheadBehind(base:head:in:)` |
| `Sources/GimMac/Data/GitServices.swift` | Implement via `git log <base>..<head>` and `git log <head>..<base>` |
| `Sources/GimMac/Presentation/History/CommitHistorySidebar.swift` | Add branch-picker text field above commit list |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | Add `compareWithBranch(_:)`, `comparisonCommits: [Commit]` |

---

## Files Changed (full list across all phases)

| File | Phases | Type |
|---|---|---|
| `Sources/GimMac/Domain/Commit.swift` | P1.1, P2.2, P3.1 | Modify |
| `Sources/GimMac/Domain/CommitFile.swift` | P1.2 | New |
| `Sources/GimMac/Domain/GitServiceProtocols.swift` | P1.2, P1.3, P3.4 | Modify |
| `Sources/GimMac/Data/GitHistoryParser.swift` | P1.1, P2.2, P3.1 | Modify |
| `Sources/GimMac/Data/GitServices.swift` | P1.2, P1.3, P3.4 | Modify |
| `Sources/GimMac/Presentation/ViewModels/HistoryHandler.swift` | P1.2, P1.3, P3.3 | Modify |
| `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` | P1.2, P1.3, P2.4, P3.2, P3.3, P3.4 | Modify |
| `Sources/GimMac/Presentation/ViewModels/DiffHandler.swift` | P3.2 | Modify |
| `Sources/GimMac/Presentation/History/HistoryRepositoryScreen.swift` | P1.2, P1.3 | Modify |
| `Sources/GimMac/Presentation/History/HistoryFilesColumn.swift` | P1.2, P1.4, P2.5 | New |
| `Sources/GimMac/Presentation/History/CommitHistorySidebar.swift` | P2.3, P3.3, P3.4 | Modify |
| `Sources/GimMac/Presentation/History/CommitRow.swift` | P2.2, P2.4, P3.1 | Modify |
| `Sources/GimMac/Presentation/History/CommitDetailsHeader.swift` | P2.1 | Modify |
| `Sources/GimMac/Presentation/Diff/DiffHeader.swift` | P3.2 | Modify |

---

## Implementation Order

```
P1.1 → P1.2 → P1.3 → P1.4 → P2.1 → P2.2 → P2.3 → P2.4 → P2.5 → P3.1 → P3.2 → P3.3 → P3.4
```

P1.1 must land first — without `Commit.date` the sidebar does not compile. P1.2 and P1.3 share the new `CommitInspecting` protocol so implement together. P1.4 depends on `HistoryFilesColumn` introduced in P1.2.

---

## Verification Steps (per phase)

| Phase | Test |
|---|---|
| P1.1 | Project builds; commit rows show relative timestamps (e.g. "2 days ago") |
| P1.2 | Select a history commit → middle column lists only that commit's changed files, not unstaged edits |
| P1.3 | Click a file in history → diff panel shows `git show` output, not `git diff HEAD` output |
| P1.4 | Middle column in history has no checkboxes; toggling files in Changes tab does not affect history selection |
| P2.1 | Commit with multi-line body shows body text below author line |
| P2.2 | Pushed commits show no arrow badge; commits ahead of remote show the arrow |
| P2.3 | New repo with zero commits shows "No history" in commit list |
| P2.4 | Right-clicking a commit row shows context menu; "Copy SHA" writes to clipboard |
| P2.5 | Right-clicking a file row in history shows "Reveal in Finder" and "Copy Path" |
| P3.1 | Tagged commits show tag chip in commit row |
| P3.2 | Diff header toggles side-by-side and re-renders diff |
| P3.3 | Shift-click selects a range; Cmd-click toggles individual commits |
| P3.4 | Branch picker filters commit list to ahead/behind commits |
