# Data Layer Audit: Bugs, Performance Issues, and Crash Risks

**Scope:** `Sources/GimMac/Data/` after the Data-layer file split/refactor.

**Status:** Re-triaged against the current split file structure.

---

## Current File Map

The old monolithic `GitServices.swift` findings now map to focused provider/service files:

| Area | Current file(s) |
|---|---|
| Git process execution | `ProcessGitClient.swift`, `ProcessGitCommandRunner.swift`, `GitCommandRunning.swift` |
| Commits | `GitCommitProvider.swift` |
| Squash / reorder | `GitSquashProvider.swift`, `GitReorderProvider.swift` |
| Diff rendering | `GitDiffProvider.swift`, `GitDiffProvider+Image.swift`, `GitDiffProvider+Parsing.swift`, `GitDiffProvider+Submodule.swift` |
| Repository screen snapshot data | `LiveRepositoryScreenDataRepository.swift` |
| Settings | `UserDefaultsAppSettingsStore.swift`, `UserDefaultsAppSettingsStore+Keys.swift`, `UserDefaultsAppSettingsStore+Properties.swift` |
| Repository creation / scaffolding | `GitRepositoryCreationService.swift`, `RepositoryCreationOrchestrator.swift`, `FileRepositoryScaffolding.swift` |
| Conflicts / merge tools | `GitConflictService.swift`, `GitMergeService.swift`, `GitRebaseService.swift` |
| Parsers | `GitStatusParser.swift`, `GitLogParser.swift`, `Parsers/BranchForEachRefParser.swift`, `Vendored/SwiftyDiff/SwiftyDiffUnifiedParser.swift` |

---

## Review Summary

Severity distribution:

| Severity | Count |
|---|---|
| Blocker | 4 |
| Major | 4 |
| Minor | 5 |

The most urgent theme remains **Git execution reliability and safety**: the process runner still serializes all Git commands, interactive rebase providers still build shell-interpreted editor commands, error classification still depends on localized Git stderr, and force-push detection still compares the wrong ref.

Two stale findings from the pre-split audit were removed:

- `UserDefaults` storage for `UncommittedChangesStrategy` is no longer a mismatch because `UncommittedChangesStrategy` is `String`-backed.
- The old `GitServices.swift` locations no longer exist; all findings below point at the current split files.

---

## Blockers

### Issue 1 — Serial Git command queue bottlenecks all concurrent work

**File:** `Sources/GimMac/Data/ProcessGitCommandRunner.swift:7`, `:28-31`, `:76-81`

**Symbol:** `ProcessGitCommandRunner.queue`

**Problem:** The runner uses a single serial `DispatchQueue` and blocks it with `process.waitUntilExit()`. Every Git command therefore runs one-at-a-time globally. Long operations such as clone, merge tool, large diffs, or blob reads block unrelated status/history/branch commands.

**Why it matters:** Severe performance regression; repository refresh, history loading, status, branch reads, and other commands cannot run concurrently.

**Suggested fix:** Remove the global serial execution bottleneck. Run each `Process` from an isolated async task or concurrent execution context, keep cancellation wired through `inFlight`, and drain pipes safely while the process runs.

### Issue 2 — Shell injection in interactive rebase/squash/reorder

**Files:** `Sources/GimMac/Data/GitSquashProvider.swift:65-73`, `Sources/GimMac/Data/GitReorderProvider.swift:69-75`

**Symbols:** `GitSquashProvider.squash`, `GitReorderProvider.reorder`

**Problem:** Temporary file paths are interpolated into `GIT_SEQUENCE_EDITOR` / `GIT_EDITOR` shell strings:

```swift
"GIT_SEQUENCE_EDITOR": "cat \"\(todoPath)\" >"
```

Git invokes these editor commands through shell parsing so quotes, `$`, backticks, or other shell syntax in the path can mis-parse.

**Why it matters:** Command failure or, in adversarial conditions, arbitrary shell execution via a manipulated temporary path.

**Suggested fix:** Write a small wrapper script to a controlled temp path and invoke that script by absolute path, or implement an editor helper that avoids shell interpolation entirely.

### Issue 3 — `merge-base --is-ancestor remoteName HEAD` is wrong

**File:** `Sources/GimMac/Data/LiveRepositoryScreenDataRepository.swift:132-138`

**Symbol:** `readForcePushNeeded(remoteName:in:)`

**Problem:** The code passes the remote name, such as `origin`, to `merge-base --is-ancestor`. A bare remote name is not a commit object unless a coincidental ref resolves.

**Why it matters:** Force-push detection is unreliable; users may be offered or denied force-push incorrectly.

**Suggested fix:** Compare against the resolved upstream ref, such as `@{upstream}` or the value from `BranchUpstreamProviding`, not the bare remote name.

### Issue 4 — stderr locale breaks error classification

**Files:** `Sources/GimMac/Data/GitAppErrorMapper.swift:10-30`, `Sources/GimMac/Data/ProcessGitCommandRunner.swift:110-117`

**Symbols:** `GitAppErrorMapper.map(command:exitCode:stdout:stderr:)`, `ProcessGitCommandRunner.gitEnvironment()`

**Problem:** Error detection depends on English substrings such as `not a git repository` and `permission denied`. `gitEnvironment()` copies the user's full environment and does not force a stable locale, so non-English `LANG` / `LC_*` values can make the checks fail.

**Why it matters:** Typed errors stop working for users with non-English locales; the app falls back to raw `.commandFailed` output instead of helpful app-specific errors.

**Suggested fix:** Set `LANG=C` and `LC_ALL=C` in `gitEnvironment()` before running Git, then keep mapper fixtures for the canonical English stderr forms.

---

## Major

### Issue 5 — Binary image blobs read entirely into memory

**File:** `Sources/GimMac/Data/GitDiffProvider+Image.swift:4-11`

**Symbols:** `workingDirectoryImage(in:for:)`, `blobImage(in:for:at:)`

**Problem:** Both methods load the full file/blob into memory and then base64-encode it. There is no size cap.

**Why it matters:** A large image or binary blob can cause memory pressure and block the async task.

**Suggested fix:** Add a size ceiling before loading/encoding, for example 10 MB, and return an oversized-image placeholder or binary fallback.

### Issue 6 — Pipe deadlock risk on large output

**File:** `Sources/GimMac/Data/ProcessGitCommandRunner.swift:28-34`, `:76-82`

**Symbol:** `ProcessGitCommandRunner.execute`, `ProcessGitCommandRunner.executeData`

**Problem:** `execute` waits for the process to exit before draining either pipe. `executeData` drains stdout before waiting, but stderr is not drained concurrently. If either pipe fills, the subprocess can block before exit.

**Why it matters:** Git commands that produce large stdout/stderr can hang indefinitely.

**Suggested fix:** Drain stdout and stderr concurrently while the process is running, or move to async file-handle reads and wait only after both streams are being consumed.

### Issue 7 — `GitCommitProvider` commits whatever got staged, silently dropping failures

**File:** `Sources/GimMac/Data/GitCommitProvider.swift:30-49`, `:64`

**Symbol:** `GitCommitProvider.commit(in:paths:summary:description:options:)`

**Problem:** The staging loop catches each path's staging failure, logs it, and continues. The final commit runs with only the successfully staged subset.

**Why it matters:** The user thinks all selected files were committed, but some may be silently left out.

**Suggested fix:** Collect failed paths and throw a typed error before `git commit` when any selected path could not be staged.

### Issue 8 — Unborn-head detection treats any `rev-parse` failure as unborn

**File:** `Sources/GimMac/Data/GitDiffProvider+Parsing.swift:4-10`

**Symbol:** `GitDiffProvider.isUnbornHead(client:repositoryURL:)`

**Problem:** `result == nil` is true for timeout, permission errors, corrupt repositories, or Git executable failures, not only for a repository with no commits.

**Why it matters:** The caller can incorrectly present a working-tree file as a pure addition via `git diff --no-index /dev/null` when HEAD failed for another reason.

**Suggested fix:** Check the specific stderr/exit status for the missing-HEAD case and propagate other failures.

---

## Minor

### Issue 9 — Force unwraps in squash/reorder providers

**Files:** `Sources/GimMac/Data/GitSquashProvider.swift:16`, `Sources/GimMac/Data/GitReorderProvider.swift:73-75`

**Symbols:** `GitSquashProvider.squash`, `GitReorderProvider.reorder`

**Problem:** Force unwraps survive because of preceding guards/conditions, but the safety is implicit and fragile to future edits.

**Why it matters:** A later precondition change can turn these into crash sites.

**Suggested fix:** Use explicit `guard let` / `if let` bindings and avoid `parentSHA!` in the ternary branch.

### Issue 10 — `RepositoryCreationOrchestrator` always writes `.gitattributes`

**File:** `Sources/GimMac/Data/RepositoryCreationOrchestrator.swift:84-86`

**Symbol:** `RepositoryCreationOrchestrator.createRepository(...)`

**Problem:** `.gitattributes` is written unconditionally, so `didScaffoldAnyFile` becomes true even when the user requested no README, license, or gitignore. If initial commit is enabled, the commit contains only `.gitattributes`.

**Why it matters:** Surprising behavior; it differs from a user's expectation of no scaffold files.

**Suggested fix:** Treat `.gitattributes` as optional scaffolding or document why it is mandatory and expose that behavior in the UI.

### Issue 11 — `GitStatusParser` assumes untracked/ignored paths have no leading spaces

**File:** `Sources/GimMac/Data/GitStatusParser.swift:35-40`

**Symbol:** `GitStatusParser.parse(_:)`

**Problem:** `String(token.dropFirst(2))` assumes `? <path>` and `! <path>` always have exactly one separator space and that the path itself cannot begin with a space.

**Why it matters:** Edge-case paths are corrupted.

**Suggested fix:** Parse the marker and separator deliberately, preserving the path bytes after the porcelain record prefix.

### Issue 12 — `LiveRepositoryScreenDataRepository` makes three separate conflict-state git calls

**File:** `Sources/GimMac/Data/LiveRepositoryScreenDataRepository.swift:110-123`

**Symbol:** `readConflictState(in:)`

**Problem:** `MERGE_HEAD`, `REBASE_HEAD`, and `CHERRY_PICK_HEAD` are checked sequentially even though the method returns the first matching state.

**Why it matters:** Snapshot loading does unnecessary work, especially on slow filesystems.

**Suggested fix:** Short-circuit after each successful state check, or combine the checks into one Git/filesystem operation.

### Issue 13 — Merge tool timeout is extremely long

**File:** `Sources/GimMac/Data/GitConflictService.swift:177-182`

**Symbol:** `GitConflictService.openInMergeTool(_:in:)`

**Problem:** `git mergetool` is allowed to run for 3600 seconds.

**Why it matters:** If the tool crashes, hangs, or is left open, the app can appear stuck for an hour unless higher-level UI cancellation is clear and reliable.

**Suggested fix:** Consider a shorter timeout with visible progress/cancellation, or explicitly document why the long timeout is required for interactive tools.

---

## Performance Concerns

- **Serial Git queue (Issue 1)** is the dominant performance bottleneck.
- **Pipe draining (Issue 6)** can hang long-running Git commands and should be fixed with the runner changes.
- **Loading full image blobs into memory (Issue 5)** can spike memory on large assets.
- `LiveRepositoryScreenDataRepository.loadSnapshot` still launches several concurrent tasks per refresh; callers must continue to ignore stale results when the selected repository changes.
- `BundledRepositoryTemplateCatalog.licenses()` should stay cached after first load; the first read still performs file I/O from an async API.

---

## Crash / Data-Loss Risks

- Shell-interpreted editor commands in squash/reorder (Issue 2).
- Force unwraps in squash/reorder (Issue 9).
- Silent partial commits (Issue 7) are a data-integrity bug.
- `CoreDataRepositoryPersistence` still uses `assertionFailure` on persistent-store load failure at `Sources/GimMac/Data/CoreDataRepositoryPersistence.swift:38-41`; debug builds can crash on a corrupt store.

---

## Triage Notes

- Fix the process runner first; it is both a blocker and a prerequisite for reliable large-output handling.
- Keep Git command arguments array-based. Do not introduce shell command strings while fixing interactive rebase; if Git requires editor environment variables, use controlled helper scripts with safely generated paths.
- Add regression tests for each blocker and major issue at fix time.
- After fixing a provider/service, reindex the touched file so symbol navigation points at the updated split structure.
