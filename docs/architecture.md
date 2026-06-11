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

## Test Strategy

- Unit tests: Domain logic, parser logic, error mapping, ViewModel state transitions.
- Integration tests: real temporary git repositories for command semantics.
- UI tests: smoke flows for launch, shell visibility, and key interaction entry points (run only when explicitly requested or during release validation).

All feature PRs must keep unit + relevant integration tests passing by default. Run UI tests when explicitly requested or during release validation.

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
