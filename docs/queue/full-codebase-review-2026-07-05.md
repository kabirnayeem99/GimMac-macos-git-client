# Full Codebase Review: Bugs, Correctness Risks, and Performance Issues

**Scope:** Entire `Sources/GimMac/` tree (228 Swift files) — Infrastructure/Git, Infrastructure/Persistence,
Infrastructure/Logging, Infrastructure/Platform, Application, Presentation/Shell, Presentation/Features
(Changes, History, Diff, Conflicts, Branches, Stash, Repository, RepositorySettings, Onboarding,
Settings), Presentation/Toolbar, Presentation/DesignSystem, App.

**Method:** Eight parallel review agents, each covering a subsystem, cross-verified against source with
direct file reads (not guessed). One agent flagged a credential-logging issue as security-relevant and
auto-spawned a separate fix session (`task_2896b170`) — review before acting on it, it was not
explicitly requested.

**Status:** Blocker and resolved major/minor items removed. Remaining issues below need individual fix tickets.

---

## Review Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 3 |
| Minor | 17 |

---

## Major

### Persistence

- **Log rotation does a full read+rewrite** — `GimMacLogger.swift:260-272`, synchronously, every 250
  appended entries.

### RepositoryStore / Changes / Diff

- **`filteredFiles` recomputed twice per render** — `Sidebar.swift:44-52,177,183`, an uncached O(n) scan
  evaluated once for the count and again for the list on every re-render.

### Shell / windows

- **`RepositorySettingsWindowController.onDismiss` is never invoked** — wired in
  `AppDelegate.swift:236-239` but no call site exists in `RepositorySettingsViewModel.swift`/
  `RepositorySettingsViewController.swift`. Closing the window via the titlebar (not an in-view action)
  leaks the window/controller/view-model indefinitely. Partially addressed: `onClose` now nils the
  window controller reference, but `onDismiss` itself is still not triggered.

---

## Minor

- `GitCommandBuilder.swift:8-10` — dead `--porcelain=v1` builder incompatible with the v2-only parser;
  landmine if ever wired up.
- `GitRemoteService.swift:13,30` — same missing-`--` pattern as the branch/tag ops above, lower risk
  since inputs are largely app-controlled.
- `GitLogParser.swift:34` — commit body never populated despite model support (`%b` not requested).
- `CoreDataRepositoryPersistence.swift:54-55` — `viewContext` merge policy configured but the context is
  never used anywhere in the codebase; dead, misleading configuration.
- `CoreDataRepositoryPersistence.swift:179-181` — opaque untyped `NSError` surfaces to the user instead
  of a typed `GitAppError` case.
- `CoreDataRepositoryPersistence.swift:39-52` — store-recreate-on-corruption swallows the second load
  failure silently; this layer has no logging dependency at all.
- `CoreDataRepositoryPersistence+Mapping.swift:18` — synchronous `fileExists` stat() per row on every
  fetch, no caching.
- `RepositoryStoreViewModel+Repository.swift:158-164,376` — nil-generation refresh path can race
  out-of-order; stash-fetch errors are swallowed via `try?`.
- `DiffLineRow.swift:111-121` — `Array(line.text)` reconverted on every render for every visible row, no
  memoization.
- `ChangedFilesListView.swift:56` — new `[ID]` array allocated per render solely for an animation trigger;
  linear `first(where:)` scans for selection (lines 16-25).
- `DiffHandler.swift:95-97` — missing `Task.isCancelled` check present in the equivalent
  `HistoryHandler.loadDiff`; currently inert but inconsistent.
- `AboutWindowFactory.swift:15,41,45,49,55` — hardcoded dark colors ignore the app's Light/Dark theme
  setting.
- `AboutWindowFactory.swift:47` — hardcoded `"GimMac version 0.1"` instead of reading the bundle version.
- No localization (`String(localized:)`/`NSLocalizedString`) found across Onboarding, Branches, Settings
  panes, About, or the main menu — all user-facing copy is raw English literals.
- `BranchDialogPresenter.swift` — inconsistent `[weak self]`/`[weak viewModel]` capture style across
  similar closures; `Create/Delete/RenameBranchWindowController` lack a `windowWillClose` cancellation
  hook (unlike `CompareBranchWindowController`, which has one).
- `StashManagementViewModel.swift` — `repositoryURL` captured once at init with no staleness guard,
  unlike `BranchesViewModel`'s generation-counter pattern.
- `AppKitMotion.swift:98-114` (`scheduleAutoDismiss`) — the returned `DispatchWorkItem` is never
  auto-cancelled on controller deinit; harmless no-op fire since the view capture is weak, but a wasted
  pending timer.
- `AppDelegate.swift:24` (`onboardingCompletedKey`) — bypasses `UserDefaultsAppSettingsStore` entirely
  and uses a raw key missing the `.settings.` namespace segment every other key shares.

---

## Confirmed clean (checked, not bugs)

- `ProcessGitCommandRunner` correctly drains stdout/stderr concurrently via `DispatchGroup`, avoiding the
  classic full-pipe-buffer deadlock.
- `gitEnvironment()` pins `LANG=C`/`LC_ALL=C`, avoiding locale-dependent stderr matching problems.
- `GitCommandScheduler`/`ProcessGitClient` correctly race the runner against a `Task.sleep` timeout and
  cancel on timeout/cancellation.
- `GitStatusParser` correctly uses `--porcelain=v2 -z` and handles renames/copies/submodules/unmerged
  distinctly.
- `DiffHandler.loadDiff` and `HistoryHandler.loadDiff` (not `loadFiles`) correctly guard stale writes with
  request-ID/selection checks.
- `AsyncDecodedImageDiffPreview` correctly keys its task to content identity via `.task(id:)`.
- No retain cycles found across AppKit delegate/closure captures in Shell, Branches, or Settings code.
- `UserDefaultsAppSettingsStore` clamping (`selectedTabSize`) and registered-defaults consistency are
  correct; no threading violations or leaked observers found in Settings panes.
