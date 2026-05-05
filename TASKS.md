# TASKS.md

## Objective

Deliver MVP and V1 from `PLAN.md` using:

- Clean Architecture boundaries
- AppKit-first UI
- MVVM + Observation
- Strong automated testing (unit + UI + integration)

## Clean Architecture Rules (Enforced Per Task)

- `Domain` layer contains entities, value objects, use-case protocols, and domain errors only.
- `Data` layer implements repositories/services (Git process, parsing, persistence, Keychain, API).
- `Presentation` layer contains AppKit controllers/views + `@Observable` ViewModels.
- `Presentation` depends on `Domain` abstractions, never on concrete `Data` implementations.
- `Data` depends on `Domain` contracts and infrastructure.
- Composition root wires concrete dependencies at app startup.
- No Git process execution from UI layer.
- No raw parser logic in UI layer.

## Target Project Structure

```text
Sources/
  GimMac/
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

## Phase Backlog

## Phase 0: Foundations and Guardrails

- [x] Define module/folder layout for `Presentation`, `Domain`, `Data`, `Infrastructure`.
- [x] Add architecture decision docs in `docs/architecture.md` and dependency rule examples.
- [x] Add test targets: `GimMacTests`, `GimMacIntegrationTests`, `GimMacUITests`.
- [x] Add CI pipeline with required gates:
- [x] `xcodegen generate`
- [x] strict build (`xcodebuild` warnings-as-errors)
- [x] unit tests
- [x] UI tests (smoke subset)
- [x] integration tests (Git flows)

Tests:
- Unit: architecture boundary tests for dependency direction.
- UI: app launches, main split view exists.
- Integration: none.

## Phase 1: App Shell + Repository Context

- [x] Build AppKit shell (`NSSplitViewController`): repo/sidebar, changes list, diff pane, commit pane.
- [x] Create `RepositoryStore` in Domain (`Repository`, `RepositoryState` models).
- [x] Implement repository picker and recent repositories list.
- [x] Show current branch or detached HEAD display in toolbar/header.

Tests:
- Unit: `RepositoryStoreViewModel` state transitions.
- UI: select repository updates shell state and visible branch label.
- Integration: open temporary repository and verify detected root/branch.

## Phase 2: Git Client Core

- [ ] Implement `GitClientProtocol` in Domain.
- [ ] Implement `ProcessGitClient` in Data (`Process` wrapper, timeout, cancellation).
- [ ] Implement typed `GitAppError` mapping from exit code/stdout/stderr.
- [ ] Add command builder utilities to enforce argument-array execution and `--` path separator.

Tests:
- Unit: command building, error mapping, timeout/cancel behavior (mocked process layer).
- UI: surface process failure in user-facing error panel.
- Integration: run real `git rev-parse`, `git status` in temp repo.

## Phase 3: Status + Change Tracking

- [ ] Implement porcelain parser for `git status --porcelain=v1 -z`.
- [ ] Model `FileChange` with composite identity strategy for rename safety.
- [ ] Build changed-files ViewModel and list UI (added/modified/deleted/renamed/conflicted/untracked).
- [ ] Add debounced refresh triggers (focus + filesystem changes).

Tests:
- Unit: parser fixtures for all status combinations.
- UI: row badges/icons per file status and staged/unstaged sections.
- Integration: real repo status changes reflected correctly.

## Phase 4: Diff Viewer

- [ ] Implement diff use case and service calls:
- [ ] `git diff -- <file>`
- [ ] `git diff --cached -- <file>`
- [ ] Parse unified diff into `DiffFile` / `DiffHunk` / `DiffLine`.
- [ ] Build AppKit diff rendering with added/removed/context styling.
- [ ] Add large-file fallback threshold behavior.

Tests:
- Unit: diff parser fixtures, large-diff threshold logic.
- UI: selecting file updates diff pane; large diff shows fallback state.
- Integration: real changed file diff and staged diff retrieval.

## Phase 5: Staging + Commit

- [ ] Implement stage/unstage whole-file use cases:
- [ ] `git add -- <file>`
- [ ] `git restore --staged -- <file>`
- [ ] Commit use case (`git commit -m summary -m body`).
- [ ] Signing status detection from git config (`commit.gpgsign`, `gpg.format`, `user.signingkey`).
- [ ] Commit panel validation and error handling (`nothingToCommit`, signing failures).

Tests:
- Unit: commit form validation; stage/unstage/commit ViewModel behavior.
- UI: stage/unstage controls, commit button enablement, success/failure banners.
- Integration: create real commit in temp repo with expected message parts.

## Phase 6: Branching + Detached HEAD

- [ ] Branch list use case (`git branch --format=...`).
- [ ] Checkout/create branch use cases (`git switch`, `git switch -c`).
- [ ] Merge use case (`git merge <branch>`), conflict detection and conflict screen.
- [ ] Enforce detached HEAD policy in UI and push restrictions.

Tests:
- Unit: detached head display formatter, merge conflict state mapping.
- UI: branch picker, create branch flow, conflict state screen.
- Integration: real branch create/switch/merge with conflict scenario.

## Phase 7: Remote Operations (MVP Done)

- [ ] Fetch (`git fetch --prune`) and upstream-aware ahead/behind counts.
- [ ] Pull (`git pull --ff-only`) and push (`git push`).
- [ ] Force push with typed confirmation only (`git push --force-with-lease`).
- [ ] Clear remediation messages for auth failures and remote rejections.

Tests:
- Unit: ahead/behind parsing, force-push confirmation guard logic.
- UI: fetch/pull/push action feedback and confirmation dialog behavior.
- Integration: local bare-remote test harness for fetch/pull/push flows.

## Phase 8: V1 GitHub Integration

- [ ] OAuth flow and Keychain token storage.
- [ ] List/publish repositories and PR creation link flow.
- [ ] Clone via HTTPS first; optional SSH clone support.

Tests:
- Unit: API client request/response mapping with mocks.
- UI: auth state transitions and repository publishing forms.
- Integration: staged with mocked API environment first.

## Cross-Cutting Quality Tasks

- [ ] Accessibility: VoiceOver labels on all controls and keyboard-focus order.
- [ ] Performance budgets:
- [ ] status refresh debounce
- [ ] diff render thresholds
- [ ] cancellation of stale operations
- [ ] Security hardening:
- [ ] ignore/neutralize repo-controlled dangerous config paths (`core.hooksPath`, `core.fsmonitor`, `filter.*`)
- [ ] never log credentials/secrets
- [ ] keep credentials in Keychain only

Tests:
- Unit: security config sanitization rules.
- UI: accessibility identifiers and smoke navigation tests.
- Integration: large-repo and conflict scenario profiling fixtures.

## Definition of Done (Per Feature)

- [ ] Clean Architecture boundary respected (no forbidden dependencies).
- [ ] Unit tests added/updated and passing.
- [ ] UI tests added/updated and passing for user-visible flow.
- [ ] Integration test added for Git behavior where relevant.
- [ ] Strict build/lint passes.
- [ ] Docs updated (`PLAN.md`/`DESIGN.md`/`docs`) if behavior or architecture changed.
