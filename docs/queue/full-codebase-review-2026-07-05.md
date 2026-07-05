# Full Codebase Review: Bugs, Correctness Risks, and Performance Issues

**Scope:** Entire `Sources/GimMac/` tree (228 Swift files) — Infrastructure/Git, Infrastructure/Persistence,
Infrastructure/Logging, Infrastructure/Platform, Application, Presentation/Shell, Presentation/Features
(Changes, History, Diff, Conflicts, Branches, Stash, Repository, RepositorySettings, Onboarding,
Settings), Presentation/Toolbar, Presentation/DesignSystem, App.

**Method:** Eight parallel review agents, each covering a subsystem, cross-verified against source with
direct file reads (not guessed). One agent flagged a credential-logging issue as security-relevant and
auto-spawned a separate fix session (`task_2896b170`) — review before acting on it, it was not
explicitly requested.

**Status:** Blocker items resolved; major/minor items remain to be triaged into individual fix tickets.

---

## Review Summary

| Severity | Count |
|---|---|
| Blocker | 0 |
| Major | 24 |
| Minor | 20 |

---

## Major

### Git layer

- **Missing `--` separator before ref/branch/tag arguments** — `GitBranchOperator.swift:19,40,45,52,76,83`,
  `GitMergeService.swift`, `GitUpdateFromDefaultService.swift`, `GitRebaseService.swift:13`,
  `GitTagProvider.swift:14-15`. A branch or tag literally named `-D`, `-f`, or `--force` is parsed by git
  as a flag instead of a ref. Fix: insert `--` before all user-controlled ref/name arguments.
- **Cherry-pick aborts on mere task cancellation** — `GitCherryPickProvider.swift:18-25` catches
  `CancellationError` alongside real errors and unconditionally runs `cherry-pick --abort`, destroying
  legitimate in-progress state if the user simply navigates away.
- **Squash has no abort-on-failure cleanup** — `GitSquashProvider.swift:73`, unlike the sibling
  `GitReorderProvider`. A squash conflict leaves the repo stuck mid-rebase with no recovery path.
- **Unbounded `git log`** — `GitHistoryProvider.swift:12-24` loads the entire history into memory when
  `maxCount == nil`.
- **No SIGKILL escalation on cancel** — `ProcessGitCommandRunner.swift:92-95` only sends SIGTERM;
  combined with long timeouts elsewhere (e.g. a 3600s mergetool timeout), a hung subprocess can outlive
  user-initiated cancellation.

### Persistence

- **Concurrent Core Data writes can race** — `CoreDataRepositoryPersistence.swift:202-228`. Each
  `performRead`/`performWrite` vends a fresh background context with the default merge policy (not the
  `.mergeByPropertyObjectTrumpMergePolicyType` configured only on the unused `viewContext`). Two rapid
  repository-switch saves can both pass the fetch-or-create check before either commits, producing a
  uniqueness-constraint save error surfaced only as a generic string.
- **Per-line file handle churn in logger** — `GimMacLogger.swift:233-249`. Every log line opens, seeks,
  writes, and closes a fresh `FileHandle`; bursts of git activity back up the logging queue.
- **Log rotation does a full read+rewrite** — `GimMacLogger.swift:260-272`, synchronously, every 250
  appended entries.

### RepositoryStore / Changes / Diff

- **No reentrancy guard on destructive operations** — `RepositoryStoreViewModel+Discard.swift:7-30`,
  `+Ignore.swift:20-29`, `+Stash.swift:46-55` (unlike commit/apply-stash/sync, which do guard). A
  double-click on "Discard All Changes" can fire two concurrent destructive git operations on the same
  working tree.
- **Diff cache-hit path skips the request-identity guard** — `DiffHandler.swift:48-52`. Currently inert
  (no `await` before the cache check), but one future edit away from a stale-diff bug; inconsistent with
  every other write path in the same function.
- **Two uncoordinated callers of `loadDiff`** — `RepositoryStoreViewModel+Repository.swift:280` vs
  `+FileActions.swift:27-35`. `refreshRepositoryScreenData` calls `loadDiff` directly without going
  through the cancellable `changedFileDiffTask`, so a file click during a post-commit/stash/sync refresh
  can race and briefly show the wrong diff.
- **`filteredFiles` recomputed twice per render** — `Sidebar.swift:44-52,177,183`, an uncached O(n) scan
  evaluated once for the count and again for the list on every re-render.
- **Destructive-action sheets swallow failures and dismiss anyway** —
  `ReorderCommitsSheet.swift:70-77`, `SquashCommitsSheet.swift:47-53`, `ResetToCommitSheet.swift:48-54`,
  `CreateBranchFromCommitSheet.swift:49-55`, `CreateTagSheet.swift:52-59`. The sheet closes unconditionally
  after `onConfirm`, even when the underlying git operation fails; the user sees an apparent success and
  must separately notice `errorMessage`.
- **No destructive-action warning banner** — `ReorderCommitsSheet.swift`, `SquashCommitsSheet.swift`,
  unlike `ResetToCommitSheet`, which does show one for its history-rewriting hard-reset path.

### Shell / windows

- **Re-entrant tab-switch animation race** — `RepositoryContentView.swift:76-172` (`showTab`).
  `currentTab` is set synchronously before the animation runs, with no in-flight guard; rapid
  Cmd+1/Cmd+2 races two `NSAnimationContext` groups and can leave panes mis-hidden or mis-offset.
- **Settings banner auto-dismiss silently cancelled and never rescheduled** —
  `RepositorySettingsViewController.swift:160-188` (`syncBanner`). Any unrelated observed field change
  cancels the pending dismiss timer without rescheduling it, so the banner can stick indefinitely if the
  user types elsewhere in the window.
- **Create-repository sheet reports success before the operation runs** —
  `CreateRepositorySheet.swift:175-192`. The sheet dismisses with a success state before `onCreate`
  (the actual `git init`) is invoked or awaited; a failed creation is silently swallowed from the user's
  perspective.
- **`RepositorySettingsWindowController.onDismiss` is never invoked** — wired in
  `AppDelegate.swift:236-239` but no call site exists in `RepositorySettingsViewModel.swift`/
  `RepositorySettingsViewController.swift`. Closing the window via the titlebar (not an in-view action)
  leaks the window/controller/view-model indefinitely.
- **Dock reopen always rebuilds the main window from scratch** — `AppDelegate.swift:128-149`
  (`ensureMainWindowVisible`). Reopening after hiding the main window discards split position, scroll
  offsets, and selected tab/section even though the previous controller was still alive.

### Branches / toolbar

- **Unguarded concurrent sheet presentation** — `BranchDialogPresenter.swift:42-45`, three independent
  call sites (toolbar, menu, controller) resolve to the same host window with no serialization; near-
  simultaneous triggers can corrupt the sheet stack or silently drop a dialog.
- **New 60s timer created on every re-render** — `PushToolbarCard.swift:15`. A `Timer.publish` is stored
  on a SwiftUI `View` struct instead of a shared/owned clock.
- **Branch loads not cancelled on rapid repo switch** — `BranchToolbarButton.swift:69-84` +
  `BranchesViewModel.swift:121-141`. A generation counter discards stale *results*, but the underlying git
  subprocess for `loadBranches()` keeps running, leaving orphaned processes on fast switching.
- **Branch delete does not stop on partial failure** — `BranchesViewModel.swift:113-119`. Local and
  remote deletes are two independent, unawaited `Task{}` blocks; the remote delete proceeds even if the
  local delete failed.
- **Observation re-armed on every popover reappearance** — `BranchesViewController.swift:47-51,153-171`
  (`observe()`), with no guard against being called again on each `viewDidAppear`, stacking redundant
  `withObservationTracking` chains.

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
- `CreateRepositorySheet.swift:186` — dead `isWorking = false`; the spinner path is unreachable since
  `isWorking` is never set true.
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
