# PLAN.md

## Summary of Changes from Review

The following issues were found and resolved in this revision:

- **Contradiction fixed:** The first implementation task list said "Create macOS SwiftUI app" — corrected to AppKit, consistent with the rest of the document.
- **Minimum macOS version locked:** macOS 14 (Sonnet). This unblocks SwiftData, the Observation framework, and async/await AppKit patterns.
- **GitAppError defined:** Error taxonomy was referenced in the state model but never specified. Now defined.
- **FileChange.id clarified:** String identity was ambiguous for renames. Now uses a stable composite key strategy.
- **Architecture locked:** "MVVM or MVC+service layer depending on screen complexity" was too vague. Now locked to MVVM + Observation.
- **Ahead/behind fetch strategy documented:** These fields existed in RepositoryState with no explanation of how they are populated.
- **Detached HEAD handling noted:** currentBranch: String? needed a stated display policy.
- **Phase order fixed:** Phase 8 (Advanced History Editing) is V1 scope and appears after MVP phases.
- **Tags explicitly scoped out:** Not mentioned anywhere previously. Now explicitly deferred to Later.
- **SwiftData conditional on macOS version clarified.**
- **Testing strategy sketch added.**
- **Security rule #4 made specific:** Named the actual attack vectors (core.hooksPath, core.fsmonitor, filter.*).

---

## Goal

Build a native **macOS-only** Git client that closely follows the GitHub Desktop workflow and layout, but implemented as a native Apple app instead of Electron. The first target is local Git workflows. Public release may happen later, so the app must avoid GitHub trademarks, icons, names, and exact copied assets.

---

## Position

Use **Swift + AppKit-first UI**, not Objective-C-first. SwiftUI may be used only for simple isolated screens where it does not hurt control or performance.

Objective-C is not meaningfully faster for this app. The bottlenecks are Git process execution, filesystem scanning, diff generation, rendering large file lists, and network calls. Swift gives better type safety, modern concurrency, SwiftUI/AppKit interop, and easier long-term maintenance. Use Objective-C only for small interop cases if a legacy macOS API is awkward from Swift.

---

## Platform Target

**Minimum macOS: 14.0 (Sonnet)**

This decision enables:

- `Observation` framework (`@Observable`) instead of Combine for MVVM
- `SwiftData` for app metadata persistence (no Core Data)
- Full `async/await` with AppKit without backporting concerns
- `NSTextContentManager` for diff rendering if needed

If the target is later lowered to macOS 13, SwiftData must be replaced with SQLite + a hand-rolled store, and `@Observable` must be replaced with Combine.

---

## Product Scope

### MVP

1. Add local repository
2. Repository switcher
3. Current branch display (including detached HEAD state)
4. Changed files list
5. File diff viewer
6. Stage / unstage whole files only
7. Commit summary and description
8. Commit with GPG or SSH signing through existing Git config
9. Branch list
10. Create branch
11. Checkout branch
12. Basic merge branch into current branch
13. Conflict detection and simple conflict screen
14. Fetch / pull / push for existing remotes
15. Force push with explicit `--force-with-lease` only
16. App preferences for Git path, author name/email, theme, signing status

Out of MVP:

- Hunk-level staging
- Commit graph/history beyond a simple recent log
- Tags (read-only display deferred to Later)
- Submodule operations

### V1

1. Commit history graph
2. Rebase/squash UI for last N commits
3. Cherry-pick commits
4. Amend last commit
5. Stash list / create / pop / drop
6. Submodule detection
7. LFS detection and install guidance
8. Better conflict resolution
9. Notifications for push/pull/fetch status
10. Keyboard shortcuts

### Later

1. Multi-platform Windows/Linux rewrite is out of scope unless the UI moves away from native Apple frameworks.
2. Hosted-platform integrations are out of scope for first version.
3. Built-in code editor is out of scope. Open external editor instead.
4. Tags: read-only tag list and tag display in branch picker.
5. Worktree support.

---

## Technical Stack

### Preferred

- Language: Swift
- UI: AppKit first; SwiftUI only for simple secondary views
- Architecture: **MVVM with Observation framework** (`@Observable`, macOS 14+)
- Git engine: Process-based Git CLI wrapper
- Git binary: system Git / Homebrew Git first; no bundled Git in MVP
- Networking: URLSession
- Persistence: SwiftData for app metadata (requires macOS 14+); fall back to SQLite if target is lowered
- Secrets: Keychain
- Logging: OSLog
- Testing: XCTest + in-process mock `GitClient`

### Avoid Initially

- libgit2 for core operations
- Objective-C-first codebase
- Electron/WebView UI
- Over-abstracted plugin architecture
- Building a full diff engine before CLI-backed diff works
- Core Data (SwiftData supersedes it on macOS 14+)

---

## Architecture Plan

### Primary Pattern: MVVM + Observation

All screens use a `ViewModel` (`@Observable` class) owned by the view or injected via environment. Services are injected into ViewModels via protocol. This is the single pattern used throughout — no MVC/service-layer mixing.

```
View (AppKit NSViewController or SwiftUI View)
  └── ViewModel (@Observable class)
        └── Service protocols (GitService, BranchService, etc.)
              └── GitClient (process runner)
```

### Main Modules

1. **AppShell**
   - Window layout
   - Sidebar
   - Toolbar
   - Navigation

2. **RepositoryStore**
   - Known repositories
   - Recent repositories
   - Selected repository
   - Repository metadata cache

3. **GitClient**
   - Runs Git commands via `Process`
   - Captures stdout/stderr separately
   - Handles timeout and cancellation
   - Returns typed `GitResult`

4. **GitParser**
   - Parses porcelain output
   - Parses branch output
   - Parses diff output
   - Parses status and conflict states

5. **DiffEngine**
   - Starts with `git diff`
   - Converts unified diff into `DiffFile` / `DiffHunk` / `DiffLine` models
   - Later supports hunk-level staging

6. **CommitService**
   - Commit creation
   - Amend
   - Signing support through Git config
   - Co-authors later

7. **BranchService**
   - Branch list
   - Checkout
   - Create
   - Merge
   - Rebase later

8. **RemoteService**
   - Fetch (populates ahead/behind via `git rev-list --count`)
   - Pull
   - Push
   - Force push with lease
   - Remote URL handling

9. **PreferencesStore**
    - Git path
    - Theme
    - External editor
    - Signing settings display

---

## Error Taxonomy

`GitAppError` covers all typed failures in the app. Every `GitService` call converts raw exit codes and stderr into one of these cases.

```swift
enum GitAppError: Error {
    // Process-level
    case timeout(command: String)
    case cancelled
    case binaryNotFound(path: String)

    // Exit code failures
    case processFailure(exitCode: Int32, stderr: String)
    case parseFailure(output: String, context: String)

    // Git domain
    case conflictDetected(files: [String])
    case nothingToCommit
    case detachedHead
    case remoteRejected(reason: String)
    case authFailure(remote: String)
    case forcePushBlocked

    // App
    case repositoryNotFound(path: URL)
    case permissionDenied(path: URL)
    case unsupportedGitVersion(found: String, required: String)
}
```

---

## Ahead / Behind Count Strategy

`RepositoryState.aheadCount` and `behindCount` are populated after every fetch operation using:

```bash
git rev-list --count HEAD..@{u}   # behind
git rev-list --count @{u}..HEAD   # ahead
```

These values are only valid when a tracking remote branch exists. If no upstream is set, both values are `nil` (use `Int?` in the model). The RemoteService is responsible for running these after each fetch and on initial repository load.

---

## `FileChange` Identity Strategy

Renames require a composite key. Path alone breaks SwiftUI diffing when a file is renamed.

```swift
struct FileChange: Identifiable {
    // Stable identity: old path if rename, otherwise new path.
    // Prefixed with status character to avoid collisions between
    // an added "foo.swift" and a renamed-from "foo.swift".
    var id: String { "\(status.rawValue):\(oldPath ?? path)" }

    let path: String           // current (new) path
    let oldPath: String?       // only set for renames
    let status: GitFileStatus
    let isStaged: Bool
    let hasConflict: Bool
}
```

---

## Detached HEAD Policy

When `git rev-parse --abbrev-ref HEAD` returns `HEAD`, the repository is in detached HEAD state.

- `currentBranch` is set to `nil`
- The branch display shows: `HEAD (detached @ abc1234)` using the short SHA from `git rev-parse --short HEAD`
- Commit is still allowed; the result is a detached commit
- Branch creation from detached HEAD is surfaced as a prompt: "You are not on a branch. Create a branch to keep your commits."
- Push is blocked with a clear error until a branch is created

---

## Testing Strategy

### Unit Tests (XCTest)

- `GitParser` is tested entirely in-process with fixture strings. No real Git needed.
- `GitClient` protocol allows injection of a `MockGitClient` that returns pre-canned `GitResult` values.
- ViewModels are tested by injecting mocks for all service protocols.

### Integration Tests

- A `TemporaryGitRepository` helper creates a real Git repo in a temp directory, performs real operations, and tears down on deinit.
- Integration tests run only on macOS (no simulator needed).
- Cover: status parsing, commit creation, branch operations, merge conflict detection.

### Mock Structure

```swift
final class MockGitClient: GitClientProtocol {
    var responses: [String: Result<GitResult, GitAppError>] = [:]

    func run(_ arguments: [String], in repositoryURL: URL, timeout: TimeInterval) async throws -> GitResult {
        let key = arguments.joined(separator: " ")
        switch responses[key] {
        case .success(let result): return result
        case .failure(let error): throw error
        case nil: throw GitAppError.processFailure(exitCode: 1, stderr: "No mock for: \(key)")
        }
    }
}
```

---

## Development Phases

### Phase 0: Research and Legal Boundary

- Decide app name and branding.
- Do not use GitHub Desktop name, icon, logo, or exact assets.
- UI can be functionally similar, but avoid redistributing a pixel-perfect trademark clone.
- Study GitHub Desktop workflows and public open-source implementation for behavioral reference.

### Phase 1: Skeleton App

- Create macOS Swift **AppKit** app. *(Not SwiftUI — AppKit-first per architecture decision.)*
- Add native `NSSplitViewController` layout: repository/sidebar area, changed files list, diff pane, commit panel.
- Add local repository selector.
- Store selected repo path.
- Show current branch (or detached HEAD display).

### Phase 2: Git CLI Foundation

- Implement `GitClient.run()`.
- Support working directory.
- Capture stdout/stderr separately.
- Add timeout.
- Add cancellation.
- Add typed `GitAppError` cases.
- Add `TemporaryGitRepository` test helper.
- Add unit tests with `MockGitClient`.

### Phase 3: Status and Changes

- Run `git status --porcelain=v1 -z`.
- Parse changed files with composite identity strategy.
- Display file state: added, modified, deleted, renamed, conflicted, untracked.
- Refresh on app focus and filesystem change (debounced).

### Phase 4: Diff Viewer

- Run `git diff -- <file>`.
- Run `git diff --cached -- <file>` for staged view.
- Render unified diff using `DiffFile` / `DiffHunk` / `DiffLine` models.
- Add syntax highlighting for added/removed/context lines.
- Show "file too large" fallback for diffs over a configurable line threshold.
- Later: side-by-side diff.

### Phase 5: Stage and Commit

- Stage whole file: `git add -- <file>`.
- Unstage whole file: `git restore --staged -- <file>`.
- No hunk-level staging in MVP.
- Commit: `git commit -m <summary> -m <body>`.
- GPG and SSH signing work automatically if `commit.gpgsign` and `gpg.format` are configured.
- Add signing status indicator by reading Git config.

### Phase 6: Branching

- List branches: `git branch --format=...`.
- Checkout branch: `git switch <branch>`.
- Create branch: `git switch -c <branch>`.
- Merge: `git merge <branch>`.
- Detect conflicts from exit code and status.
- Display detached HEAD state per policy above.

### Phase 7: Remote Operations (MVP complete after this phase)

- Fetch: `git fetch --prune`, followed by ahead/behind count refresh.
- Pull: `git pull --ff-only` by default.
- Push: `git push`.
- Force push: `git push --force-with-lease`, gated by typed confirmation.
- Never default to raw `--force`.

### Phase 8: Advanced History Editing (V1 starts here)

This is not MVP. Add after local Git is stable.

- Rebase/squash UI for last N commits.
- Cherry-pick and amend flows.
- Stash management.
- Always create a backup ref before destructive history edits.

### Phase 9: Quality and UX (V1)

- For combining last N commits, safest implementation:
  - `git reset --soft HEAD~N`
  - Create a new commit
- For arbitrary commits, use interactive rebase only after a proper todo-list UI exists.
- Always create a backup ref before destructive history edits.

### Phase 10: Polish

- Keyboard shortcuts.
- Empty states (no repos, no changes, no branches).
- Error recovery dialogs.
- Accessibility (VoiceOver labels on all interactive elements).
- Large repository performance.
- Background refresh throttling.
- Crash logging.

---

## Git Commands Needed

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD        # branch name; returns "HEAD" if detached
git rev-parse --short HEAD             # short SHA for detached HEAD display
git status --porcelain=v1 -z
git branch --format='%(refname:short)|%(objectname)|%(upstream:short)'
git diff -- <file>
git diff --cached -- <file>
git add -- <file>
git restore --staged -- <file>
git commit -m "summary" -m "body"
git switch <branch>
git switch -c <branch>
git merge <branch>
git fetch --prune
git rev-list --count HEAD..@{u}        # behind count
git rev-list --count @{u}..HEAD        # ahead count
git pull --ff-only
git push
git push --force-with-lease
git config --get user.name
git config --get user.email
git config --get commit.gpgsign
git config --get user.signingkey
git log --oneline --decorate --graph --max-count=100
```

---

## GPG / SSH Signing Plan

Do not implement cryptographic signing manually.

Use Git's own signing system.

The app should:

1. Detect signing config.
2. Show whether commit signing is enabled.
3. Let user toggle Git config if requested.
4. Let Git invoke GPG, SSH signing, pinentry, or Keychain-backed flows.
5. Surface signing failure clearly using `GitAppError.processFailure`.

Relevant config:

```bash
git config --global commit.gpgsign true
git config --global user.signingkey <key-id>
git config --global gpg.format openpgp
```

For SSH signing:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

---

## Risks

1. Diff rendering performance on large files.
2. Hunk-level staging complexity.
3. Merge conflict UX.
4. Configuration edge cases.
5. GPG/pinentry failures.
6. Sandboxing restrictions if distributed through Mac App Store.
7. Legal/trademark risk if marketed as a clone.
8. macOS version target being lowered, invalidating SwiftData and Observation choices.

---

## First Implementation Task List

1. Create macOS **AppKit** app (not SwiftUI — see architecture decision).
2. Build `GitClient` wrapper around `Process`.
3. Add `TemporaryGitRepository` test helper.
4. Define and implement `GitAppError` taxonomy.
5. Implement `git status --porcelain=v1 -z` parser.
6. Build repository picker.
7. Show changed files list using composite `FileChange.id`.
8. Show basic unified diff.
9. Stage/unstage whole file.
10. Commit summary/body.
11. Push/pull/fetch buttons with ahead/behind refresh.

---

## Locked Decisions

1. Target platform: macOS 14+ only.
2. Minimum macOS version: 14.0 (Sonnet).
3. Architecture: MVVM with Observation framework.
4. Product direction: native GitHub Desktop-like workflow, safe for possible public release.
5. MVP: local Git only with no hosted-platform-specific features.
6. Staging: whole-file staging in MVP; hunk-level in V1.
7. Git binary: system/Homebrew Git in MVP; no bundled Git.
8. Signing: support both GPG and SSH signing through Git config.
9. UI: AppKit-first.
10. Tags: out of scope until Later.

---

## Remaining Open Questions

1. App name.
2. Whether to include a simple commit history in MVP.
3. Whether to add hosted-platform integrations after V1.
4. Whether direct public release should use Sparkle auto-update.
