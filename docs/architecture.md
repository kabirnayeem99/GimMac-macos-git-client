# Architecture

## Overview

GimMac follows Clean Architecture with AppKit-first presentation and MVVM using Observation.

```text
Presentation (AppKit ViewControllers + SwiftUI views + @Observable ViewModels)
  -> Application (entities, value objects, use-case protocols / ports)
    -> Infrastructure (git process runner, parsers, persistence, platform services)
```

The Xcode target is a single module, but the source tree enforces the dependency direction above.

## Dependency Rules

- Presentation may depend on Application abstractions only.
- Application must not import AppKit, networking, storage, or process execution.
- Infrastructure implements Application ports and may use Foundation/system APIs.
- Dependency injection is performed in a composition root at app startup (`AppDelegate`).
- Git command execution is isolated behind `GitClientProtocol`.
- Raw git parsing is isolated to parser components, never in UI classes.
- Presentation ViewModels are `@Observable` Swift classes; Combine is not used.

## Source Tree

```text
Sources/GimMac/
  App/                      — AppKit lifecycle, composition root, menus, platform bridges
  Application/
    Models/                 — Domain entities and value objects
    Ports/                  — Protocols consumed by Application and implemented by Infrastructure
    Services/               — Thin Application-level orchestrators (e.g. repository creation)
  Infrastructure/
    Git/                    — Git command builders, runners, readers, operators, parsers, errors
    Logging/                — Structured file logging and log entry model
    Persistence/            — Core Data, UserDefaults, live repository screen data
    Platform/               — AppKit/system service implementations of Application ports
    Templates/              — Repository scaffolding and bundled templates
    Vendored/               — Third-party code (e.g. SwiftyDiff)
  Presentation/
    DesignSystem/           — Reusable design tokens and modifiers
    Features/               — Per-feature screens, components, sheets, windows, ViewModels
    Shared/                 — Cross-cutting presentation utilities
    Shell/                  — App-level shell, split views, empty states, window controllers
    Toolbar/                — Unified toolbar and its picker/styling pieces
  Resources/                — Assets, app icon, bundled templates
main.swift
Tests/
  GimMacTests/              — Unit tests
  GimMacIntegrationTests/   — Tests against real temporary git repositories
UITests/
  GimMacUITests/            — Smoke UI tests
```

## Application Layer

`Sources/GimMac/Application/` is the domain center. It defines models and ports but has no knowledge of AppKit, Core Data, `UserDefaults`, or the git process runner.

### Models

Key value objects and entities:

- `Repository.swift` — Local repository value type.
- `StoredRepository.swift` — Persisted repository record.
- `ChangedFile.swift` — Working-tree file change with status, staging, conflict flags, rename tracking.
- `Commit.swift` / `CommitFile.swift` / `CommitAuthor.swift` — Commit and commit-file models.
- `DiffDocument.swift` / `DiffLine.swift` — Diff document and line models.
- `Branch.swift` / `BranchStartPoint.swift` / `BranchCompareResult.swift` / `BranchesTab.swift` — Branch models and compare result.
- `StashEntry.swift` — Stash entry.
- `ConflictedFileStatus.swift` — Conflicted file with resolution status.
- `Tip.swift` — `TipState` and `BranchSummary` for toolbar branch display.
- `GitUserProfile.swift` / `GitIdentity.swift` — Git identity value types.
- `RepositoryScreenSnapshot.swift` — Aggregated screen state from `LiveRepositoryScreenDataRepository`.
- `AppSettingsValues.swift` — Settings value types.
- `GitAppError.swift` — Typed application errors.
- `LogEntry.swift` / `LogCategory.swift` / `LogLevel.swift` — Logging models.

### Ports

Application ports are protocols implemented by Infrastructure:

- `GitClientProtocol` — Runs git argument arrays.
- `RepositoryInspecting` — Inspects a directory and reports `TipState`.
- `RepositoryPersistenceProviding` — Persists recently opened and selected repositories.
- `RepositoryScreenDataProviding` — Provides `RepositoryScreenSnapshot`.
- `DiffProviding` — Loads working-tree and commit diffs.
- `CommitProviding` / `CommitInspecting` — Creates commits and lists commit files.
- `StatusProviding` — Loads working-tree status.
- `BranchProviding` / `BranchOperating` / `BranchCompareProviding` — Reads and mutates branches.
- `StashProviding` — Stash operations.
- `RemoteSyncProviding` — Fetch, pull, push.
- `DiscardProviding` / `GitIgnoreProviding` / `ResetProviding` / `RevertProviding` / `CherryPickProviding` / `TagProviding` / `ReorderProviding` / `SquashProviding` / `ConflictResolutionProviding` / `MergeBranchProviding` / `RebaseProviding` — Additional git operations.
- `RepositoryCreating` / `RepositoryCloneProviding` / `RepositoryInitProviding` / `RepositoryTemplateCatalog` — Repository creation.
- `AppSettingsStoring` — App settings storage.
- `AppLogging` — Structured logging.
- `ThemeApplying` / `NotificationAuthorizing` / `ExternalEditorOpening` / `ShellLaunching` — Platform service ports.

### Services

- `RepositoryCreationOrchestrator.swift` — Coordinates init/clone with optional scaffolding and license substitution.

## Infrastructure Layer

`Sources/GimMac/Infrastructure/` implements Application ports using system Git, Foundation, Core Data, and AppKit where required.

### Git command execution

- `Git/Process/ProcessGitClient.swift` — `GitClientProtocol` implementation; entry point for running git processes with timeouts and cancellation.
- `Git/Process/ProcessGitCommandRunner.swift` — Lower-level process runner that drains stdout/stderr pipes, manages command environments, and supports cancellation by command ID.
- `Git/Process/GitCommandBuilder.swift` — Reusable git argument arrays (`status`, `rev-parse`, path-safe helpers).
- `Git/Process/GitCommandRunning.swift` — Executable-command abstraction used by the process runner.
- `Git/Errors/GitAppErrorMapper.swift` — Maps raw process exit codes and stderr strings to typed `GitAppError` values.

### Parsers

- `Git/Parsing/GitStatusParser.swift` — Parses `git status --porcelain=v1` into `ChangedFile` values, including renames, copies, submodules, and unmerged entries.
- `Git/Parsing/GitLogParser.swift` — Parses formatted `git log` output into `Commit` values.
- `Git/Parsing/BranchForEachRefParser.swift` — Parses `git for-each-ref` output for local and remote branches.
- `Git/Readers/GitDiffProvider+Parsing.swift` — Parses unified diff output into hunks and lines.
- `Vendored/SwiftyDiff/SwiftyDiffUnifiedParser.swift` — Vendored unified diff parser used as a fallback.

### Working directory and diff

- `Git/Readers/GitStatusProvider.swift` — Loads the current working directory status.
- `Git/Readers/GitDiffProvider.swift` — Loads diffs for working-tree changes and arbitrary commits.
- `Git/Readers/GitDiffProvider+Image.swift` — Image/blob diff helpers.
- `Git/Readers/GitDiffProvider+Submodule.swift` — Submodule diff handling.
- `Git/Readers/GitDiscardProvider.swift` — Discards working-tree changes.

### Branches

- `Git/Readers/GitBranchReader.swift` — Reads local and remote branches via `git for-each-ref`.
- `Git/Operations/GitBranchOperator.swift` — Switches, renames, and deletes local and remote branches.
- `Git/Readers/GitBranchUpstreamReader.swift` — Reads the upstream tracking branch for a local branch.
- `Git/Readers/GitBranchCompareReader.swift` — Compares two branches (ahead/behind counts and commits).

### Commits and history

- `Git/Readers/GitCommitProvider.swift` — Stages selected paths and creates commits with options for signing and amend.
- `Git/Readers/GitCommitInspector.swift` — Lists files changed in a given commit.
- `Git/Readers/GitHistoryProvider.swift` — Loads paginated commit history.
- `Git/Readers/GitReorderProvider.swift` — Reorders commits via interactive rebase.
- `Git/Readers/GitSquashProvider.swift` — Squashes a range of commits.
- `Git/Readers/GitResetProvider.swift` — Resets HEAD and/or index.
- `Git/Readers/GitRevertProvider.swift` — Reverts commits.
- `Git/Readers/GitCherryPickProvider.swift` — Cherry-picks commits.
- `Git/Readers/GitTagProvider.swift` — Creates annotated or lightweight tags.

### Stashes

- `Git/Readers/GitStashProvider.swift` — Creates, applies, drops, and lists stashes.

### Conflicts, merge, and rebase

- `Git/Operations/GitConflictService.swift` — Detects conflicted files, counts conflict markers, stages manual resolutions, and opens external merge tools.
- `Git/Operations/GitMergeService.swift` — Runs merges and squash merges.
- `Git/Operations/GitRebaseService.swift` — Runs interactive and non-interactive rebases.

### Remotes

- `Git/Operations/GitRemoteService.swift` — Reads and updates remote URLs.
- `Git/Operations/GitRemoteSyncService.swift` — Performs fetch, pull, push, force-with-lease push, and branch publishing.

### Repository lifecycle

- `Git/Operations/GitRepositoryCreationService.swift` — Initializes new repositories and clones existing ones.
- `Templates/FileRepositoryScaffolding.swift` — Writes README, `.gitignore`, `.gitattributes`, license, and `.git/description` files into a new repository.
- `Templates/BundledRepositoryTemplateCatalog.swift` — Loads bundled `.gitignore` templates and open-source license bodies.
- `Persistence/LocalGitRepositoryInspector.swift` — Inspects a local directory and reports its `TipState`.
- `Git/Operations/GitUpdateFromDefaultService.swift` — Merges or rebases the current branch from the repository's default branch.
- `Git/Operations/GitLFSService.swift` — Checks Git LFS availability and initializes LFS in a repository.
- `Git/Operations/GitIgnoreProvider.swift` — Appends entries to `.gitignore`.
- `Git/Operations/GitConfigService.swift` — Reads and writes Git config, pinning `HOME` to an isolatable home URL for tests.
- `Git/Operations/GitEditorScript.swift` — Builds editor scripts used by interactive Git operations.

### Persistence and settings

- `Persistence/CoreData/CoreDataRepositoryPersistence.swift` — Core Data-backed store for recently opened repositories and the currently selected repository.
- `Persistence/CoreData/CoreDataRepositoryPersistence+Model.swift` — Programmatic `NSManagedObjectModel` definition.
- `Persistence/CoreData/CoreDataRepositoryPersistence+Mapping.swift` — Maps `NSManagedObject` records to `StoredRepository` and canonicalizes paths.
- `Persistence/UserDefaults/UserDefaultsAppSettingsStore.swift` — `UserDefaults`-backed implementation of `AppSettingsStoring`; the only place settings keys and defaults live.
- `Persistence/UserDefaults/UserDefaultsAppSettingsStore+Keys.swift` — Settings key definitions.
- `Persistence/UserDefaults/UserDefaultsAppSettingsStore+Properties.swift` — Type-safe convenience accessors for settings values.

### Live repository screen data

- `Persistence/LiveRepositoryScreenDataRepository.swift` — Aggregates status, upstream state, ahead/behind, conflict state, and the primary repository action into a `RepositoryScreenSnapshot`.

### Logging

- `Logging/GimMacLogger.swift` — File-based structured logger for app events and git command auditing.
- `Application/Models/LogEntry.swift` — Log entry model and console formatting.

### Platform services

- `Platform/AppKitThemeController.swift` — Implements `ThemeApplying` via `NSApp.appearance`.
- `Platform/UserNotificationAuthorizer.swift` — Implements `NotificationAuthorizing` via `UNUserNotificationCenter`.
- `Platform/NSWorkspaceShellService.swift` — Implements `ShellLaunching`.
- `App/NSWorkspaceExternalEditorService.swift` — Implements `ExternalEditorOpening`.

## Presentation Layer

`Sources/GimMac/Presentation/` contains AppKit controllers, SwiftUI views, and `@Observable` ViewModels. Views depend only on Application models and ViewModels; ViewModels depend on Application ports. Presentation is organized by **feature and ownership**, not by technical type.

```text
Presentation/
  DesignSystem/
  Features/
    Branches/
    Changes/
    Conflicts/
    Diff/
    History/
    Onboarding/
    Repository/
    RepositorySettings/
    Settings/
    Stash/
  Shared/
    Components/
    Formatters/
    Motion/
  Shell/
    EmptyStates/
    RepositoryStore/
    SplitViews/
    WindowControllers/
  Toolbar/
    BranchPicker/
    RepositoryPicker/
    Styling/
    Sync/
```

### Folder rules

- **DesignSystem** — Reusable visual tokens (`LiquidGlass`, spacing, typography, colors).
- **Features** — Each feature owns its screens, components, sheets, windows, and ViewModels. Subfolders are added only when a feature has enough files to justify them.
- **Shared** — Cross-cutting presentation components, formatters, and motion helpers that do not belong to a single feature.
- **Shell** — App-level chrome: root split views, repository store, empty states, and top-level window controllers.
- **Toolbar** — Unified toolbar and its grouped picker/styling pieces.

### Shell

- `Shell/SplitViews/MainSplitViewController.swift` — Root window controller; hosts `RepositoryScreen`, routes menu-bar actions, and presents open/clone/create repository sheets.
- `Shell/RepositoryScreen.swift` — Root SwiftUI view that switches between the Changes and History tabs and presents the conflict-resolution sheet.
- `Shell/RepositoryContentView.swift` / `Shell/RepositoryContentRepresentable.swift` — SwiftUI wrappers around native repository content.
- `Shell/SplitViews/RepositorySplitViewController.swift` — Shared `NSSplitViewController` base for repository layouts.
- `Shell/SplitViews/ChangesSplitViewController.swift` / `Shell/SplitViews/ChangesSplitView.swift` — Native two-pane split view for the Changes tab (sidebar + diff viewer).
- `Shell/SplitViews/SidebarViewController.swift` — Native AppKit sidebar.
- `Shell/WindowControllers/SettingsWindowController.swift` / `Shell/WindowControllers/SettingsRootViewController.swift` — Settings window and split-view root.
- `Shell/EmptyStates/EmptyRepositoryStateView.swift` / `Shell/EmptyStates/EmptyStateButtonStyle.swift` — Empty-state placeholder shown when no repository is selected.

### Repository store

- `Shell/RepositoryStore/RepositoryStoreViewModel.swift` — Central `@Observable` ViewModel owned by the app shell; holds selected repository, changed files, commits, sync/commit outcomes, and primary action state.
- `Shell/RepositoryStore/RepositoryStoreViewModel+*.swift` — Focused extensions for branches, commits, conflicts, discard, file actions, history, ignore, outcomes, repository, repository management, stash, and sync.

> **Note:** `RepositoryStoreViewModel` is intentionally kept as one type with extensions today. The long-term direction is to decompose it into feature-scoped stores (`ChangesStore`, `CommitStore`, `BranchesStore`, etc.) owned by a thin composing `RepositoryStoreViewModel`.

### Features

#### Changes

- `Features/Changes/Screens/ChangesContentView.swift` — Changes tab content container.
- `Features/Changes/Screens/MainContent.swift` — Main content area when no diff is selected, including the primary action button and remote suggestions.
- `Features/Changes/Screens/Sidebar.swift` — Changes sidebar with file list and filter chips.
- `Features/Changes/Components/ChangedFilesListView.swift` / `Features/Changes/Components/ChangedFilesHeader.swift` — File list and its header.
- `Features/Changes/Components/CommitBox.swift` — Commit message input and options.
- `Features/Changes/Components/CommitInlineStatusSection.swift` — Inline status below the commit box.
- `Features/Changes/Components/FilterChips.swift` — Status filter chips.
- `Features/Changes/Components/HeaderSection.swift` — Section headers for the changes list.
- `Features/Changes/Components/StashPanel.swift` / `Features/Changes/Components/SuggestionCard.swift` — Stash and suggestion UI.
- `Features/Changes/ChangedFilesHandler.swift` — Selection and staging logic for changed files.
- `Features/Changes/CommitFormHandler.swift` — Commit message, description, and option state.
- `Features/Changes/DiffHandler.swift` — Diff loading and selection state.

#### Diff

- `Features/Diff/DiffViewer.swift` — Main diff viewer that selects the appropriate diff renderer.
- `Features/Diff/DiffLineRow.swift` / `Features/Diff/DiffHeader.swift` — Unified diff line and header rendering.
- `Features/Diff/DiffModels.swift` — Presentation models for diff rendering.
- `Features/Diff/DiffMessageView.swift` — Empty/error/placeholder messages in the diff pane.
- `Features/Diff/ImageDiffContentView.swift` / `Features/Diff/AsyncDecodedImageDiffPreview.swift` — Image diff rendering.
- `Features/Diff/SubmoduleDiffContentView.swift` — Submodule change rendering.

#### History

- `Features/History/Screens/HistorySplitViewController.swift` / `Features/History/Screens/HistorySplitView.swift` — Native three-pane split view for the History tab (commit list, files, diff).
- `Features/History/Columns/CommitHistorySidebar.swift` — Commit list sidebar.
- `Features/History/Components/CommitRow.swift` / `Features/History/Components/CommitDetailsHeader.swift` — Commit row and detail header.
- `Features/History/Columns/ChangedFilesColumn.swift` / `Features/History/Columns/HistoryFilesColumn.swift` / `Features/History/Components/HistoryFileRow.swift` — Changed-files columns and rows.
- `Features/History/Components/HistoryDiffContent.swift` — Diff content for a selected historical file.
- `Features/History/HistoryHandler.swift` — History list selection and pagination state.
- `Features/History/Sheets/CreateBranchFromCommitSheet.swift`, `Features/History/Sheets/CreateTagSheet.swift`, `Features/History/Sheets/ReorderCommitsSheet.swift`, `Features/History/Sheets/ResetToCommitSheet.swift`, `Features/History/Sheets/SquashCommitsSheet.swift` — History action sheets.

#### Branches

- `Features/Branches/BranchDialogPresenter.swift` — Coordinates branch-related modal sheets and pickers.
- `Features/Branches/BranchCompareViewModel.swift` — Drives the branch comparison sheet.
- `Features/Branches/BranchesViewModel.swift` — Drives the branch list, switching, renaming, deletion, validation, and stash guards.
- `Features/Branches/Screens/BranchesViewController.swift` — Native branch list view controller.
- `Features/Branches/Components/BranchCellView.swift` — Branch row cell.
- `Features/Branches/Windows/CreateBranchWindowController.swift`, `Features/Branches/Windows/RenameBranchWindowController.swift`, `Features/Branches/Windows/DeleteBranchWindowController.swift`, `Features/Branches/Windows/CompareBranchWindowController.swift` — Branch action windows.
- `Features/Branches/Sheets/StashAndSwitchSheetController.swift` / `Features/Branches/Sheets/UpdateFromDefaultSheetController.swift` — Stash-and-switch and update-from-default sheets.

#### Conflicts

- `Features/Conflicts/ConflictsDialogView.swift` — Conflict resolution dialog.
- `Features/Conflicts/UnmergedFileRow.swift` — Row for a conflicted file with resolution options.

#### Repository

- `Features/Repository/CreateRepositorySheet.swift` / `Features/Repository/CreateRepositoryWindowController.swift` / `Features/Repository/CloneRepositoryWindowController.swift` — New and clone repository windows.
- `Features/Repository/RepositoryBranchDisplayFormatter.swift` — Formatting helpers for branch names in the UI.

#### Repository settings

- `Features/RepositorySettings/RepositorySettingsViewController.swift` / `Features/RepositorySettings/RepositorySettingsViewModel.swift` / `Features/RepositorySettings/RepositorySettingsWindowController.swift` — Repository settings (remote URL, external editor, terminal).

#### Stash

- `Features/Stash/StashManagementViewController.swift` — Window controller for listing and managing stashes.
- `Features/Stash/StashManagementViewModel.swift` — Drives the stash list and apply/drop actions.

#### Onboarding

- `Features/Onboarding/OnboardingView.swift` / `Features/Onboarding/OnboardingViewModel.swift` / `Features/Onboarding/OnboardingWindowController.swift` / `Features/Onboarding/WelcomeStepView.swift` / `Features/Onboarding/ConfigureGitStepView.swift` — First-launch onboarding flow.

#### Settings

- `Features/Settings/SettingsEnvironment.swift` — Composition context that assembles settings ViewModels and pane controllers.
- `Features/Settings/SettingsPaneViewController.swift` — Base controller for settings panes.
- `Features/Settings/Panes/*/*SettingsPaneController.swift` / `Features/Settings/Panes/*/*SettingsViewModel.swift` — One pane controller and ViewModel per settings category (Git, Integrations, Appearance, Notifications, Prompts, Advanced, Accessibility).

### Toolbar

- `Toolbar/MainToolbarController.swift` — Builds and owns the native unified `NSToolbar`, hosting SwiftUI toolbar items.
- `Toolbar/ContextToolbarCluster.swift` — Contextual toolbar cluster.
- `Toolbar/BranchPicker/BranchToolbarButton.swift` / `Toolbar/BranchPicker/BranchPullDownMenuContent.swift` / `Toolbar/BranchPicker/BranchesPickerPopover.swift` / `Toolbar/BranchPicker/BranchesViewControllerWrapper.swift` — Branch picker in the toolbar.
- `Toolbar/RepositoryPicker/RepositoryMenuButton.swift` / `Toolbar/RepositoryPicker/RepositoryPickerDialog.swift` / `Toolbar/RepositoryPicker/RepositoryPickerRow.swift` — Repository selector in the toolbar.
- `Toolbar/Sync/SyncMenuButton.swift` / `Toolbar/Sync/SyncToolbarButtonStyle.swift` / `Toolbar/Sync/PushToolbarCard.swift` — Sync controls.
- `Toolbar/Styling/ToolbarCard.swift` / `Toolbar/Styling/ToolbarItemStyle.swift` / `Toolbar/Styling/ConditionalToolbarItemStyle.swift` — Toolbar item/card styling.

### Shared

- `Shared/Components/ChangedFileRow.swift` — Reusable file row used across changes and history.
- `Shared/Components/LoadingPlaceholder.swift` — Loading placeholder views.
- `Shared/Formatters/AppFormatters.swift` — Shared formatters (relative dates, etc.).
- `Shared/Motion/Motion.swift` / `Shared/Motion/AppKitMotion.swift` — Motion/animation helpers.

### DesignSystem

- `DesignSystem/LiquidGlass.swift` — Liquid Glass background modifier.

## App Layer

`Sources/GimMac/App/` contains the AppKit application lifecycle and composition root.

- `App/AppDelegate.swift` — Application delegate and composition root; wires all Application ports to their Infrastructure implementations.
- `App/MainMenuFactory.swift` — Constructs the main menu bar.
- `App/AboutWindowFactory.swift` — Constructs the About window.
- `App/NSWorkspaceExternalEditorService.swift` — Platform service for opening files in external editors.

## Settings / Preferences seam

App-wide preferences follow the same layering as Git operations:

- `Application/Models/AppSettingsValues.swift` — `AppSettingsStoring` protocol plus value types (`ApplicationTheme`, `UncommittedChangesStrategy`, `DateFormat`/`TimeFormat`/`NumberFormat`, `CustomIntegration`). Application stays storage-agnostic.
- `Infrastructure/Persistence/UserDefaults/UserDefaultsAppSettingsStore.swift` — `UserDefaults`-backed implementation; the only place keys/defaults live.
- App-layer system services implement the remaining Application ports where AppKit / system frameworks are required: `AppKitThemeController` (`ThemeApplying` → `NSApp.appearance`), `UserNotificationAuthorizer` (`NotificationAuthorizing` → `UNUserNotificationCenter`), `NSWorkspaceShellService` (`ShellLaunching`), `NSWorkspaceExternalEditorService` (`ExternalEditorOpening`).
- `Presentation/Features/Settings/` — one `@Observable` ViewModel and one AppKit pane controller per Settings pane, assembled through `SettingsEnvironment` at the composition root (`AppDelegate`).

Global Git identity / `init.defaultBranch` go through `GitConfigService`, not `UserDefaults`. The service pins `HOME` to its configured `homeURL` so `--global` is isolatable in tests. See `docs/settings-implementation-plan.md` for the full design and rollout.

## Test Strategy

- **Unit tests** (`Tests/GimMacTests/`): Domain logic, parser logic, error mapping, ViewModel state transitions.
- **Integration tests** (`Tests/GimMacIntegrationTests/`): real temporary git repositories for command semantics.
- **UI tests** (`UITests/GimMacUITests/`): smoke flows for launch, shell visibility, and key interaction entry points. Run only when explicitly requested or during release validation.

All feature PRs must keep unit + relevant integration tests passing by default. Run UI tests when explicitly requested or during release validation.
