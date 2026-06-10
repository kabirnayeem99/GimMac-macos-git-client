# GitHub Desktop — macOS Menu Bar Reference

Reference doc mapping every macOS menu bar item in the GitHub Desktop codebase to its
native Electron code and underlying Git CLI command. Use as a baseline when porting
menu actions to GimMac (`NSMenu` + `GitClientProtocol` / `ProcessGitClient`).

## Architecture

GitHub Desktop builds the macOS menu with Electron's `Menu.buildFromTemplate`. Each
menu item emits a `MenuEvent` over IPC → renderer `dispatcher` → git lib function.
Git is executed via **dugite** (a git CLI wrapper) — **no libgit2**. This matches
GimMac's locked decision: process-based CLI wrapper (`ProcessGitClient`) only.

- Native menu code: `app/src/main-process/menu/build-default-menu.ts`
- Event enum: `app/src/main-process/menu/menu-event.ts`
- Git command wrappers: `app/src/lib/git/`
- dugite invocation helper: `app/src/lib/git/core.ts` — `git(args, path, name)`

Flow: `menu item → emit('<event>') → IPC 'menu-event' → renderer dispatcher → git lib fn`

---

## 🟦 GitHub Desktop (app menu) — `__DARWIN__` only

| Item | id / role | Event | Git CLI |
|---|---|---|---|
| About GitHub Desktop | `about` | `show-about` | — (UI) |
| Settings… `⌘,` | `preferences` | `show-preferences` | — (reads `git config`) |
| Install Command Line Tool… | `install-cli` | `install-darwin-cli` | — (symlinks binary) |
| Services / Hide / Hide Others / Show All / Quit | roles | — | — (Electron native roles) |

## 📄 File

| Item | id | Event | Git CLI |
|---|---|---|---|
| New Repository… `⌘N` | `new-repository` | `create-repository` | `git init` (`init.ts`) |
| Add Local Repository… `⌘O` | `add-local-repository` | `add-local-repository` | — (validates via `git rev-parse`) |
| Clone Repository… `⌘⇧O` | `clone-repository` | `clone-repository` | `git clone --recursive --progress -- <url> <path>` (`clone.ts:43`) |

## ✏️ Edit

| Item | role/event | Git CLI |
|---|---|---|
| Undo / Redo / Cut / Copy / Paste | Electron roles | — |
| Select All `⌘A` | `select-all` | — |
| Find `⌘F` | `find-text` | — |

## 👁 View — pure UI, no git

| Item | Event |
|---|---|
| Show Changes `⌘1` | `show-changes` |
| Show History `⌘2` | `show-history` |
| Show Repository List `⌘T` | `choose-repository` |
| Show Branches List `⌘B` | `show-branches` |
| Go to Summary `⌘G` | `go-to-commit-message` |
| Show/Hide Stashed Changes `⌃H` | `show-stashed-changes` / `hide-stashed-changes` |
| Show/Hide Changes Filter `⌘L` | `toggle-changes-filter` |
| Toggle Full Screen | role `togglefullscreen` |
| Reset Zoom `⌘0` / Zoom In `⌘=` / Out `⌘-` | `zoom()` (Electron `webContents.zoomFactor`) |
| Expand Active Resizable `⌘9` | `increase-active-resizable-width` |
| Contract Active Resizable `⌘8` | `decrease-active-resizable-width` |
| Reload `⌘⌥R` (dev only) | `focusedWindow.reload()` |
| Toggle Developer Tools `⌥⌘I` | `webContents.toggleDevTools()` |

## 📦 Repository

| Item | id | Event | Git CLI |
|---|---|---|---|
| Push `⌘P` (or Force Push…) | `push` | `push` / `force-push` | `git push [--set-upstream] [--force-with-lease] [--no-verify] --progress` (`push.ts:57`) |
| Pull `⌘⇧P` | `pull` | `pull` | `git pull [--no-rebase / --rebase] --progress` (`pull.ts:96`) |
| Fetch `⌘⇧T` | `fetch` | `fetch` | `git fetch --prune --progress <remote>` (`fetch.ts:14`) |
| Remove… `⌘⌫` | `remove-repository` | `remove-repository` | — (drops from app DB) |
| Open in <Shell> `⌃\`` | `open-in-shell` | `open-in-shell` | — (spawns terminal) |
| Show in Finder `⌘⇧F` | `open-working-directory` | `open-working-directory` | — (`shell`) |
| Open in <Editor> `⌘⇧A` | `open-external-editor` | `open-external-editor` | — (launches editor) |
| Open With… `⌘⇧⌥A` | `open-with-external-editor` | `open-with-external-editor` | — |
| Repository Settings… | `show-repository-settings` | `show-repository-settings` | `git config` + `git remote` (`config.ts`, `remote.ts`) |

## 🌿 Branch

| Item | id | Event | Git CLI |
|---|---|---|---|
| New Branch… `⌘⇧N` | `create-branch` | `create-branch` | `git branch <name> [<startPoint>] [--no-track]` (`branch.ts:28`); checkout via `git checkout` (`checkout.ts`) |
| Rename… `⌘⇧R` | `rename-branch` | `rename-branch` | `git branch -m/-M <old> <new>` (`branch.ts:56`) |
| Delete… `⌘⇧D` | `delete-branch` | `delete-branch` | `git branch -D <name>`; remote: `git push <remote> :<branch>` (`branch.ts:105,120`) |
| Discard All Changes… `⌘⇧⌫` | `discard-all-changes` | `discard-all-changes` | `git checkout -- <paths>` / `git reset` (`reset.ts`, `checkout-index.ts`) |
| Stash All Changes `⌘⇧S` | `stash-all-changes` | `stash-all-changes` | `git stash push -m <msg>` (`stash.ts:159`) |
| Update from <DefaultBranch> `⌘⇧U` | `update-branch-with-contribution-target-branch` | same | `git merge` or `git rebase` (`merge.ts`, `rebase.ts`) |
| Compare to Branch `⌘⇧B` | `compare-to-branch` | `compare-to-branch` | `git log` / `git rev-list` (`log.ts`, `rev-list.ts`) |
| Merge into Current Branch… `⌘⇧M` | `merge-branch` | `merge-branch` | `git merge [--no-verify] <branch>` (`merge.ts:41`) |
| Squash and Merge into Current… `⌘⇧H` | `squash-and-merge-branch` | `squash-and-merge-branch` | `git merge --squash <branch>` then `git commit --no-edit` (`merge.ts:44,67`) |
| Rebase Current Branch… `⌘⇧E` | `rebase-branch` | `rebase-branch` | `git rebase <base> <target>` (+ `--continue`/`--skip`/`--abort`) (`rebase.ts:396`) |

## 🪟 Window — `__DARWIN__` only

Minimize / Zoom / Close / Front — all Electron native roles. No git.

## ❓ Help

| Item | Action | Git CLI |
|---|---|---|
| Show Logs in Finder | `UNSAFE_openDirectory(logPath)` | — |
| + `buildTestMenu()` items (dev/test builds) | various | various |

---

## Notes for GimMac port

- **No libgit2.** GitHub Desktop runs git CLI via dugite (`git(args, path, name)` in `core.ts`).
  Matches GimMac locked decision: `ProcessGitClient` only.
- Menu item → `emit('<event>')` → IPC `menu-event` → renderer `dispatcher` → git lib fn.
  Event names enumerated in `menu-event.ts`.
- Dynamic labels (Push↔Force Push, Show↔Hide Stash, changes-filter Show↔Hide) computed at
  build time from `MenuLabelsEvent` flags in `build-default-menu.ts`.
- Pure-UI items (View menu, zoom, devtools) never touch git — handle in ViewModel only.
- Port path: each MenuEvent maps to an `NSMenuItem` action → ViewModel method → `GitClientProtocol`.
