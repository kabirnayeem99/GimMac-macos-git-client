# UI / UX Bug Audit and Implementation Plan

This document replaces the older TODO-style list with a source-checked audit of the
current `Sources/GimMac/` implementation.

It is intended to be implementation-ready:

- each issue is tied to current behavior;
- each issue states the expected native macOS outcome;
- each issue includes concrete implementation notes;
- work is ordered to reduce rework across the AppKit shell and hosted SwiftUI views.

This app is **AppKit-first**. Where native macOS look, layout, focus behavior, or
toolbar behavior matters, prefer **AppKit** controls and container ownership over
custom SwiftUI styling.

---

## Source-Checked Status Summary

### Already implemented or mostly implemented

These items should **not** be treated as greenfield work:

1. Changes and History panes already use native split-view containers and already
   preserve divider positions and first-responder state across tab switches.
2. The branch toolbar control already exists, supports disabled state, uses middle
   truncation, and already exposes `Switch Branch…` and `New Branch…`.
3. Motion infrastructure already exists, including Reduce Motion support and native
   SwiftUI/AppKit animation helpers.

### Partially implemented or still buggy

These are the real remaining issues:

1. Repository and branch controls do not yet form a coherent native macOS toolbar cluster.
2. Repository control behavior is incomplete relative to expected repository workflows.
3. Branch control behavior is only partially aligned with the desired popup model.
4. Changes / History tab UI is duplicated and not implemented as a single native shell control.
5. Commit button enabled/disabled behavior is incorrect.
6. Sidebar and card styling still overuses material/glass in places where AppKit-native
   surfaces should lead.
7. Several empty/loading/error states need polish for native macOS UX consistency.
8. Accessibility and keyboard behavior need a focused audit after the UI structure is cleaned up.

---

## Design Rules for This Work

Use these rules during implementation:

1. Prefer `NSToolbar`, `NSToolbarItem`, `NSMenuToolbarItem`, `NSSegmentedControl`,
   `NSPopUpButton`, `NSMenu`, `NSStackView`, `NSSplitViewController`, `NSTableView`,
   and `NSOutlineView` when the control is part of window chrome or native navigation.
2. Keep SwiftUI for hosted content regions where it already works well:
   changed-file rows, diff content, form fields, empty states, status presentation.
3. Avoid recreating native toolbar visuals in SwiftUI when AppKit can supply them.
4. Avoid introducing decorative animation libraries. Use the existing native motion
   system unless a concrete product case justifies more.
5. Do not duplicate navigation or selection state across multiple tab controls.
6. Make disabled states explicit and predictable before relying on validation errors.
7. Preserve existing single-source-of-truth view-model state in `RepositoryStoreViewModel`.

---

## Issue 1: Toolbar Information Architecture Is Wrong

### Current state

- The repository control is placed at the leading side of the window toolbar.
- The branch and sync controls are grouped separately at the trailing side.
- This does not match the intended Xcode-like grouping of repository context and branch context.

### Why this is a bug

- Repository and branch are part of the same contextual cluster.
- Splitting them across the toolbar makes branch switching feel detached from repository selection.
- The current arrangement weakens scanability, especially in large windows.

### Target outcome

Toolbar layout should read like:

```text
[other toolbar items / flexible space] [Repository] [Branch] [Sync]
```

Requirements:

- Repository and branch controls sit together in the top trailing area.
- Sync remains immediately adjacent to branch if kept visible there.
- The cluster should feel native, compact, and stable during state changes.
- Controls should not jump horizontally when sync visibility changes.

### Implementation notes

- Refactor `MainToolbarController` to own a single trailing cluster.
- Prefer an AppKit-owned cluster using `NSToolbarItem` + `NSStackView` of native controls.
- Keep width behavior stable when control contents change.
- Keep window title hidden only if the toolbar cluster still visually owns the top row.

### Acceptance criteria

- Repository, branch, and sync appear as one trailing cluster.
- No overlap, jitter, or width collapse during repo/branch changes.
- Toolbar spacing reads as native macOS, not like embedded in-content controls.

---

## Issue 2: Repository Control Is Incomplete and Not Native Enough

### Current state

The repository control currently:

- shows the selected repository;
- lists recent repositories;
- offers `More Repositories…`;
- offers `Open Repository…`.

Missing from the toolbar control:

- `Add Local Repository…`
- `Clone Repository…`
- optionally `New Repository…`

It also does not visually match the intended branch control style.

### Why this is a bug

- Repository selection is a top-level workflow and should expose the primary repo-entry actions.
- Users should not need to rely on menu-bar commands for common repository actions.
- The control currently behaves more like a title chip than a complete repository selector.

### Target outcome

The repository control should:

- show current repository name;
- use a repository/folder icon;
- truncate long names in the middle;
- open a native menu or popup listing recent/saved repositories;
- show a checkmark beside the current repository;
- expose:
  - `Add Local Repository…`
  - `Clone Repository…`
  - `Open Repository…`
  - optionally `New Repository…`
  - `More Repositories…` when the saved list is longer than the inline list
- disable unavailable rows when a saved repository is missing on disk.

### AppKit preference

Prefer one of:

1. `NSMenuToolbarItem`
2. `NSPopUpButton` hosted in the toolbar
3. custom `NSToolbarItem` with AppKit menu presentation

Prefer AppKit over a purely SwiftUI `Menu` here, because toolbar chrome and popup behavior
should feel native to macOS first.

### Implementation notes

- Reuse existing handlers already available in `MainSplitViewController`.
- Keep the full repositories dialog/sheet for large saved lists.
- Preserve path tooltips and missing-repository labeling.
- Make the visual treatment match the branch control so they read as a pair.

### Acceptance criteria

- The toolbar repository control exposes all primary repository actions.
- The current repository is obvious and checkmarked in the menu.
- Long names remain readable due to middle truncation.
- Missing repositories remain visible but disabled.

---

## Issue 3: Branch Control Is Only Partially Correct

### Current state

The branch control already:

- exists in the toolbar;
- truncates text in the middle;
- disables when unavailable;
- offers `Switch Branch…` and `New Branch…`;
- opens a full branch picker popover.

But it currently shows recent branches in the top-level menu instead of behaving like a
true current-branch popup over local branches.

### Why this is a bug

- The first interaction should support direct branch switching from a predictable local-branch list.
- Showing only recent branches makes the menu feel incomplete.
- The popup should better reflect the current repository branch model, including detached HEAD.

### Target outcome

The branch control should:

- show current branch name or detached HEAD display text;
- show a branch icon;
- truncate long names in the middle;
- present local branches in the first-level menu;
- show a checkmark beside the current branch;
- expose:
  - `Switch Branch…`
  - `New Branch…`
- stay disabled when branch data is unavailable.

Detached HEAD requirements:

- The label must explicitly show detached HEAD state.
- Detached HEAD must never render like a blank or missing branch.

### AppKit preference

If the toolbar cluster moves to AppKit-native controls, move this control with it.

Preferred behavior:

- simple popup/menu in the toolbar for common branch switching;
- searchable full picker remains available via `Switch Branch…`.

### Implementation notes

- Reuse existing `BranchesViewModel` and `BranchDialogPresenter`.
- Keep the full searchable picker as the “advanced / full list” path.
- Ensure branch refresh is synchronized with repository selection changes.
- Preserve disabled and accessibility behavior.

### Acceptance criteria

- The first-level branch control is useful for ordinary branch switching.
- Current branch is visibly selected.
- Detached HEAD is shown explicitly.
- Full picker remains available for search-heavy workflows.

---

## Issue 4: Changes / History Tabs Are Duplicated and Not Native Enough

### Current state

- A segmented `Picker` appears in the Changes sidebar.
- Another segmented `Picker` appears in the History sidebar.
- The app already preserves tab state and view-controller state correctly in the shell.

### Why this is a bug

- Two tab controls for one navigation decision creates duplication.
- Text-only segmented controls in content sidebars do not match the intended shell-level navigation.
- This should be owned by the AppKit shell, not duplicated in hosted content.

### Target outcome

There should be one shared tab control for:

- `Changes`
- `History`

Requirements:

- the control should live in the shell layer;
- the control should feel native to macOS;
- the selected state must be visually obvious;
- switching tabs must preserve each tab’s split-view state, focus, and selection state;
- both icon and label should be shown if the chosen native control supports it cleanly.

### AppKit preference

Prefer `NSSegmentedControl` owned by the AppKit shell.

Possible locations:

1. toolbar-adjacent shell area
2. top of the sidebar shell
3. native title/toolbar accessory if it integrates cleanly

Do not keep duplicate copies of the control in both Changes and History panes.

### Implementation notes

- Keep `RepositoryContentViewController.showTab(_:)` as the single switching mechanism.
- Remove duplicated segmented pickers from hosted SwiftUI sidebars.
- Route menu commands and the shared tab control through the same `viewModel.viewTab`.

### Acceptance criteria

- Only one Changes/History control exists in the UI.
- Switching preserves first responder, divider positions, and per-tab state.
- The control reads as shell navigation, not inline content decoration.

---

## Issue 5: Commit Button Disabled State Is Wrong

### Current state

The commit button is disabled for some conditions, but not all of the actual commit guard logic.

The current button logic does not directly use the authoritative `canCommitChanges` state.
As a result, invalid commit attempts can still rely on post-click validation instead of clear pre-click affordance.

### Why this is a bug

- Commit is a primary action and must be predictably enabled or disabled.
- Validation after click is useful as backup, not as the primary UX.
- This especially matters for no-file-selected and empty-summary cases.

### Target outcome

The commit button should be disabled whenever commit is not currently allowed.

Disable when:

- no repository is selected;
- a commit is already in progress;
- no files are selected for commit, unless amend mode explicitly allows otherwise;
- commit summary is empty or only whitespace;
- unresolved conflicts exist.

### Implementation notes

- Bind disabled state directly to `!viewModel.canCommitChanges`.
- Keep shake/error feedback for invalid attempts that still reach submission paths.
- Add contextual `.help(...)` text explaining why the button is disabled.
- Ensure amend mode behavior is preserved.

### Acceptance criteria

- Commit button state always matches actual commit eligibility.
- Empty summary and no-selected-files states are visibly disabled before click.
- Tooltip/help communicates the missing requirement.

---

## Issue 6: Sidebar Surface Styling Is Fighting AppKit

### Current state

- Native `NSSplitViewController` sidebars already provide AppKit-native pane behavior.
- Hosted SwiftUI sidebar content still adds `.thinMaterial` and glass-like card treatments in ways that may muddy the visual hierarchy.

### Why this is a bug

- AppKit already supplies the primary structural surface for sidebars.
- Layering extra material on top can make the UI feel less native and less crisp.
- The current visual treatment risks looking hybrid rather than intentionally native.

### Target outcome

- Let AppKit own the main sidebar and content surfaces.
- Use custom background treatments only for small internal components that truly benefit from emphasis.
- Reduce visual competition between structural surfaces and inline cards.

### Implementation notes

- Audit `Sidebar`, `CommitHistorySidebar`, `CommitBox`, `MainContent`, and toolbar control styling.
- Remove redundant material layers where the parent AppKit pane already provides the correct look.
- Keep explicit backgrounds in diff/content panes where legibility matters.
- Re-check light mode, dark mode, vibrancy, separator clarity, and selected-state contrast.

### Acceptance criteria

- Sidebars read as native AppKit sidebar panes.
- Content panes stay crisp and legible.
- Glass/material usage feels intentional rather than globally sprayed on top.

---

## Issue 7: Empty, Loading, Success, and Error States Need a Native Pass

### Current state

There is already motion/status infrastructure, and several empty states exist.
The issue is not absence; the issue is consistency and native tone.

### Why this is a bug

- Different sections may feel like they were designed independently.
- Some states currently lean too much on animation or custom cards instead of native clarity.
- High-frequency Git workflows should feel calm and precise, not decorative.

### Target outcome

Audit and normalize these states:

1. no repository selected
2. no changed files
3. no history files
4. no branches available
5. branch switching in progress
6. commit in progress
7. commit success
8. commit failure
9. sync/fetch/pull/push success and failure
10. conflict-required state

### Rules

- Prefer subtle opacity/replace/slide transitions already supported by the motion system.
- Respect Reduce Motion everywhere.
- Avoid introducing Lottie unless a very specific state justifies it.
- Use native macOS wording and pacing.

### Acceptance criteria

- State transitions feel consistent across the app.
- Feedback is visible but not noisy.
- Reduce Motion produces a clear static fallback for every animated state.

---

## Issue 8: Accessibility and Keyboard UX Need a Focused Audit

### Current state

Some accessibility labels are already present, but the UI architecture is changing enough
that a final pass is required after the shell cleanup.

### Why this is a bug risk

- Toolbar rewrites often regress keyboard focus and accessibility naming.
- Duplicate controls and hosted views can create confusing VoiceOver behavior.
- Native macOS apps should support keyboard-first navigation well.

### Target outcome

Audit the following after structural changes land:

1. VoiceOver labels for repository, branch, sync, and tab controls.
2. Keyboard navigation across toolbar, sidebar list, history list, and commit form.
3. Focus restoration when switching between Changes and History.
4. Disabled-state announcements for commit and sync actions.
5. Popover/sheet focus for branch picker, repository picker, clone, and create flows.

### Acceptance criteria

- All primary controls are clearly named for VoiceOver.
- Keyboard users can switch views and act without needing the mouse.
- No hidden or duplicate controls confuse accessibility navigation.

---

## Implementation Order

Execute in this order to avoid rework:

1. Fix commit-button enable/disable behavior.
2. Replace duplicate Changes/History controls with one shared native shell control.
3. Rework toolbar layout into one trailing repository/branch/sync cluster.
4. Upgrade repository control to a complete native repository selector.
5. Upgrade branch control to a more complete native popup model.
6. Clean up sidebar/material styling after shell structure is stable.
7. Normalize empty/loading/success/error states.
8. Perform accessibility and keyboard audit.
9. Update screenshots / QA notes if needed.

---

## Suggested Task Breakdown

### Task 1: Commit gating fix

- bind commit button disabled state to `canCommitChanges`
- add disabled help text
- verify amend mode
- add regression tests for summary/selection/conflict gating

### Task 2: Shared shell tab control

- add one AppKit-owned Changes/History control
- remove duplicated SwiftUI segmented controls
- preserve menu-command synchronization
- verify focus restoration and divider preservation

### Task 3: Toolbar cluster restructure

- move repository into trailing cluster
- keep branch and sync adjacent
- stabilize intrinsic sizing and visibility behavior
- verify layout across narrow and wide windows

### Task 4: Repository selector upgrade

- expose recent repositories with checkmark
- add `Add Local Repository…`
- add `Clone Repository…`
- decide whether to include `New Repository…`
- keep `More Repositories…` path

### Task 5: Branch selector upgrade

- show local branches in first-level menu
- preserve full searchable picker
- show detached HEAD clearly
- verify disabled behavior when branches are unavailable

### Task 6: Native surface cleanup

- remove redundant material layers
- preserve legibility in diff/content panes
- tune separators, hover states, and sidebar emphasis

### Task 7: State polish

- review all high-frequency empty/loading/success/error states
- reduce overly decorative motion
- ensure native wording and timing

### Task 8: Accessibility / keyboard QA

- VoiceOver labels
- first responder and focus order
- keyboard shortcuts and navigation
- disabled-state explanations

---

## QA Checklist

Use this checklist during implementation:

- Repository control stays readable with long repository names.
- Branch control stays readable with long branch names.
- Detached HEAD is explicit everywhere branch context is shown.
- Repository and branch controls remain aligned during live updates.
- Sync visibility does not cause control jumpiness.
- Changes/History switching preserves divider positions.
- Changes/History switching preserves keyboard focus correctly.
- Commit button disables immediately when summary becomes blank.
- Commit button disables immediately when no files are selected.
- Commit button disables immediately when conflicts exist.
- Missing repositories remain visible but cannot be selected.
- Menus, popovers, and sheets open with sensible keyboard focus.
- Reduce Motion behavior is respected across all animated feedback.
- VoiceOver names the toolbar controls and status elements clearly.

---

## Non-Goals for This Queue Item

These are out of scope for this document unless explicitly added later:

- hunk-level staging
- commit graph redesign
- diff engine redesign
- adding third-party animation systems
- broad visual rebranding
- hosted-platform integrations

---

## Definition of Done for This Bug Batch

This bug batch is done when:

1. the toolbar cluster is native, coherent, and stable;
2. repository and branch selectors expose the expected primary actions;
3. Changes/History navigation is represented by one shared native control;
4. commit affordance correctly reflects eligibility before click;
5. sidebar surface styling no longer fights AppKit;
6. key empty/loading/status states feel consistent and calm;
7. accessibility and keyboard behavior are verified after the structural cleanup.
