# DESIGN.md

## Summary of Changes from Review

- **DiffLine struct completed:** It was referenced by `DiffHunk` but never defined.
- **Security rule #4 made specific:** The original said "do not trust repository config blindly." Now names the exact attack vectors: `core.hooksPath`, `core.fsmonitor`, and `filter.*` keys.
- **Detached HEAD UI plan added:** The state model used `currentBranch: String?` with no stated display policy.
- **FileChange.id strategy reflected in state model:** Composite key documented (see PLAN.md).
- **GitAppError cases referenced in state model:** `lastError` now has a defined type with cases.
- **Ignored files behaviour documented:** Users will ask why files are not shown.
- **Empty states added to screen designs.**
- **aheadCount / behindCount typed as optional:** No upstream = no value; reflects the fetch strategy from PLAN.md.

---

## Design Goal

Native macOS Git client with a GitHub Desktop-like workflow:

- left repository/branch context
- center changed files list
- right diff viewer
- bottom/side commit form
- minimal Git jargon for normal flow
- advanced Git operations hidden behind explicit menus

---

## UI Principles

1. Fast first screen.
2. No terminal required for common Git tasks.
3. Show dangerous operations clearly.
4. Prefer safe Git defaults.
5. Keep state visible: branch, sync status, staged/unstaged, conflicts.
6. Do not hide errors behind vague messages.
7. Show detached HEAD state explicitly — never silently show an empty branch field.
8. Surface ignored-file behaviour: the app only shows what `git status` reports; files excluded by `.gitignore` will not appear, and this should be noted in empty-file-list states.

---

## Main Window Layout

```text
┌────────────────────────────────────────────────────────────┐
│ Toolbar: Repo | Branch | Fetch | Pull | Push | PR          │
├───────────────┬──────────────────────┬─────────────────────┤
│ Sidebar       │ Changed Files         │ Diff Viewer         │
│               │                      │                     │
│ Repositories  │ [ ] file1.swift       │ unified/side-by-side│
│ Branches      │ [x] file2.swift       │                     │
│ History       │ ⚠ conflict.txt        │                     │
│               │                      │                     │
├───────────────┴──────────────────────┴─────────────────────┤
│ Commit summary                                             │
│ Commit description                                         │
│ [Commit to branch]                                         │
└────────────────────────────────────────────────────────────┘
```

---

## Screens

### Welcome Screen

Actions:

- Clone repository
- Add existing repository
- Create new repository
- Sign in to GitHub

Empty state: shown on first launch or when all repositories are removed. Prompt the user to add or clone a repository.

### Repository Screen

Shows:

- Repository name
- Current branch — or `HEAD (detached @ abc1234)` if in detached HEAD state
- Ahead/behind count (hidden if no upstream is configured)
- Changed files
- Selected file diff
- Commit box

Empty states:

- No changes: "No local changes. Your working copy is clean."
- No file selected: "Select a file to view its diff."
- File too large: "This diff is too large to display. Open in external editor."
- Ignored files note: "Files excluded by .gitignore are not shown here."

### Branch Picker

Shows:

- Current branch (or detached HEAD indicator)
- Local branches
- Remote branches
- Create branch action
- Checkout action

Empty state: "No branches found. This may be a new repository with no commits."

### History Screen

Shows:

- Commit list
- Selected commit details
- Changed files in commit
- Commit diff
- Actions: checkout, cherry-pick, revert, squash (V1)

Empty state: "No commit history yet. Make your first commit to get started."

### Conflict Screen

Shows:

- Conflicted files
- Current status
- Open in external editor
- Mark resolved (active after conflict markers are no longer present in the file)
- Abort merge / abort rebase
- Continue merge/rebase if all conflicts are resolved

### Detached HEAD Screen

Triggered when `git rev-parse --abbrev-ref HEAD` returns `HEAD`.

Shows:

- Warning banner: "You are in detached HEAD state. You are not on a branch."
- Short SHA and timestamp of current commit
- Button: "Create Branch from Here" — runs `git switch -c <name>`
- Commit is still allowed but the warning banner remains
- Push is blocked with inline message: "Create a branch before pushing."

### Preferences

Sections:

- Git binary path
- Name / email
- Commit signing
- External editor
- Theme
- GitHub account

---

## Dangerous Operation UX

### Force Push

Allowed command:

```bash
git push --force-with-lease
```

Never offer raw `--force`.

Dialog must show:

- Current branch
- Remote branch
- Ahead/behind state
- Warning that remote commits may be overwritten
- Require typed confirmation: `force push`

### Reset / Squash

Before history rewrite:

```bash
git branch backup/<branch>-<timestamp>
```

Then proceed. Show the backup branch name in the confirmation dialog so the user knows how to recover.

### Merge

Default merge is normal `git merge`.

If conflict occurs:

- Stop normal UI flow
- Show conflicted files in Conflict Screen
- Provide abort merge
- Provide continue after all conflicts resolved

---

## Git Service Design

### GitClient API

```swift
protocol GitClientProtocol {
    func run(
        _ arguments: [String],
        in repositoryURL: URL,
        timeout: TimeInterval
    ) async throws -> GitResult
}

struct GitResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}
```

### Rules

- Never build shell strings. Always pass arguments as an array.
- Always use `--` before file paths.
- Always capture stderr.
- Treat non-zero exit as a typed `GitAppError`.
- Add timeout for long commands.
- Run commands off the main thread.
- Never pass repository-supplied values directly to system paths or environment variables.

---

## State Model

```swift
struct RepositoryState {
    var path: URL
    var name: String
    var currentBranch: String?    // nil means detached HEAD
    var headSHA: String?          // short SHA; populated when currentBranch is nil
    var aheadCount: Int?          // nil if no upstream configured
    var behindCount: Int?         // nil if no upstream configured
    var changes: [FileChange]
    var selectedFile: FileChange?
    var isRefreshing: Bool
    var lastError: GitAppError?
}
```

```swift
struct FileChange: Identifiable {
    // Composite identity: status prefix + anchor path.
    // Stable across refreshes; handles renames correctly.
    var id: String { "\(status.rawValue):\(oldPath ?? path)" }

    let path: String        // current (new) path
    let oldPath: String?    // set only for renames
    let status: GitFileStatus
    let isStaged: Bool
    let hasConflict: Bool
}
```

---

## Diff Model

```swift
struct DiffFile {
    let oldPath: String?
    let newPath: String
    let hunks: [DiffHunk]
    let isBinary: Bool
    let isTooLarge: Bool    // set when line count exceeds rendering threshold
}

struct DiffHunk {
    let header: String
    let lines: [DiffLine]
}

struct DiffLine {
    let kind: DiffLineKind
    let oldLineNumber: Int?
    let newLineNumber: Int?
    let content: String     // raw line text, newline stripped
}

enum DiffLineKind {
    case context
    case added
    case removed
    case metadata    // hunk header lines beginning with @@
}
```

---

## Performance Design

1. Debounce filesystem refresh (minimum 300ms between refreshes).
2. Cache status for current repository; invalidate on focus and filesystem event.
3. Lazy-load diff only for selected file.
4. Avoid rendering huge diffs fully; set a line threshold (e.g. 5000 lines) and show a fallback.
5. Show "file too large" fallback with an open-in-editor button.
6. Cancel stale Git commands when repo or selection changes.
7. Use `git status -z` for null-delimited, machine-safe parsing.
8. Ahead/behind refresh runs after fetch, not on every status poll.

---

## Security Design

1. Store GitHub tokens only in Keychain. Never write to disk or log.
2. Do not log tokens, remotes with embedded credentials, or auth headers.
3. Do not execute Git commands through `/bin/sh -c`. Always use `Process` with an explicit arguments array.
4. **Treat repository `.git/config` as untrusted input.** Specifically:
   - Do not read `core.hooksPath` and execute scripts found there.
   - Do not honour `core.fsmonitor` values that point to executables in the repository.
   - Do not execute `filter.*`, `diff.*`, or `merge.*` driver commands sourced from repository config without user consent.
   - Only `user.*`, `branch.*`, `remote.*`, and `commit.*` values are read for display purposes.
5. Prefer HTTPS clone first; SSH later.
6. Signing delegated to Git/GPG. Do not reimplement cryptographic operations.

---

## macOS Distribution Design

The product is macOS-only.

### Direct Distribution (Recommended)

Best for early development and likely best for public release too.

- Developer ID signing
- Notarization
- Sparkle updater optional (see open questions in PLAN.md)
- Fewer sandbox problems

### Mac App Store

Not recommended early.

Problems:

- Sandbox file access restrictions on arbitrary repository paths
- External Git binary access blocked without entitlement
- GPG/pinentry integration difficult under sandbox
- Repository filesystem permissions

---

## Locked Decisions

1. Target platform: macOS 14+ only.
2. Product direction: native GitHub Desktop-like workflow, safe for possible public release.
3. MVP: local Git first; GitHub login is V1.
4. Staging: whole-file staging in MVP.
5. Git binary: system/Homebrew Git in MVP.
6. Signing: support both GPG and SSH signing through Git config.
7. UI: AppKit-first.
8. Detached HEAD: always surface explicitly; never show a blank branch field.
9. Ignored files: not surfaced in the changed files list; noted in empty states.

---

## Remaining Open Questions

1. App name.
2. Minimum macOS version (locked at 14.0 — reopen only if distribution data demands otherwise).
3. Whether to use pure AppKit MVC or MVVM with Observation (locked to MVVM + Observation — reopen only if macOS target is lowered).
4. Whether to include a simple commit history in MVP.
5. Whether to support only GitHub remotes initially or any Git remote.
6. Whether direct public release should use Sparkle auto-update.
