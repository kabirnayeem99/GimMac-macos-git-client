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
- UI tests: smoke flows for launch, shell visibility, and key interaction entry points.

All feature PRs must keep unit + relevant integration/UI tests passing.
