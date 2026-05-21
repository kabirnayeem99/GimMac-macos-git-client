# GimMac — Architecture Improvement Points

Audit comparing current implementation against `gimmac-ops.md` spec.

---

## MUST Fix — Correctness and Safety Violations

**#1 — Synchronous file I/O on `@MainActor`**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` (~line 461)

`String(contentsOf:)` is synchronous I/O called from a `@MainActor` function (`loadUntrackedFileDiff`). On a repo with a large untracked binary or text file this will hang the UI thread. Must be moved off-thread via `Task.detached` or pushed into `DiffProviding`.

---

**#2 — `ChangedFile.id` is wrong — rename collision**
File: `Sources/GimMac/Domain/ChangedFile.swift`

Current:
```swift
var id: String { path }
```

Spec requires:
```swift
var id: String { "\(status.rawValue):\(oldPath ?? path)" }
```

A rename produces two `ChangedFile` entries with the same `path`. Using only `path` as the identifier causes SwiftUI diffing collisions and silent list corruption.

---

**#3 — `ChangedFile` missing `isStaged` and `hasConflict` fields**
File: `Sources/GimMac/Domain/ChangedFile.swift`

The spec defines both fields. Without `isStaged`, the staging workflow has no model-level distinction between index state and worktree state. Without `hasConflict`, merge conflict handling is stringly-typed. Porcelain v1 format (`XY`) provides both — first char = index state, second char = worktree state.

---

**#4 — `RepositoryScreenDataProviding` protocol lives in the ViewModel file**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` (~line 86)

Domain protocols must live in `Sources/GimMac/Domain/`. A protocol defined inside a Presentation file cannot be tested or reused without importing the ViewModel.

---

**#5 — `LiveRepositoryScreenDataRepository` lives in the ViewModel file**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` (~line 92)

This is a full Data layer class (reads git, merges results, derives state) embedded in a Presentation file. It must move to `Sources/GimMac/Data/`.

---

## SHOULD Fix — Architecture Violations

**#6 — `LocalGitRepositoryInspector` has a default concrete init parameter**
File: `Sources/GimMac/Data/LocalGitRepositoryInspector.swift`

```swift
init(gitClient: GitClientProtocol = ProcessGitClient()) { ... }
```

This default allows any callsite to silently bypass dependency injection and construct an uninstrumented, unlogged `ProcessGitClient`. All construction must happen at the composition root. Remove the default value.

---

**#7 — Domain value types living in the ViewModel file**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift`

`GitUserProfile`, `RepositoryScreenSnapshot`, and `RepositoryPrimaryAction` (including its `label`, `badge`, `subtitle` computed properties) are defined in the ViewModel file. These are domain/value objects and belong in `Sources/GimMac/Domain/`. `RepositoryPrimaryAction` labels are presentation-facing — if kept in the model they go to Domain; if purely view-formatting they should be a separate Presentation-layer formatter (like `RepositoryBranchDisplayFormatter`).

---

**#8 — `@unchecked Sendable` on multiple Data classes**
Files: `GitHistoryProvider`, `GitStatusProvider`, `GitCommitProvider` in `GitServices.swift`; `ProcessGitClient.swift`

All use `@unchecked Sendable`, which opts out of Swift concurrency checking entirely. These classes hold a single immutable `let` property so they are genuinely `Sendable`. The annotation should be changed from `@unchecked Sendable` to `Sendable`.

---

**#9 — `RepositoryStoreViewModel` is 487 lines with too many responsibilities**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift`

Current responsibilities packed into one ViewModel:
- Repository selection and persistence
- Diff loading
- Commit form state (`commitSummary`, `commitDescription`)
- Changed-file check state (`checkedChangedFilePaths`)
- History tab selection (`selectedHistoryCommitIndex`)
- Primary action derivation
- User profile loading
- Saved repositories list

The commit form state (`commitSummary`, `commitDescription`, `isCommitting`, `canCommitChanges`, `commitChanges()`) should be a separate `CommitFormViewModel`. History selection state is another natural split. The data-source tracing rule from the spec becomes unenforceable at this size.

---

## COULD Fix — Quality and Performance Improvements

**#10 — `ProcessGitCommandRunner` uses `DispatchQueue` + `CheckedContinuation`**
File: `Sources/GimMac/Data/ProcessGitClient.swift`

The actor uses `DispatchQueue.global(qos: .userInitiated)` to bridge `Process.waitUntilExit()` into async. This is a correct pattern for blocking APIs, but a named private `DispatchQueue(label: "com.gimmac.git-runner", qos: .userInitiated)` would be more explicit and easier to profile with Instruments than `.global`.

---

**#11 — `LiveRepositoryScreenDataRepository.loadSnapshot` silently swallows all errors**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` (~line 118)

```swift
let changedFiles = (try? await changedFilesTask) ?? []
```

Every failure path returns `[]` or mock data. If `statusProvider.fetchStatus` throws `GitAppError.notARepository`, the ViewModel never surfaces this to the user — it shows an empty list instead. Errors should propagate so `errorMessage` can be set.

---

**#12 — `CoreDataRepositoryPersistence` is coupled to `GitClientProtocol`**
File: `Sources/GimMac/Data/CoreDataRepositoryPersistence.swift`

The persistence layer calls `git rev-parse HEAD` internally to record `gitIdentifier`. This couples storage to the Git process. A cleaner boundary: accept `headHash: String?` as a parameter in `saveOrUpdateRepository` and let the caller (ViewModel or AppDelegate) supply the hash it already has from `inspectRepository`.

---

**#13 — `GitStatusParser` ignores the worktree column**
File: `Sources/GimMac/Data/GitStatusParser.swift`

Porcelain v1 format is `XY filename`. The parser reads only `statusString.first` (the index column `X`) and ignores the second character (the worktree column `Y`). Once `isStaged` is added to `ChangedFile` (see #3), this parser must read both columns: `X` = staged/index state, `Y` = unstaged/worktree state.

---

**#14 — `Infrastructure/` folder is empty**
Path: `Sources/GimMac/Infrastructure/`

The folder exists but contains nothing. Either use it for cross-cutting concerns (logging, file watching, Keychain access) or remove it to avoid confusion about where infrastructure code lives.

---

**#15 — `git rev-list` command deviates from spec without documentation**
File: `Sources/GimMac/Presentation/ViewModels/RepositoryStoreViewModel.swift` (~line 150)

The spec documents two separate commands for ahead/behind counts. The implementation uses one combined command (`--left-right --count @{upstream}...HEAD`), which is more efficient. The deviation is acceptable and preferable, but `gimmac-ops.md` should be updated to document this optimization so future contributors do not revert it.
