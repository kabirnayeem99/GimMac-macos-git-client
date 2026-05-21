# Branches Feature — Implementation Plan

**Status:** Planning  
**Reference:** GitHub Desktop `app/src/ui/branches/`, `app/src/lib/git/branch.ts`, `app/src/models/branch.ts`  
**Architecture:** Clean Architecture (Presentation → Domain → Data). No shortcuts.

---

## Gap Summary

GimMac currently only reads current branch state (`TipState`, upstream tracking, ahead/behind vs upstream).  
All interactive branch operations and the full branches panel are missing.

| Feature | Status |
|---|---|
| Display current branch | ✅ Implemented |
| List all branches | ❌ Missing |
| Create branch | ❌ Missing |
| Switch branch | ❌ Missing |
| Delete local branch | ❌ Missing |
| Delete remote branch | ❌ Missing |
| Rename branch | ❌ Missing |
| Compare two branches | ❌ Missing (only vs upstream exists) |
| Update from default branch (merge/rebase) | ❌ Missing |
| Auto-stash on switch | ❌ Missing |

---

## Phase 1 — Domain Models

> Files: `Sources/GimMac/Domain/`  
> No AppKit, no process execution, no storage.

### 1.1 Rename / Extend `BranchSummary` → `Branch`

**Current (`Tip.swift`):**
```swift
struct BranchSummary {
    let name: String
    let upstream: String?
    let sha: String
}
```

**New (`Branch.swift` — new file):**
```swift
enum BranchType: Equatable {
    case local
    case remote(remoteName: String)
}

struct Branch: Identifiable, Equatable {
    var id: String { ref }

    let name: String            // short name, e.g. "main", "feature/foo"
    let ref: String             // full ref, e.g. "refs/heads/main"
    let tip: BranchTip
    let type: BranchType
    let upstream: String?       // e.g. "origin/main" — nil if no tracking branch

    // Computed
    var isLocal: Bool { type == .local }
    var remoteName: String? {
        guard case .remote(let r) = type else { return nil }
        return r
    }
    var nameWithoutRemote: String {
        guard let r = remoteName else { return name }
        return String(name.dropFirst(r.count + 1))
    }
}

struct BranchTip: Equatable {
    let sha: String
    let shortSHA: String
    let authorName: String
    let summary: String         // commit subject line
    let date: Date
}
```

**Migration:** `BranchSummary` stays in `Tip.swift` for `TipState.valid` — it only needs `name`, `upstream`, `sha`. Full `Branch` is used for the branch list. No rename of `TipState` or `BranchSummary` — they serve a different purpose (toolbar display).

### 1.2 New: `BranchStartPoint`

```swift
// Sources/GimMac/Domain/BranchStartPoint.swift
enum BranchStartPoint: Equatable {
    case currentBranch
    case defaultBranch          // origin/HEAD or configured default
    case head
    case branch(Branch)
    case commit(sha: String)
}
```

GitHub Desktop equivalent: `StartPoint` enum.

### 1.3 New: `AheadBehind` + `BranchCompareResult`

```swift
// Sources/GimMac/Domain/BranchCompareResult.swift
struct AheadBehind: Equatable {
    let ahead: Int
    let behind: Int
}

struct BranchCompareResult: Equatable {
    let base: Branch
    let compare: Branch
    let aheadBehind: AheadBehind
    let commits: [CommitSummary]    // commits in compare not in base
}
```

GitHub Desktop equivalents: `IAheadBehind`, `ICompareResult`.

### 1.4 New: `BranchesTab`

```swift
// Sources/GimMac/Domain/BranchesTab.swift
enum BranchesTab: Int, CaseIterable {
    case localBranches = 0
    case remoteBranches = 1
}
```

GitHub Desktop equivalent: `BranchesTab` (had `PullRequests` as tab 1 — omit for MVP, remote branches instead).

---

## Phase 2 — Service Protocols

> File: `Sources/GimMac/Domain/GitServiceProtocols.swift` — add new protocols.

### 2.1 `BranchProviding`

Reads branch list. Read-only. Replaces nothing — `BranchUpstreamProviding` stays for toolbar upstream reads.

```swift
protocol BranchProviding {
    /// Fetch all local and remote branches.
    func fetchBranches(in repositoryURL: URL) async throws -> [Branch]

    /// Fetch branches that point at a given commitish.
    func fetchBranchesPointing(at commitish: String, in repositoryURL: URL) async throws -> [Branch]

    /// Fetch local branches fully merged into the given branch.
    func fetchMergedBranches(into branch: Branch, in repositoryURL: URL) async throws -> [Branch]
}
```

GitHub Desktop equivalents: `getBranches`, `getBranchesPointedAt`, `getMergedBranches`.

### 2.2 `BranchOperating`

Mutating operations. Separate protocol so read-only VMs don't get write access.

```swift
protocol BranchOperating {
    /// Create a new branch from startPoint. Does not switch to it.
    func createBranch(named name: String, from startPoint: BranchStartPoint, noTrack: Bool, in repositoryURL: URL) async throws -> Branch

    /// Switch working tree to the given branch.
    func switchBranch(to branch: Branch, in repositoryURL: URL) async throws

    /// Delete a local branch. Force = true skips merge check.
    func deleteLocalBranch(_ branch: Branch, force: Bool, in repositoryURL: URL) async throws

    /// Delete a remote tracking branch via `git push remote :branchName`.
    func deleteRemoteBranch(_ branch: Branch, remote: String, in repositoryURL: URL) async throws

    /// Rename a branch. Force = true allows rename even if name exists.
    func renameBranch(_ branch: Branch, to newName: String, force: Bool, in repositoryURL: URL) async throws -> Branch
}
```

GitHub Desktop equivalents: `createBranch`, `getBranchCheckoutArgs` (checkout), `deleteLocalBranch`, `deleteRemoteBranch`, `renameBranch`.

### 2.3 `BranchCompareProviding`

```swift
protocol BranchCompareProviding {
    /// Compare two branches — returns commits in `compare` not in `base` + ahead/behind counts.
    func compareBranches(base: Branch, compare: Branch, in repositoryURL: URL) async throws -> BranchCompareResult
}
```

GitHub Desktop equivalent: `ICompareResult` via `git log` + `git rev-list`.

### 2.4 `UpdateFromDefaultProviding`

```swift
protocol UpdateFromDefaultProviding {
    /// Merge the default branch into the current branch.
    func mergeDefaultBranch(into branch: Branch, in repositoryURL: URL) async throws

    /// Rebase the current branch onto the default branch.
    func rebaseOntoDefaultBranch(_ branch: Branch, in repositoryURL: URL) async throws
}
```

GitHub Desktop equivalent: `MergeChooseBranchDialog` + `RebaseChooseBranchDialog` flows.

---

## Phase 3 — Data Implementations

> Files: `Sources/GimMac/Data/`

### 3.1 `GitBranchReader` — implements `BranchProviding`

**Git commands:**

| Method | Git command |
|---|---|
| `fetchBranches` | `git for-each-ref --format=<fields> refs/heads refs/remotes` |
| `fetchBranchesPointing(at:)` | `git branch --points-at=[sha] --format=%(refname:short)` |
| `fetchMergedBranches(into:)` | `git branch --merged [branchName] --format=%(refname:short)` |

**`for-each-ref` format string** (same fields GitHub Desktop uses):
```
%(refname)%00%(refname:short)%00%(objectname)%00%(objectname:short)%00%(upstream:short)%00%(author:name)%00%(subject)%00%(creatordate:iso-strict)
```

Parser: `BranchForEachRefParser` — splits on `%00`, maps to `Branch`. Lives in `Sources/GimMac/Data/Parsers/BranchForEachRefParser.swift`.

### 3.2 `GitBranchOperator` — implements `BranchOperating`

**Git commands:**

| Method | Git command | Notes |
|---|---|---|
| `createBranch(named:from:noTrack:)` | `git branch [name] [startPoint] [--no-track]` | Do NOT auto-switch |
| `switchBranch(to:)` | `git switch [name]` | Prefer `git switch` over `git checkout` |
| `deleteLocalBranch(_:force:)` | `git branch -d [name]` or `-D` if force | Use `-D` only when user confirms |
| `deleteRemoteBranch(_:remote:)` | `git push [remote] :[branchName]` | Push empty ref |
| `renameBranch(_:to:force:)` | `git branch -m [old] [new]` or `-M` if force | `-M` only when user confirms override |

**Security note (from AGENTS.md):** always pass args as array, never shell string.

### 3.3 `GitBranchCompareReader` — implements `BranchCompareProviding`

```
git log [base]..[compare] --format=%H%x00%an%x00%s%x00%aI --no-merges
git rev-list --left-right --count [base]...[compare]
```

### 3.4 `GitUpdateFromDefaultOperator` — implements `UpdateFromDefaultProviding`

```
git merge [defaultBranch] --no-edit
git rebase [defaultBranch]
```

---

## Phase 4 — Stash Guard (Pre-Switch)

Before switching branches, check for dirty working tree.  
GitHub Desktop: `StashAndSwitchBranchDialog`.

### 4.1 `DirtyWorkingTreeAction` enum

```swift
enum DirtyWorkingTreeAction {
    case stashChanges
    case discardChanges
    case cancel
}
```

### 4.2 Flow in `BranchesViewModel`

```
switchBranch(to:) called
  → check StatusProviding.fetchStatus() for dirty files
  → if clean: call BranchOperating.switchBranch(to:) directly
  → if dirty: emit stashGuardNeeded(files:) event
      → UI shows StashAndSwitchSheetController
      → user picks .stashChanges / .discardChanges / .cancel
      → proceed accordingly
```

---

## Phase 5 — ViewModels

> `Sources/GimMac/Presentation/ViewModels/`

### 5.1 `BranchesViewModel`

```swift
@Observable
final class BranchesViewModel {
    // State
    var localBranches: [Branch] = []
    var remoteBranches: [Branch] = []
    var selectedTab: BranchesTab = .localBranches
    var searchQuery: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    // Filtered (computed)
    var filteredBranches: [Branch] { ... }

    // Injected
    private let branchProvider: BranchProviding
    private let branchOperator: BranchOperating
    private let statusProvider: StatusProviding

    // Actions
    @MainActor func loadBranches(in repositoryURL: URL) async { ... }
    @MainActor func createBranch(named: String, from: BranchStartPoint) async { ... }
    @MainActor func switchBranch(to: Branch) async { ... }
    @MainActor func deleteLocalBranch(_ branch: Branch) async { ... }
    @MainActor func deleteRemoteBranch(_ branch: Branch, remote: String) async { ... }
    @MainActor func renameBranch(_ branch: Branch, to newName: String) async { ... }
}
```

### 5.2 `BranchCompareViewModel`

```swift
@Observable
final class BranchCompareViewModel {
    var baseB: Branch?
    var compareB: Branch?
    var result: BranchCompareResult?
    var isLoading: Bool = false

    private let compareProvider: BranchCompareProviding

    @MainActor func compare() async { ... }
}
```

---

## Phase 6 — UI (AppKit)

> `Sources/GimMac/Presentation/Branches/`

### 6.1 `BranchesViewController`

NSViewController. Contains:
- `NSSegmentedControl` for `BranchesTab` (Local / Remote)
- `NSSearchField` bound to `BranchesViewModel.searchQuery`
- `BranchTableView` (NSTableView, single column, `BranchCellView` rows)
- "New Branch" `NSButton` at bottom

GitHub Desktop equivalent: `BranchesContainer`.

### 6.2 `BranchCellView`

NSTableCellView subclass:
- Branch name label (bold if current)
- Current branch indicator (•)
- Ahead/behind badges (only if tracking upstream)
- Context menu: Switch, Rename, Delete, Copy Name

GitHub Desktop equivalent: `BranchListItem`.

### 6.3 `CreateBranchWindowController`

NSWindowController + NSViewController sheet:
- Branch name `NSTextField` with live validation
- Start point picker `NSPopUpButton` (Current Branch / Default Branch / Specific SHA)
- "Create Branch" + "Cancel" buttons

On confirm: calls `BranchesViewModel.createBranch(named:from:)`.

GitHub Desktop equivalent: `CreateBranchDialog`.

### 6.4 `DeleteBranchWindowController`

Confirmation sheet:
- Shows branch name
- Checkbox: "Also delete remote tracking branch" (only if upstream exists)
- Destructive "Delete" + "Cancel"

GitHub Desktop equivalent: `DeleteBranchDialog` + `DeleteRemoteBranchDialog` (merged into one sheet).

### 6.5 `RenameBranchWindowController`

NSWindowController sheet:
- Current name (read-only label)
- New name `NSTextField` with live validation
- Warning label if branch has upstream ("Remote branch will not be renamed")
- "Rename" + "Cancel"

GitHub Desktop equivalent: `RenameBranchDialog`.

### 6.6 `StashAndSwitchSheetController`

Sheet triggered before switch when dirty working tree:
- Lists changed files count
- "Stash Changes" / "Discard Changes" / "Cancel" buttons

GitHub Desktop equivalent: `StashAndSwitchBranchDialog`.

### 6.7 Toolbar Wire-up

`TopToolbar` branch card becomes clickable:
- Click opens `BranchesViewController` as popover or side panel
- Matches GitHub Desktop `BranchDropdown` behavior

---

## Phase 7 — Compare Branches (Post-MVP)

Separate screen. Two branch pickers + commit list + diff view.  
Scope: V1, not MVP.

---

## Phase 8 — Update from Default Branch (Post-MVP)

Merge/rebase onto default branch from branches panel context menu.  
Scope: V1, not MVP.

---

## Naming Map — GitHub Desktop → GimMac

| GitHub Desktop (TS) | GimMac (Swift) | File |
|---|---|---|
| `Branch` class | `Branch` struct | `Domain/Branch.swift` |
| `BranchType` enum | `BranchType` enum | `Domain/Branch.swift` |
| `IBranchTip` | `BranchTip` struct | `Domain/Branch.swift` |
| `IAheadBehind` | `AheadBehind` struct | `Domain/BranchCompareResult.swift` |
| `ICompareResult` | `BranchCompareResult` struct | `Domain/BranchCompareResult.swift` |
| `StartPoint` enum | `BranchStartPoint` enum | `Domain/BranchStartPoint.swift` |
| `BranchesTab` enum | `BranchesTab` enum | `Domain/BranchesTab.swift` |
| `ITrackingBranch` | field on `Branch.upstream: String?` | `Domain/Branch.swift` |
| `getBranches` | `BranchProviding.fetchBranches` | `Domain/GitServiceProtocols.swift` |
| `getBranchesPointedAt` | `BranchProviding.fetchBranchesPointing(at:)` | — |
| `getMergedBranches` | `BranchProviding.fetchMergedBranches(into:)` | — |
| `createBranch` | `BranchOperating.createBranch(named:from:noTrack:)` | — |
| `getBranchCheckoutArgs` (checkout) | `BranchOperating.switchBranch(to:)` | — |
| `deleteLocalBranch` | `BranchOperating.deleteLocalBranch(_:force:)` | — |
| `deleteRemoteBranch` | `BranchOperating.deleteRemoteBranch(_:remote:)` | — |
| `renameBranch` | `BranchOperating.renameBranch(_:to:force:)` | — |
| `BranchesContainer` | `BranchesViewController` | `Presentation/Branches/` |
| `BranchList` | `BranchTableView` | `Presentation/Branches/` |
| `BranchListItem` | `BranchCellView` | `Presentation/Branches/` |
| `BranchListItemContextMenu` | Context menu on `BranchCellView` | — |
| `CreateBranchDialog` | `CreateBranchWindowController` | `Presentation/Branches/` |
| `DeleteBranchDialog` | `DeleteBranchWindowController` | `Presentation/Branches/` |
| `RenameBranchDialog` | `RenameBranchWindowController` | `Presentation/Branches/` |
| `StashAndSwitchBranchDialog` | `StashAndSwitchSheetController` | `Presentation/Branches/` |
| `BranchDropdown` (toolbar) | Make `TopToolbar` branch card interactive | `Presentation/Toolbar/` |
| `groupBranches` | `BranchGrouper` (sort by recency) | `Presentation/Branches/` |
| `MergeChooseBranchDialog` | `MergeTargetWindowController` | `Presentation/Branches/` (V1) |
| `RebaseChooseBranchDialog` | `RebaseTargetWindowController` | `Presentation/Branches/` (V1) |
| `CIStatus` | Omit — no CI integration in MVP | — |

---

## Implementation Order

```
Phase 1 — Domain models (Branch, BranchType, BranchStartPoint, AheadBehind, BranchCompareResult, BranchesTab)
Phase 2 — Service protocols (BranchProviding, BranchOperating, BranchCompareProviding)
Phase 3 — Data layer (GitBranchReader, GitBranchOperator + BranchForEachRefParser)
Phase 4 — Stash guard (DirtyWorkingTreeAction)
Phase 5 — ViewModels (BranchesViewModel)
Phase 6 — UI (BranchesViewController → BranchCellView → dialogs → toolbar wire-up)
Phase 7 — Compare branches (V1)
Phase 8 — Update from default (V1)
```

Each phase must be completable independently. Do not start Phase 6 before Phase 5 tests pass.

---

## Tests Required Per Phase

| Phase | Test type | Notes |
|---|---|---|
| 1 | Unit | Model equality, computed properties |
| 2 | — | Protocols have no logic |
| 3 | Integration | `TemporaryGitRepository` for each git operation |
| 4 | Unit | Stash guard state machine |
| 5 | Unit | ViewModel with injected fakes |
| 6 | Manual smoke | AppKit views — no XCTest UI automation in MVP |

---

## Git Command Reference

| Operation | Command | Flag notes |
|---|---|---|
| List all branches | `git for-each-ref --format=<fields> refs/heads refs/remotes` | Single call for both local + remote |
| Create branch | `git branch [name] [startPoint]` | Add `--no-track` when `noTrack=true` |
| Switch branch | `git switch [name]` | Do NOT use `git checkout` for switching |
| Delete local (safe) | `git branch -d [name]` | Fails if not merged |
| Delete local (force) | `git branch -D [name]` | User must confirm |
| Delete remote | `git push [remote] :[branchName]` | Empty refspec = delete |
| Rename (safe) | `git branch -m [old] [new]` | Fails if new name exists |
| Rename (force) | `git branch -M [old] [new]` | User must confirm override |
| Ahead/behind arbitrary | `git rev-list --left-right --count [base]...[compare]` | Already used for upstream |
| Branches at commit | `git branch --points-at=[sha] --format=%(refname:short)` | — |
| Merged branches | `git branch --merged [name] --format=%(refname:short)` | — |
| Merge default | `git merge [defaultBranch] --no-edit` | — |
| Rebase onto default | `git rebase [defaultBranch]` | — |
