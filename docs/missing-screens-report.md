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
| 4 | History Screen | ✅ Done | view/diff/compare + revert + cherry-pick + tag + create-branch-from-commit + reset-to-commit (soft/mixed/hard) all wired |
| 5 | Branches Screen | ✅ Done | create/switch/delete/rename/compare/update-from-default all wired |
| 6 | Fetch/Pull/Push bar | ✅ Done | + force-push-with-lease, publish — `TopToolbar`, `GitRemoteSyncService` |
| 7 | **Merge Conflict Resolution** | ❌ Missing | detects conflicts + blocks commit, but tells user *"run continue/skip/abort from the terminal"* (`BranchDialogPresenter.swift:228`). No resolution UI |
| 8 | **Stash Screen** | ❌ Missing | only auto-stash-on-switch (`StashAndSwitchSheetController`). No stash list/manage screen. Backend supports single stash only (`fetchStash` returns one) |
| 9 | Clone Dialog | ✅ Done | `CloneRepositoryWindowController` |
| 10 | Create Repository | 🟡 Partial | `git init` done. No README / .gitignore template / license options |
| 11 | Repository Settings | ✅ Done | remote URL, default branch rename, LFS, open in editor/terminal |
| 12 | External Editor | ✅ Done | `NSWorkspaceExternalEditorService` |
| 13 | Compare Before Merge | ✅ Done | `BranchCompareViewModel`, `CompareBranchWindowController` |
| 14 | Advanced History Editing | ✅ Done | squash + cherry-pick + reorder (drag-to-reorder via interactive rebase) all wired |

---

## Missing / incomplete features (detail)

### ❌ Fully missing screens

1. **Merge Conflict Resolution screen** — largest gap. Backend has `abortMerge` /
   `continueRebase` / `skipCommit` (`MergeBranchProviding`, `RebaseProviding`) but
   no UI; punts the user to the terminal.
2. **Stash management screen** — list stashes, apply/pop/drop from UI. Only
   single-stash backend + auto-stash-on-switch exists.

### ❌ Missing History right-click actions (doc §4)

- **Revert commit** (`git revert`) — ✅ `RevertProviding` / `GitRevertProvider`, single-commit context-menu "Revert This Commit", conflict-aborts to clean tree
- **Cherry-pick** — ✅ `CherryPickProviding` / `GitCherryPickProvider`, wired for single + multi-select context menu, conflict-aborts to clean tree
- **Create branch from commit** — ✅ `CreateBranchFromCommitSheet` + context-menu "Create Branch from Commit…", reuses `BranchOperating.createBranch(from: .commit)`
- **Reset to commit** (`git reset --soft|mixed|hard`) — ✅ `ResetProviding` / `GitResetProvider`, `ResetToCommitSheet` (mode picker + hard-reset warning + red confirm), context-menu "Reset to Commit…"
- **Tag commit** (`git tag`) — ✅ `TagProviding` / `GitTagProvider` (lightweight + annotated), `CreateTagSheet` + context-menu "Create Tag…"

### Changes-screen features (doc §3)

- **Stage/unstage individual files** — ✅ whole-file include/exclude via checkboxes. Hunk/line staging stays **V1 per locked decisions**.
- **Ignore file → `.gitignore`** — ✅ context-menu "Ignore" submenu: Ignore File, Ignore Folder (ancestor submenu), Ignore All `*.ext`. `GitIgnoreRule` (escaping/rule builder) + `GitIgnoreProvider` (root `.gitignore` write, de-duped).
- **Co-author commit trailer** — ✅ `Co-authored-by:` trailer via co-author input in `CommitBox`. `CommitAuthor` value type, `CommitOptions.coAuthors`, appended as a trailing `-m` paragraph in `GitCommitProvider`.

### ✅ Formerly stub-only — now wired

- Reorder commits — `ReorderProviding` / `GitReorderProvider` (interactive-rebase todo, like squash), `ReorderCommitsSheet` (drag-to-reorder), conflict-aborts to clean tree

### 🟡 Create Repository

- Missing README / .gitignore-template / license scaffolding (init-only currently)

---

## Suggested priority

Highest-value gaps vs the inventory:

1. Merge conflict resolution screen (currently delegates to terminal) — **now the top remaining gap**
2. ~~Tag commit~~ ✅ done
3. ~~Revert + cherry-pick context-menu actions~~ ✅ done
4. ~~Reset-to-commit + Reorder commits~~ ✅ done — screens #4 and #14 fully closed
4. Stash management screen
