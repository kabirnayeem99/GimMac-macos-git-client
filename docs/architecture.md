# Architecture

## Overview

GimMac follows Clean Architecture with AppKit-first presentation and MVVM using Observation.

```text
Presentation (AppKit Views/ViewControllers + ViewModels)
  -> Domain (entities, value objects, use cases, protocols)
    -> Data/Infrastructure (git process runner, parsers, persistence, API)
```

## Dependency Rules

- Presentation may depend on Domain abstractions only.
- Domain must not depend on AppKit, networking, storage, or process execution.
- Data/Infrastructure implement Domain protocols and may use Foundation/system APIs.
- Dependency injection is performed in a composition root at app startup.
- Git command execution is isolated behind `GitClientProtocol`.
- Raw git parsing is isolated to parser components, never in UI classes.

## Module Layout

```text
Sources/GimMac/
  App/
  Presentation/
  Domain/
  Data/
  Infrastructure/
Tests/
  GimMacTests/
  GimMacIntegrationTests/
UITests/
  GimMacUITests/
```

## Data Layer

`Sources/GimMac/Data/` implements the Domain protocols using system Git, Foundation, and Core Data.

### Git command execution

- `ProcessGitClient.swift` — `GitClientProtocol` implementation; the entry point for running git processes with timeouts and cancellation.
- `ProcessGitCommandRunner.swift` — Lower-level process runner that drains stdout/stderr pipes, manages command environments, and supports cancellation by command ID.
- `GitCommandRunning.swift` — Executable-command abstraction used by the process runner.
- `GitCommandBuilder.swift` — Reusable git argument arrays (`status`, `rev-parse`, path-safe helpers).
- `GitAppErrorMapper.swift` — Maps raw process exit codes and stderr strings to typed `GitAppError` values.

### Parsers

- `GitStatusParser.swift` — Parses `git status --porcelain=v1` into `ChangedFile` values, including renames, copies, submodules, and unmerged entries.
- `GitLogParser.swift` — Parses formatted `git log` output into `Commit` values.
- `Parsers/BranchForEachRefParser.swift` — Parses `git for-each-ref` output for local and remote branches.
- `GitDiffProvider+Parsing.swift` — Parses unified diff output into hunks and lines.
- `Vendored/SwiftyDiff/SwiftyDiffUnifiedParser.swift` — Vendored unified diff parser used as a fallback.

### Working directory and diff

- `GitStatusProvider.swift` — Loads the current working directory status.
- `GitDiffProvider.swift` — Loads diffs for working-tree changes and arbitrary commits.
- `GitDiffProvider+Image.swift` — Image/blob diff helpers.
- `GitDiffProvider+Submodule.swift` — Submodule diff handling.
- `GitDiscardProvider.swift` — Discards working-tree changes.

### Branches

- `GitBranchReader.swift` — Reads local and remote branches via `git for-each-ref`.
- `GitBranchOperator.swift` — Switches, renames, and deletes local and remote branches.
- `GitBranchUpstreamReader.swift` — Reads the upstream tracking branch for a local branch.
- `GitBranchCompareReader.swift` — Compares two branches (ahead/behind counts and commits).

### Commits and history

- `GitCommitProvider.swift` — Stages selected paths and creates commits with options for signing and amend.
- `GitCommitInspector.swift` — Lists files changed in a given commit.
- `GitHistoryProvider.swift` — Loads paginated commit history.
- `GitReorderProvider.swift` — Reorders commits via interactive rebase.
- `GitSquashProvider.swift` — Squashes a range of commits.
- `GitResetProvider.swift` — Resets HEAD and/or index.
- `GitRevertProvider.swift` — Reverts commits.
- `GitCherryPickProvider.swift` — Cherry-picks commits.

### Stashes and tags

- `GitStashProvider.swift` — Creates, applies, drops, and lists stashes.
- `GitTagProvider.swift` — Creates annotated or lightweight tags.

### Conflicts, merge, and rebase

- `GitConflictService.swift` — Detects conflicted files, counts conflict markers, stages manual resolutions, and opens external merge tools.
- `GitMergeService.swift` — Runs merges and squash merges.
- `GitRebaseService.swift` — Runs interactive and non-interactive rebases.

### Remotes

- `GitRemoteService.swift` — Reads and updates remote URLs.
- `GitRemoteSyncService.swift` — Performs fetch, pull, push, force-with-lease push, and branch publishing.

### Repository lifecycle

- `GitRepositoryCreationService.swift` — Initializes new repositories and clones existing ones.
- `FileRepositoryScaffolding.swift` — Writes README, `.gitignore`, `.gitattributes`, license, and `.git/description` files into a new repository.
- `BundledRepositoryTemplateCatalog.swift` — Loads bundled `.gitignore` templates and open-source license bodies.
- `RepositoryCreationOrchestrator.swift` — Coordinates init/clone with optional scaffolding and license substitution.
- `LocalGitRepositoryInspector.swift` — Inspects a local directory and reports its `TipState`.
- `GitUpdateFromDefaultService.swift` — Merges or rebases the current branch from the repository's default branch.
- `GitLFSService.swift` — Checks Git LFS availability and initializes LFS in a repository.
- `GitIgnoreProvider.swift` — Appends entries to `.gitignore`.
- `GitConfigService.swift` — Reads and writes Git config, pinning `HOME` to an isolatable home URL for tests.
- `GitEditorScript.swift` — Builds editor scripts used by interactive Git operations.

### Persistence and settings

- `CoreDataRepositoryPersistence.swift` — Core Data-backed store for recently opened repositories and the currently selected repository.
- `CoreDataRepositoryPersistence+Model.swift` — Programmatic `NSManagedObjectModel` definition.
- `CoreDataRepositoryPersistence+Mapping.swift` — Maps `NSManagedObject` records to `StoredRepository` and canonicalizes paths.
- `UserDefaultsAppSettingsStore.swift` — `UserDefaults`-backed implementation of `AppSettingsStoring`; the only place settings keys and defaults live.
- `UserDefaultsAppSettingsStore+Keys.swift` — Settings key definitions.
- `UserDefaultsAppSettingsStore+Properties.swift` — Type-safe convenience accessors for settings values.

### Live repository screen data

- `LiveRepositoryScreenDataRepository.swift` — Aggregates status, upstream state, ahead/behind, conflict state, and the primary repository action into a `RepositoryScreenSnapshot`.

### Logging

- `Logging/GimMacLogger.swift` — File-based structured logger for app events and git command auditing.
- `Logging/LogEntry.swift` — Log entry model and console formatting.

## Presentation Layer

`Sources/GimMac/Presentation/` contains AppKit controllers, SwiftUI views, and `@Observable` ViewModels. Views depend only on Domain types and ViewModels; ViewModels depend on Domain protocols.

### App shell

- `AppShell/MainSplitViewController.swift` — Root window controller; hosts `RepositoryScreen`, routes menu-bar actions, and presents open/clone/create repository sheets.
- `AppShell/RepositoryScreen.swift` — Root SwiftUI view that switches between the Changes and History tabs and presents the conflict-resolution sheet.
- `AppShell/MainToolbarController.swift` — Builds and owns the native unified `NSToolbar`, hosting SwiftUI toolbar items such as the branch picker and sync controls.
- `AppShell/SidebarViewController.swift` — Native AppKit sidebar for the Settings window.
- `AppShell/RepositorySplitViewController.swift` — Shared `NSSplitViewController` base for repository layouts.
- `AppShell/ChangesSplitViewController.swift` — Native two-pane split view for the Changes tab (sidebar + diff viewer).
- `AppShell/RepositoryContentView.swift` / `AppShell/RepositoryContentRepresentable.swift` — SwiftUI wrappers around native repository content.
- `AppShell/SettingsWindowController.swift` / `AppShell/SettingsRootViewController.swift` — Settings window and split-view root.
- `AppShell/EmptyRepositoryStateView.swift` — Empty-state placeholder shown when no repository is selected.

### ViewModels

- `ViewModels/RepositoryStoreViewModel.swift` — Central `@Observable` ViewModel owned by the app shell; holds selected repository, changed files, commits, sync/commit outcomes, and primary action state. Implemented via focused extensions for branches, commits, conflicts, discard, file actions, history, ignore, outcomes, repository management, stash, and sync.
- `ViewModels/BranchesViewModel.swift` — Drives the branch list, switching, renaming, deletion, validation, and stash guards.
- `ViewModels/BranchCompareViewModel.swift` — Drives the branch comparison sheet.
- `ViewModels/StashManagementViewModel.swift` — Drives the stash list and apply/drop actions.
- `ViewModels/ChangedFilesHandler.swift` — Selection and staging logic for changed files.
- `ViewModels/CommitFormHandler.swift` — Commit message, description, and option state.
- `ViewModels/DiffHandler.swift` — Diff loading and selection state.
- `ViewModels/HistoryHandler.swift` — History list selection and pagination state.
- `ViewModels/RepositoryBranchDisplayFormatter.swift` — Formatting helpers for branch names in the UI.

### Changes

- `Changes/MainContent.swift` — Main content area when no diff is selected, including the primary action button and remote suggestions.
- `Changes/Sidebar.swift` — Changes sidebar with file list and filter chips.
- `Changes/ChangedFilesListView.swift` / `Changes/ChangedFilesHeader.swift` — File list and its header.
- `Changes/CommitBox.swift` — Commit message input and options.
- `Changes/CommitInlineStatusSection.swift` — Inline status below the commit box.
- `Changes/FilterChips.swift` — Status filter chips.
- `Changes/HeaderSection.swift` — Section headers for the changes list.
- `Changes/StashPanel.swift` / `Changes/SuggestionCard.swift` — Stash and suggestion UI.

### Diff

- `Diff/DiffViewer.swift` — Main diff viewer that selects the appropriate diff renderer.
- `Diff/DiffLineRow.swift` / `Diff/DiffHeader.swift` — Unified diff line and header rendering.
- `Diff/DiffModels.swift` — Presentation models for diff rendering.
- `Diff/DiffMessageView.swift` — Empty/error/placeholder messages in the diff pane.
- `Diff/ImageDiffContentView.swift` / `Diff/AsyncDecodedImageDiffPreview.swift` — Image diff rendering.
- `Diff/SubmoduleDiffContentView.swift` — Submodule change rendering.

### History

- `History/HistorySplitViewController.swift` — Native three-pane split view for the History tab (commit list, files, diff).
- `History/CommitHistorySidebar.swift` — Commit list sidebar.
- `History/CommitRow.swift` / `History/CommitDetailsHeader.swift` — Commit row and detail header.
- `History/ChangedFilesColumn.swift` / `History/HistoryFilesColumn.swift` / `History/HistoryFileRow.swift` — Changed-files columns and rows.
- `History/HistoryDiffContent.swift` — Diff content for a selected historical file.
- `History/CreateBranchFromCommitSheet.swift`, `History/CreateTagSheet.swift`, `History/ReorderCommitsSheet.swift`, `History/ResetToCommitSheet.swift`, `History/SquashCommitsSheet.swift` — History action sheets.

### Branches

- `Branches/BranchDialogPresenter.swift` — Coordinates branch-related modal sheets and pickers.
- `Branches/BranchesViewController.swift` — Native branch list view controller.
- `Branches/BranchCellView.swift` — Branch row cell.
- `Branches/CreateBranchWindowController.swift`, `Branches/RenameBranchWindowController.swift`, `Branches/DeleteBranchWindowController.swift`, `Branches/CompareBranchWindowController.swift` — Branch action windows.
- `Branches/StashAndSwitchSheetController.swift` / `Branches/UpdateFromDefaultSheetController.swift` — Stash-and-switch and update-from-default sheets.

### Toolbar

- `Toolbar/BranchToolbarButton.swift` / `Toolbar/BranchPullDownMenuContent.swift` / `Toolbar/BranchesPickerPopover.swift` / `Toolbar/BranchesViewControllerWrapper.swift` — Branch picker in the toolbar.
- `Toolbar/RepositoryMenuButton.swift` / `Toolbar/RepositoryPickerDialog.swift` / `Toolbar/RepositoryPickerRow.swift` — Repository selector in the toolbar.
- `Toolbar/SyncMenuButton.swift` / `Toolbar/SyncToolbarButtonStyle.swift` / `Toolbar/PushToolbarCard.swift` / `Toolbar/ToolbarCard.swift` — Sync controls and card styling.
- `Toolbar/ConditionalToolbarItemStyle.swift` / `Toolbar/ToolbarItemStyle.swift` — Toolbar item styles.

### Conflicts

- `Conflicts/ConflictsDialogView.swift` — Conflict resolution dialog.
- `Conflicts/UnmergedFileRow.swift` — Row for a conflicted file with resolution options.

### Repository creation and onboarding

- `Onboarding/OnboardingView.swift` / `Onboarding/OnboardingViewModel.swift` / `Onboarding/OnboardingWindowController.swift` / `Onboarding/WelcomeStepView.swift` / `Onboarding/ConfigureGitStepView.swift` — First-launch onboarding flow.
- `Repository/CreateRepositorySheet.swift` / `Repository/CreateRepositoryWindowController.swift` / `Repository/CloneRepositoryWindowController.swift` — New and clone repository windows.

### Repository settings

- `RepositorySettings/RepositorySettingsViewController.swift` / `RepositorySettings/RepositorySettingsViewModel.swift` / `RepositorySettings/RepositorySettingsWindowController.swift` — Repository settings (remote URL, external editor, terminal).

### App settings

- `Settings/SettingsEnvironment.swift` — Composition context that assembles settings ViewModels and pane controllers.
- `Settings/SettingsPaneViewController.swift` — Base controller for settings panes.
- `Settings/*SettingsPaneController.swift` / `Settings/*SettingsViewModel.swift` — One pane controller and ViewModel per settings category (Git, Integrations, Appearance, Notifications, Prompts, Advanced, Accessibility).

### Shared presentation utilities

- `Shared/ChangedFileRow.swift` — Reusable file row used across changes and history.
- `Shared/LiquidGlass.swift` — Liquid Glass background modifier.
- `Shared/LoadingPlaceholder.swift` — Loading placeholder views.
- `Shared/Motion.swift` / `Shared/AppKitMotion.swift` — Motion/animation helpers.

### Stash management

- `Stash/StashManagementViewController.swift` — Window controller for listing and managing stashes.

## Settings / Preferences seam

App-wide preferences follow the same layering as Git operations:

- `Domain/AppSettings.swift` — `AppSettingsStoring` protocol plus value types
  (`ApplicationTheme`, `UncommittedChangesStrategy`, `DateFormat`/`TimeFormat`/`NumberFormat`,
  `CustomIntegration`). Domain stays storage-agnostic.
- `Data/UserDefaultsAppSettingsStore.swift` — `UserDefaults`-backed implementation; the only
  place keys/defaults live.
- App-layer system services implement the remaining Domain protocols where AppKit / system
  frameworks are required: `AppKitThemeController` (`ThemeApplying` → `NSApp.appearance`),
  `UserNotificationAuthorizer` (`NotificationAuthorizing` → `UNUserNotificationCenter`),
  `NSWorkspaceShellService` (`ShellServiceProtocol`).
- `Presentation/Settings/` — one `@Observable` ViewModel and one AppKit pane controller per
  Settings pane, assembled through `SettingsEnvironment` at the composition root (`AppDelegate`).

Global Git identity / `init.defaultBranch` go through `GitConfigService`, not `UserDefaults`.
The service pins `HOME` to its configured `homeURL` so `--global` is isolatable in tests.
See `docs/settings-implementation-plan.md` for the full design and rollout.

## Test Strategy

- Unit tests: Domain logic, parser logic, error mapping, ViewModel state transitions.
- Integration tests: real temporary git repositories for command semantics.
- UI tests: smoke flows for launch, shell visibility, and key interaction entry points (run only when explicitly requested or during release validation).

All feature PRs must keep unit + relevant integration tests passing by default. Run UI tests when explicitly requested or during release validation.
