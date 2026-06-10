# Missing Screens & Features Report

Comparison of GitHub Desktop screen inventory ([github-desktop-screens.md](github-desktop-screens.md))
against the current GimMac codebase. Generated 2026-06-10.

Scope: pure-Git operations only (no GitHub API/auth), per the source inventory.

---

## Screen-by-screen status

| # | Doc Screen | Status | Notes |
|---|---|---|---|
| 1 | Welcome / Onboarding | ✅ Done | identity config, clone, create (`git init`), add existing — `Onboarding/`, `CloneRepositoryWindowController`, `GitRepositoryCreationService` |
| 2 | Repository Selector | ✅ Done | switch/add/remove/recent — `RepositoryStoreViewModel`, `CoreDataRepositoryPersistence` |
| 3 | Changes Screen | ✅ Done | whole-file staging, commit (amend/sign-off/skip-hooks), discard, `.gitignore` (file/folder/`*.ext`), co-author trailer. Hunk/line staging is V1 per locked decisions |
| 4 | History Screen | 🟡 Partial | view/diff/compare done; right-click actions mostly missing |
| 5 | Branches Screen | ✅ Done | create/switch/delete/rename/compare/update-from-default all wired |
| 6 | Fetch/Pull/Push bar | ✅ Done | + force-push-with-lease, publish — `TopToolbar`, `GitRemoteSyncService` |
| 7 | **Merge Conflict Resolution** | ❌ Missing | detects conflicts + blocks commit, but tells user *"run continue/skip/abort from the terminal"* (`BranchDialogPresenter.swift:228`). No resolution UI |
| 8 | **Stash Screen** | ❌ Missing | only auto-stash-on-switch (`StashAndSwitchSheetController`). No stash list/manage screen. Backend supports single stash only (`fetchStash` returns one) |
| 9 | Clone Dialog | ✅ Done | `CloneRepositoryWindowController` |
| 10 | Create Repository | 🟡 Partial | `git init` done. No README / .gitignore template / license options |
| 11 | Repository Settings | ✅ Done | remote URL, default branch rename, LFS, open in editor/terminal |
| 12 | External Editor | ✅ Done | `NSWorkspaceExternalEditorService` |
| 13 | Compare Before Merge | ✅ Done | `BranchCompareViewModel`, `CompareBranchWindowController` |
| 14 | Advanced History Editing | 🟡 Partial | squash ✅ wired; reorder + drag-drop cherry-pick = empty stubs |

---

## Missing / incomplete features (detail)

### ❌ Fully missing screens

1. **Merge Conflict Resolution screen** — largest gap. Backend has `abortMerge` /
   `continueRebase` / `skipCommit` (`MergeBranchProviding`, `RebaseProviding`) but
   no UI; punts the user to the terminal.
2. **Stash management screen** — list stashes, apply/pop/drop from UI. Only
   single-stash backend + auto-stash-on-switch exists.

### ❌ Missing History right-click actions (doc §4)

- **Revert commit** (`git revert`) — no service, no UI
- **Cherry-pick** — UI button exists but empty `{}` stub (`CommitHistorySidebar.swift:88`), no service
- **Create branch from commit** — not wired to context menu
- **Reset to commit** (`git reset --soft|mixed|hard`) — only internal undo/discard use it, not exposed
- **Tag commit** (`git tag`) — completely absent (domain, data, UI)

### Changes-screen features (doc §3)

- **Stage/unstage individual files** — ✅ whole-file include/exclude via checkboxes. Hunk/line staging stays **V1 per locked decisions**.
- **Ignore file → `.gitignore`** — ✅ context-menu "Ignore" submenu: Ignore File, Ignore Folder (ancestor submenu), Ignore All `*.ext`. `GitIgnoreRule` (escaping/rule builder) + `GitIgnoreProvider` (root `.gitignore` write, de-duped).
- **Co-author commit trailer** — ✅ `Co-authored-by:` trailer via co-author input in `CommitBox`. `CommitAuthor` value type, `CommitOptions.coAuthors`, appended as a trailing `-m` paragraph in `GitCommitProvider`.

### 🟡 Stub-only (UI present, no logic)

- Reorder commits (`CommitHistorySidebar.swift:90`)
- Cherry-pick N commits (`CommitHistorySidebar.swift:88`)

### 🟡 Create Repository

- Missing README / .gitignore-template / license scaffolding (init-only currently)

---

## Suggested priority

Highest-value gaps vs the inventory:

1. Merge conflict resolution screen (currently delegates to terminal)
2. Tag commit
3. Revert + cherry-pick context-menu actions (wire the existing stubs)
4. Stash management screen
