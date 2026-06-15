# Presentation Micro-Interactions Queue

## Goal

Make GimMac feel more responsive, lively, and polished through subtle native macOS motion. Motion must
communicate state, causality, progress, or continuity. It must not slow frequent Git workflows or add
decorative distraction.

The current Presentation layer has very little explicit animation: the commit co-author reveal and the
onboarding step transition are the main existing examples.

## Global Rules

- Respect Reduce Motion and provide an opacity-only or immediate alternative.
- Use 100-250 ms for normal feedback and up to 400 ms for larger spatial transitions.
- Prefer springs/snappy motion for direct manipulation and spatial changes.
- Prefer opacity and content transitions for labels, counts, loading, and status changes.
- Preserve stable list identity, selection, keyboard navigation, and AppKit responder behavior.
- Keep animations interruptible. Never delay user input until an animation completes.
- Do not animate every row during scrolling or render large diffs line by line.
- Avoid continuous ambient motion and repeated bouncing.
- Use SwiftUI animation APIs and AppKit `NSAnimationContext`/animator proxies available on macOS 14.
- Profile any motion that affects large lists, diffs, attributed strings, or split-view layout.

## Priority 1: High-Value Feedback

### Toolbar and Sync

Relevant files:

- `Presentation/Toolbar/PushToolbarCard.swift`
- `Presentation/Toolbar/SyncMenuButton.swift`
- `Presentation/Toolbar/BranchToolbarButton.swift`
- `Presentation/Toolbar/RepositoryMenuButton.swift`
- `Presentation/AppShell/MainToolbarController.swift`

Suggestions:

- Rotate or pulse the sync symbol once while fetch/pull/push starts.
- Replace operation symbols with a checkmark briefly on success.
- Animate ahead/behind numeric changes using numeric content transitions.
- Crossfade repository and branch labels when selection changes.
- Apply a restrained error symbol pulse once when an operation fails.
- Add subtle native hover/pressed feedback to custom toolbar cards.

### Commit Box

Relevant file: `Presentation/Changes/CommitBox.swift`

Suggestions:

- Preserve the existing co-author reveal and use an asymmetric fade/move transition.
- Animate validation, conflict, warning, and error messages into the layout.
- Transition the character counter color when crossing the recommended limit.
- Use symbol replacement for amend mode on/off.
- Show progress while committing without changing button geometry.
- On success, briefly show confirmation before clearing fields.
- Use a short shake only for an explicitly submitted invalid form, with a non-motion alternative.

### Changed Files and Staging

Relevant files:

- `Presentation/Changes/Sidebar.swift`
- `Presentation/Shared/ChangedFileRow.swift`
- `Presentation/ViewModels/ChangedFilesHandler.swift`

Suggestions:

- Animate file insertion/removal after refresh while preserving stable path identity.
- Smoothly interpolate selection background and disclosure state.
- Use symbol replacement for stage/unstage state.
- Briefly tint a row after successful stage/unstage.
- Animate filter result counts and the filtered-empty state.
- Crossfade filter chips/options rather than rebuilding the whole sidebar abruptly.
- Avoid entrance animations for an entire large repository status result.

### Loading, Errors, and Success

Apply consistently across Presentation:

- Fade or slide inline errors into place instead of showing routine modal alerts.
- Crossfade loading text into loaded content.
- Use temporary checkmarks or subtle highlight flashes for success.
- Keep progress indicators stable in size to avoid layout jumps.
- Animate disabled/enabled state changes through color and opacity, not movement.

## Priority 2: Navigation and Continuity

### App Shell

Relevant files:

- `Presentation/AppShell/RepositoryScreen.swift`
- `Presentation/AppShell/ChangesSplitViewController.swift`
- `Presentation/AppShell/HistorySplitViewController.swift`
- `Presentation/AppShell/MainSplitViewController.swift`

Suggestions:

- Crossfade from the empty repository state to repository content.
- Use a restrained directional transition between Changes and History.
- Animate optional pane visibility through native split-view APIs.
- Preserve divider positions and first-responder focus during transitions.
- Fade stale content before applying a newly selected repository snapshot.

### Empty Repository State

Relevant file: `Presentation/AppShell/RepositoryScreen.swift`

Suggestions:

- Add a subtle one-time folder-symbol appearance or pulse.
- Add restrained hover/pressed feedback to the Select Repository button.
- Crossfade the state out after repository selection.
- Do not use continuous icon motion.

### Branches

Relevant files:

- `Presentation/Branches/BranchesViewController.swift`
- `Presentation/Branches/BranchCellView.swift`
- `Presentation/Branches/BranchesPopoverPresenter.swift`
- Branch create, rename, delete, compare, stash-and-switch, and update sheets

Suggestions:

- Smooth hover highlighting for custom branch rows/popover controls.
- Replace the current-branch checkmark when checkout completes.
- Animate inserted, renamed, and deleted rows while retaining selection.
- Show checkout/update progress in the affected row or action area.
- Provide brief completion feedback after branch switching.
- Animate disclosure arrows and content replacement in custom popovers.
- Keep native menu and sheet presentation animations unchanged.

### History

Relevant files:

- `Presentation/History/CommitHistorySidebar.swift`
- `Presentation/History/CommitRow.swift`
- `Presentation/History/ChangedFilesColumn.swift`
- `Presentation/History/HistoryFilesColumn.swift`
- `Presentation/History/CommitDetailsHeader.swift`
- `Presentation/History/HistorySplitViewController.swift`

Suggestions:

- Animate commit selection highlight without moving rows.
- Crossfade commit details when selection changes.
- Transition changed-file columns and diff content together.
- Animate changed counts and commit statistics numerically.
- Add completion feedback for branch/tag creation from a commit.
- Animate reorder/squash previews only when the visual position communicates the resulting history.

## Priority 3: Content-Specific Motion

### Diff Viewer

Relevant files:

- `Presentation/Diff/DiffViewer.swift`
- `Presentation/Diff/DiffHeader.swift`
- `Presentation/Diff/DiffLineRow.swift`

Suggestions:

- Crossfade between selected-file diffs.
- Use a lightweight loading placeholder before diff content appears.
- Transition text, image, binary, submodule, and large-diff states.
- Fade image-diff content after decoding completes.
- Animate large-diff warnings into place.
- Optionally reveal a newly expanded hunk, but never animate every diff line.
- Avoid motion that causes attributed-string rebuilding or scroll-position loss.

### Suggestions and Stash Panel

Relevant files:

- `Presentation/Changes/SuggestionCard.swift`
- `Presentation/Changes/Sidebar.swift`

Suggestions:

- Slide/fade suggestion cards in and out.
- Animate compact expansion/collapse while preserving surrounding layout.
- Briefly confirm accepted actions before removing the card.
- Transition stash panel visibility and count changes.

### Conflicts

Relevant file: `Presentation/Conflicts/ConflictsDialogView.swift`

Suggestions:

- Replace unresolved symbols with resolved checkmarks.
- Collapse/fade resolved rows after a short confirmation period.
- Animate the progress count as conflicts are resolved.
- Show a restrained completion state when all conflicts are resolved.
- Never hide unresolved state or auto-dismiss before the user can understand completion.

### Stash Management

Relevant file: `Presentation/Stash/StashManagementViewController.swift`

Suggestions:

- Animate stash row insertion/removal using native table updates.
- Show apply/pop/drop progress in the selected row or action area.
- Transition button enabled state as selection changes.
- Briefly confirm successful apply/pop/drop operations.
- Preserve table selection and scroll position.

## Priority 4: Forms, Onboarding, and Settings

### Onboarding

Relevant files:

- `Presentation/Onboarding/OnboardingView.swift`
- `Presentation/Onboarding/OnboardingViewModel.swift`

Suggestions:

- Keep the existing step animation and add directional continuity.
- Animate progress interpolation between steps.
- Transition validation and setup status inline.
- Add a restrained completion checkmark before closing.
- Disable spatial motion under Reduce Motion while retaining opacity feedback.

### Create and Clone Repository

Relevant files:

- `Presentation/Repository/CreateRepositorySheet.swift`
- `Presentation/Repository/CloneRepositoryWindowController.swift`
- `Presentation/Repository/CreateRepositoryWindowController.swift`

Suggestions:

- Animate inline validation and button enabled state.
- Crossfade destination-path confirmation after folder selection.
- Show stable clone/create progress without resizing the sheet.
- Sequence success confirmation before dismissal.
- Use subtle focus emphasis for the first invalid field.

### Settings

Relevant files: `Presentation/Settings/`

Suggestions:

- Fade save/error status banners in and out.
- Animate toggle-dependent sections and advanced options.
- Crossfade settings pane content while preserving native tab/toolbar behavior.
- Animate appearance preview changes without animating the entire window.
- Transition notification, integration, and Git validation states.
- Avoid motion for every checkbox or standard AppKit control when native feedback is sufficient.

### Repository Settings

Relevant files:

- `Presentation/RepositorySettings/RepositorySettingsWindowController.swift`
- `Presentation/RepositorySettings/RepositorySettingsViewModel.swift`

Suggestions:

- Crossfade loading labels into remote/default-branch/LFS content.
- Fade success/error banners and remove them predictably.
- Provide remote-save, branch-rename, and LFS-initialization completion feedback.
- Animate tab content only when it does not conflict with native `NSTabView` behavior.
- Keep open-in-terminal/editor actions immediate; a brief symbol confirmation is sufficient.

### Sheets and Destructive Actions

Relevant areas:

- Branch dialogs
- Reset, reorder, and squash sheets
- Stash-and-switch
- Repository creation and clone sheets

Suggestions:

- Animate inline validation and expandable advanced options.
- Use restrained warning emphasis when destructive choices change.
- Keep native macOS sheet presentation/dismissal.
- Do not animate confirmations in ways that obscure the default or cancel action.

## Shared Components to Consider

Potential reusable, narrowly scoped helpers:

- A Reduce Motion-aware animation policy for SwiftUI.
- A small set of named durations and spring choices.
- A reusable inline status transition for loading/success/error.
- A reusable SF Symbol replacement helper.
- AppKit helpers for fading labels/banners and animating table updates.

Do not build a large animation framework before multiple concrete uses exist. Start with the toolbar,
commit box, changed-file staging, and inline status feedback, then extract only repeated behavior.

## Implementation Order

1. Establish Reduce Motion-aware duration/spring conventions.
2. Add operation feedback to toolbar sync and commit actions.
3. Add changed-file staging and list update transitions.
4. Standardize inline loading/error/success transitions.
5. Add repository/tab/file/commit continuity transitions.
6. Add content-specific motion for branches, history, conflicts, stash, and diffs.
7. Polish forms, onboarding, settings, and repository settings.
8. Profile large repositories and diffs before expanding motion further.

## Acceptance Criteria

- Motion communicates a state change or user action.
- Reduce Motion is respected.
- Keyboard focus, VoiceOver, selection, and scroll position remain correct.
- Frequent actions do not feel delayed.
- Large lists and diffs remain responsive.
- No animation depends on Git or parsing work running on the main thread.
- UI tests or focused state tests cover important animated state transitions where practical.
- Senior Engineer review finds no blocker/major accessibility, concurrency, or performance issue.
