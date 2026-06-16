# Bugs

This queue was checked against the current codebase on 2026-06-16. Keep fixes small and reviewable.
Prefer UI-only changes unless the notes below call out a model or service gap.

## 1. Changes split and History split do not share the same radius/style

Original report: "The radius and style of changes split and history split not same."

Current code context:

- Changes uses `ChangesSplitViewController` with two panes: sidebar and content.
  See `Sources/GimMac/Presentation/Shell/SplitViews/ChangesSplitViewController.swift`.
- History uses `HistorySplitViewController` with three panes: commit sidebar, changed-files column,
  and diff pane.
  See `Sources/GimMac/Presentation/Features/History/Screens/HistorySplitViewController.swift`.
- Both inherit `RepositorySplitViewController`, which only provides transparent SwiftUI hosting. It
  does not define shared split styling, content insets, rounded container treatment, or divider
  styling.
- `RepositoryContentViewController` hosts both controllers and switches tabs while preserving divider
  state. Styling that must be identical across tabs probably belongs in the shared base class or in
  the hosted pane root views, not in the tab switcher.

Plan:

- Compare visible backgrounds, pane corner radius, divider material, and content padding between the
  Changes and History tabs.
- Move any common native split styling into `RepositorySplitViewController` if it is truly shared.
- Keep pane-specific width constraints local to the tab controllers.
- Avoid nested cards or decorative containers; this is an AppKit-first productivity surface.

Acceptance criteria:

- Changes and History panes use consistent corner radius, material/background, and divider styling.
- Switching between tabs does not visually jump due to different outer insets or rounded clipping.
- Existing split divider persistence and first-responder restoration still work.

Suggested verification:

- Manual visual check in light and dark mode.
- `xcodebuild -project GimMac.xcodeproj -scheme GimMac -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build`

## 2. Squash failure with uncommitted changes appears under CommitBox instead of as an alert

Original report: "If there're uncommited changes and user try to squash, instead of showing a error
dialog (alert with only OK), it shows the error under CommitBox,which is wrong."

Current code context:

- `RepositoryStoreViewModel.squashSelectedCommits(message:)` catches failures and writes
  `errorMessage = error.localizedDescription`.
  See `Sources/GimMac/Presentation/Shell/RepositoryStore/RepositoryStoreViewModel+History.swift`.
- `CommitInlineStatusSection` displays `viewModel.errorMessage` under `CommitBox`, so history
  operation failures leak into the commit form.
  See `Sources/GimMac/Presentation/Features/Changes/Components/CommitInlineStatusSection.swift`.
- `CommitHistorySidebar` presents the squash sheet and awaits `squashSelectedCommits`, but it does
  not present an operation-scoped failure alert.
  See `Sources/GimMac/Presentation/Features/History/Columns/CommitHistorySidebar.swift`.
- Other AppKit-backed feature areas already use `NSAlert` for operation failures, for example branch
  and stash management controllers.

Plan:

- Do not route history edit failures through the commit inline status.
- Add an operation-scoped history error path, likely a `historyErrorMessage` or a one-shot alert state
  owned by the history UI.
- For squash blocked by uncommitted changes, show a modal/sheet alert with a single OK button and a
  clear message.
- Keep commit failures under `CommitBox`; only non-commit operations should move away from
  `CommitInlineStatusSection`.

Acceptance criteria:

- With uncommitted changes present, attempting Squash from History shows an alert/sheet with only OK.
- The same failure does not appear under CommitBox.
- Commit failures still appear inline under CommitBox.
- The squash sheet either stays open for correction or dismisses consistently with the selected alert
  behavior; choose one and keep it stable.

Suggested verification:

- Add or update a focused `RepositoryStoreViewModel` test if error state is split.
- Manual test with a repository containing two selected commits and a dirty working tree.

## 3. Selecting the already-open repository reloads it

Original report: "If we try to change the repository, and select the same repository again, nothing
should happen. Now it tries to reload."

Status: Implementation patch added on 2026-06-16. Verification is blocked in this sandbox by
`swift-plugin-server` failing to load `ObservationMacros.ObservableMacro`; rerun the focused XCTest
target in a normal Xcode environment before closing.

Current code context:

- Toolbar recent-repository rows call `selectRepositoryAction(repository.id)` even when the row is
  already current.
  See `Sources/GimMac/Presentation/Toolbar/RepositoryPicker/RepositoryMenuButton.swift`.
- The full repository picker dialog also calls `selectRepositoryAction(repository.id)` for the
  current row.
  See `Sources/GimMac/Presentation/Toolbar/RepositoryPicker/RepositoryPickerDialog.swift`.
- `selectPersistedRepository(id:)` always asks persistence for the selected repository, then calls
  `selectRepository(at:)`.
  See `Sources/GimMac/Presentation/Shell/RepositoryStore/RepositoryStoreViewModel+Repository.swift`.
- `selectRepository(at:)` always begins a new selection, resets per-repository state, inspects the
  repository, refreshes screen data, and reloads saved repositories.

Plan:

- Add an early return before selection work starts when the target URL matches the current
  `selectedRepository?.url` after resolving symlinks and standardizing both file URLs.
- Prefer the guard in `selectRepository(at:)` so every caller benefits, including menu, dialog, launch
  bootstrap, create, clone, and tests.
- Optionally disable current repository rows in the picker UI after the model guard is in place.

Acceptance criteria:

- Selecting the current repository from the toolbar menu does not clear selection, reload diffs, reset
  commit text, or flash loading state.
- Selecting the current repository from the "More Repositories" dialog is also a no-op.
- Selecting a different repository still performs the full refresh.

Suggested verification:

- Add a `RepositoryStoreViewModelTests` case that calls `selectRepository(at:)` twice with the same
  canonical URL and asserts expensive collaborators are not invoked the second time.
- Manual check that current diff selection and commit form contents remain intact.

## 4. Remove the visible "Loading diff..." indicator

Original report: "remove Loading diff indicator. Just animation should suffice."

Status: Implementation patch added on 2026-06-16. `DiffViewer` no longer shows visible loading copy or
spinner for diff loads, while keeping an accessibility loading value. Verification is blocked in this
sandbox by the same `swift-plugin-server` / Observation macro failure noted above.

Current code context:

- `DiffViewer.diffContent` renders `LoadingPlaceholder(title: "Loading diff...", minHeight: 160)`
  whenever `isLoadingDiff` or `isLoadingHistoryDiff` is true.
  See `Sources/GimMac/Presentation/Features/Diff/DiffViewer.swift`.
- The same `DiffViewer` is used by Changes and History via the `source` parameter.
- `DiffViewer` already has content identity, transition, crossfade, and motion hooks.

Plan:

- Remove the explicit loading text from the diff viewer.
- Keep a subtle transition or skeleton/blank-preserving animation so the app still feels responsive.
- Preserve accessibility: if there is no visible text, expose a non-intrusive accessibility value or
  progress state where VoiceOver users still know the diff is loading.
- Ensure the old document does not misleadingly remain interactive if the newly selected diff is still
  loading.

Acceptance criteria:

- No visible "Loading diff..." label appears in Changes or History.
- Diff loads with an unobtrusive animation and without layout shift.
- VoiceOver still has a loading cue.

Suggested verification:

- Manual test on a large diff or by temporarily slowing the diff provider.
- Check both Changes diff and History diff.

## 5. Diff snapshot loading should be async and preloaded before clicking

Original report: "The diff snapshot loading should be async, and preloaded before clicking."

Current code context:

- Changes diff loading is already async in `DiffHandler.loadDiff(in:changedFiles:)`.
- It has request-generation cancellation/stale-result protection and a cache keyed by repository,
  path, status, staging state, conflict/submodule state, file modification time, and file size.
- Untracked file reads are detached off the main actor.
- The missing part is preloading: only the selected file's diff is loaded. There is no warm-up for the
  first few changed files or likely next/previous selections.
- History file diffs are also async through `historyFileDiffTask`, but there is no cache or prefetch
  visible in `RepositoryStoreViewModel+History.swift`.

Plan:

- Add a bounded diff prefetch queue for the Changes tab after `changedFiles` syncs.
- Prefetch only small text diffs first; skip binary/image/submodule or very large files unless the
  existing provider can cheaply classify them.
- Keep prefetch cancellable on repository change, status refresh, staging change, and selected file
  change.
- Reuse `DiffHandler` cache instead of introducing a second source of truth.
- Consider a separate history diff cache only if History selection latency remains visible.

Acceptance criteria:

- The first changed file still loads automatically.
- Selecting the next few changed files is instant or near-instant after repository refresh.
- Prefetch never blocks the main actor and cancels promptly when repository or status changes.
- Cache invalidates when file modification time, size, status, staging state, conflict state, old path,
  or submodule state changes.

Suggested verification:

- Add unit coverage around cache hits, invalidation, and stale request handling.
- Manual test with 20+ changed files and rapid selection changes.

## 6. Branch selector toolbar button requires two steps for local/remote branches

Original report: "The branch selector toolbar button has 2 steps, we should on first click show the
local and remote thing. Just add a button for adding new branch, it should be enough."

Current code context:

- `BranchToolbarButton` opens a `Menu`.
- `BranchPullDownMenuContent` shows only local branches directly, capped at 12.
- Remote branches are not visible on first click; users must choose "Switch Branch..." to open the
  full branch picker popover.
- There is already a direct "New Branch..." button in the menu.

Plan:

- On first click, show both local and remote branch sections in the toolbar menu.
- Keep "New Branch..." as a direct action.
- Remove or demote "Switch Branch..." if the menu itself becomes sufficient; keep it only if search
  or full management actions still require the popover.
- Use branch type from `Branch.type` to group local and remote branches.
- Keep the list bounded so the toolbar menu is not unusable in repositories with many branches.

Acceptance criteria:

- First click on the branch toolbar item exposes local branches, remote branches, and New Branch.
- Switching to a remote branch follows the current branch operation behavior and error handling.
- Current branch remains clearly marked.
- Empty local or remote sections have useful disabled empty states.

Suggested verification:

- Manual test with a repository that has both local branches and `origin/*` remote-tracking branches.
- Check keyboard navigation through the menu.

## 7. Add last modified time to branches

Original report: "Add last time modified time in the branch."

Current code context:

- The `Branch` model already includes `BranchTip.date`.
- `GitBranchReader` fetches `%(creatordate:iso-strict)` through `git for-each-ref`.
- `BranchForEachRefParser` parses that date into `BranchTip.date`.
- `BranchCellView` currently shows branch name, tip short SHA, subject, and upstream. It does not show
  relative or absolute last modified time.

Plan:

- Surface `branch.tip.date` in branch rows, likely as relative text such as "updated 2h ago" or a
  user-settings-aware absolute date from `AppFormatters`.
- Decide whether "last modified" means tip commit date. In Git branch UI, that is usually the latest
  commit date on the branch, which is exactly the field already parsed.
- Add the same date display to the toolbar menu if space allows; otherwise keep it in the full branch
  picker rows first.
- Avoid increasing row height unless the current two-line layout cannot fit branch name, subject, and
  date cleanly.

Acceptance criteria:

- Branch rows show a last modified/updated time derived from `branch.tip.date`.
- The value updates after branch refresh.
- Remote branches show the date from their remote-tracking ref tip.
- Very long branch names and subjects still truncate cleanly.

Suggested verification:

- Unit test parser date handling if formatting logic is added outside the cell.
- Manual test with branches whose last commits have visibly different dates.

## 8. Make the app feel faster with animation and caching

Original report: "Make the app feel faster with animation and caching."

Current code context:

- Motion helpers already exist in `Sources/GimMac/Presentation/Shared/Motion`.
- Repository tab switching uses animation and preserves both split controllers.
- Diff loading has a cache for selected Changes diffs.
- Template catalog caching exists, but branch/history/diff preloading is incomplete.
- `RepositoryStoreViewModel.refreshRepositoryScreenData(for:)` loads snapshot, then may load history
  files/diff, then loads the selected changes diff, then fetches stash. Some work is sequential.

Plan:

- Treat this as a performance polish epic, not one unbounded bug.
- Start with high-impact, low-risk work:
  - avoid same-repository reloads;
  - remove visible diff loading text;
  - prefetch bounded changed-file diffs;
  - cache branch lists briefly per repository and invalidate on branch operations;
  - avoid clearing visible content until replacement content is ready where correctness allows.
- Only add deeper concurrency after measuring. Do not parallelize Git operations that must observe a
  consistent repository state unless the service contract makes that safe.
- Keep Reduce Motion behavior correct for every new animation.

Acceptance criteria:

- Common interactions feel immediate: repository menu no-op, branch menu open, changed-file selection,
  tab switch.
- New caches are bounded and invalidated by repository changes and mutating Git operations.
- No stale repository, branch, or diff data is displayed after a repository switch or refresh.
- Animations respect Reduce Motion.

Suggested verification:

- Add targeted unit tests for cache invalidation where model-owned.
- Manual smoke test: open repository, switch Changes/History, select changed files rapidly, switch
  branches, refresh status.
- Run strict CI before closing this epic because performance changes can cross presentation and
  concurrency boundaries.
