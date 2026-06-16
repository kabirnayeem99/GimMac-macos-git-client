# GimMac Multi-Agent Engineering Guide

This is the canonical instruction file for AI coding agents working in GimMac. `CLAUDE.md` and
`GEMINI.md` include this file and must not duplicate its rules.

## 1. Project Agent System

GimMac is a native macOS 14+ Git client. The implementation is Swift-first, uses AppKit and SwiftUI,
follows MVVM with Observation, and runs Git through a process-based command client.

The orchestrator is [.agents/engineering_lead.md](.agents/engineering_lead.md). It classifies the
task, creates the plan, selects the minimum useful specialists, integrates their work, enforces the
review loop, and decides whether the Definition of Done is met.

### Detected Project Stack

| Technology | Status | Evidence / Rule |
|---|---|---|
| macOS | Used | Deployment target is macOS 14.0 |
| Swift | Used | Main implementation language; strict concurrency is complete |
| Objective-C interoperability | Supported | Apply ARC, weak-delegate, block-capture, and autorelease rules when encountered |
| SwiftUI | Used | Presentation screens and hosted content |
| AppKit | Used | Application lifecycle, windows, controllers, menus, and native macOS integration |
| UIKit | Not used | Do not introduce it in this macOS app |
| Observation | Used | ViewModels use `@Observable`; do not introduce Combine-based `ObservableObject` by default |
| Combine | Not detected | Do not introduce it without a concrete need |
| Swift Concurrency | Used | `async/await`, tasks, actors, `@MainActor`; complete strict checking |
| Core Data | Used | `CoreDataRepositoryPersistence` and related persistence code |
| SwiftData | Not detected | Do not migrate or introduce it without an approved architecture change |
| The Composable Architecture | Not detected | Do not introduce it |
| XCTest | Used | Unit, integration, and UI test targets |
| Swift Testing | Not detected | Follow existing XCTest conventions |
| XcodeGen | Used | `project.yml` is the Xcode project source of truth |
| Tuist | Not used | Do not introduce it |
| Swift Package Manager | No root manifest detected | Add packages through `project.yml` only when justified |
| CocoaPods | Not used | Do not introduce it |
| SwiftLint | Used | `.swiftlint.yml` and strict CI script |
| SwiftFormat | Not configured | Do not claim a format command exists |

### Source of Truth

When instructions conflict, use this order:

```text
AGENTS.md > DESIGN.md > PLAN.md > docs/architecture.md > docs/ > wiki/ > inline comments
```

Read `DESIGN.md` and `PLAN.md` before changing product behavior, Git semantics, architecture, or UI
flows. Update both when changing a locked platform, architecture, product-scope, or Git decision.

### Locked Project Decisions

- macOS 14+ only.
- Swift-first, AppKit-first; SwiftUI is allowed where already established or appropriate for hosted
  presentation content.
- MVVM with Observation (`@Observable`).
- Presentation depends on Domain abstractions; Domain does not depend on AppKit, process execution,
  networking, or persistence implementations; Data/Infrastructure implements Domain protocols.
- Git runs through argument arrays using system/Homebrew Git. Never use shell command strings.
- Local Git first; GitHub login is not an MVP dependency.
- Whole-file staging in MVP; hunk-level staging is deferred.
- Signing is delegated to Git, GPG, ssh-agent, and pinentry.
- No Electron, WebView-based primary UI, libgit2, or copied GitHub Desktop branding/assets.

### Repository Exploration

- Use jCodeMunch as the primary code-navigation and symbol layer.
- Start with `resolve_repo`, then `plan_turn`; index incrementally if stale.
- Use symbol search and symbol source before raw text search or whole-file reads.
- Use `lean-ctx -c "<command>"` for compact shell output and `--raw` only when full output is needed.
- Prefer `rg` over `grep`/`find` for focused discovery.
- After edits, register or reindex touched files.
- The `github-desktop-codebase/` directory is reference-only. Study its UX and Git behavior; never
  copy its Electron/TypeScript implementation or assets.

## 2. Core Principle

Use the minimum number of agents needed to complete the task well. Do not call every agent by default.

- Prefer small, focused, reviewable changes.
- Do not rewrite unrelated code or replace working architecture without a demonstrated need.
- Match existing patterns before adding abstractions or dependencies.
- Prefer one primary Swift type per file, especially under `Sources/GimMac/Presentation`. Create a
  dedicated file for each new SwiftUI `View`, `ViewModifier`, `PreferenceKey`, AppKit bridge,
  controller, coordinator, view model, or other reusable UI type so agents can reference compact files
  and symbols directly.
- Keep one owner per file during parallel work.
- Run independent specialist tasks in parallel only when they do not overlap.
- Senior Engineer and Tester provide quality control; Engineering Lead owns final integration.
- Update documentation only when behavior, setup, architecture, commands, public APIs, or important
  limitations change.
- The user receives the integrated result, not internal agent transcripts or debates.

## 3. Agent Files

| Agent | File | Primary Ownership |
|---|---|---|
| Engineering Lead | [.agents/engineering_lead.md](.agents/engineering_lead.md) | Orchestration, classification, architecture, scope, integration, completion |
| Product Manager | [.agents/product_manager.md](.agents/product_manager.md) | Requirements, user value, business rules, acceptance criteria, scope |
| UI/UX Designer | [.agents/ui_ux_designer.md](.agents/ui_ux_designer.md) | Apple HIG, AppKit/SwiftUI UX, accessibility, states, interaction design |
| Software Engineer | [.agents/software_engineer.md](.agents/software_engineer.md) | Focused implementation, fixes, refactors, build/lint remediation |
| Senior Engineer | [.agents/senior_engineer.md](.agents/senior_engineer.md) | Skeptical review, architecture, Swift/concurrency, performance, warnings |
| Tester | [.agents/tester.md](.agents/tester.md) | XCTest strategy, regression coverage, integration tests, verification |
| Documentation Writer | [.agents/documentation_writer.md](.agents/documentation_writer.md) | Concise user/developer documentation updates |

Specialist prompts are reusable role instructions. They inherit this file and must not override its
locked decisions, safety rules, command policy, or Definition of Done.

### Shared Project Skills

The canonical skill library remains in `.claude/skills/`. The `.agents/skills` path points to that
same library so Claude, Codex, and Kimi use one maintained copy:

```text
.agents/skills -> ../.claude/skills
```

- Codex scans `.agents/skills` for repository skills and supports symlinked skill folders.
- Kimi scans `.agents/skills` as its generic project-level skill root.
- Claude continues to use `.claude/skills` directly.
- Do not copy skill directories into `.codex/skills` or `.kimi/skills`; that would create duplicate
  sources and drift.
- Each specialist prompt lists its relevant skills. Load only the skills whose trigger matches the
  current task; do not load every skill by default.
- If a tool does not automatically discover a skill, read the referenced `SKILL.md` directly from
  `.agents/skills` (or the canonical `.claude/skills` target).

## 4. Default Workflow

1. Engineering Lead receives the task.
2. Engineering Lead inspects the live repository, classifies the task, selects agents, and publishes
   a short implementation plan and acceptance criteria.
3. Product Manager defines requirements only when behavior is ambiguous, feature-level, or requires
   business/scope decisions.
4. UI/UX Designer provides implementable guidance only when UI, interaction, accessibility, or user
   states are involved.
5. Software Engineer implements the smallest complete change.
6. Senior Engineer reviews meaningful code changes for correctness, build warnings, lint,
   architecture, concurrency, performance, accessibility, and Apple-platform behavior.
7. Software Engineer fixes blocker/major findings and justified minor findings.
8. Tester writes or updates tests, verifies acceptance criteria, and runs the relevant test targets.
9. Software Engineer fixes test failures caused by the change.
10. Senior Engineer performs a final review only when fixes were significant or the task is high-risk.
11. Documentation Writer updates existing docs only when required.
12. Engineering Lead checks the Definition of Done and gives the final summary.

### Task Classification

- **SIMPLE:** bounded, low-risk, obvious behavior; usually Engineering Lead plus one implementer, and
  Senior Engineer only when code risk warrants it.
- **MODERATE:** several coupled edits, a logic bug, or one specialist concern; use two to four agents.
- **COMPLEX:** feature, architecture, cross-layer, UI workflow, or broad refactor; create a staged plan.
- **HIGH_RISK:** credentials, signing, untrusted Git config, destructive Git, data deletion, persistence
  migration, production CI, security, or serious crash/data-loss potential.

## 5. Routing Matrix

| Task | Recommended Route |
|---|---|
| Tiny bug fix | Engineering Lead -> Software Engineer -> Senior Engineer when meaningful |
| Logic bug | Engineering Lead -> Software Engineer -> Senior Engineer -> Tester |
| New feature | Engineering Lead -> Product Manager -> UI/UX Designer if UI -> Software Engineer -> Senior Engineer -> Tester -> Documentation Writer if needed |
| UI polish | Engineering Lead -> UI/UX Designer -> Software Engineer -> Senior Engineer |
| Accessibility issue | Engineering Lead -> UI/UX Designer -> Software Engineer -> Senior Engineer -> Tester when automatable |
| Refactor | Engineering Lead -> Senior Engineer -> Software Engineer -> Tester |
| Performance issue | Engineering Lead -> Senior Engineer -> Software Engineer -> Tester |
| Concurrency issue | Engineering Lead -> Senior Engineer -> Software Engineer -> Tester |
| Persistence change | Engineering Lead -> Product Manager if behavior changes -> Senior Engineer -> Software Engineer -> Tester -> Documentation Writer if needed |
| Test coverage task | Engineering Lead -> Tester -> Senior Engineer |
| Build/lint failure | Engineering Lead -> Software Engineer -> Senior Engineer |
| Documentation update | Engineering Lead -> Documentation Writer |
| Architecture change | Engineering Lead -> Product Manager -> Senior Engineer -> Software Engineer -> Tester -> Documentation Writer |
| High-risk Git/security change | Engineering Lead -> Product Manager if behavior changes -> Senior Engineer -> Software Engineer -> Tester -> independent final Senior Engineer review -> Documentation Writer if needed |

The route is guidance, not a requirement to invoke every listed role. Skip any agent that adds no value.

## 6. Review Loop Rules

- Maximum two normal review/fix rounds.
- A round is: review or test feedback -> implementation fixes -> targeted verification.
- Additional rounds are allowed only for build failure, test failure, crash risk, data-loss risk,
  security issue, or serious Apple-platform correctness issue.
- Do not reopen resolved subjective preferences.
- Senior Engineer requests changes only for concrete correctness, architecture, performance,
  accessibility, maintainability, warning, or platform concerns.
- Approve when remaining findings are acceptable nits and record them rather than looping.
- If a blocker cannot be resolved, stop and report the exact evidence, attempted fixes, and required
  user decision. Never fabricate success.

### Review Severity

- **blocker:** build/test failure, crash, data loss, security risk, or severe platform violation.
- **major:** likely bug, incorrect behavior, architecture violation, serious performance issue, or
  broken accessibility.
- **minor:** maintainability issue, unclear naming, weaker structure, or missing non-critical edge case.
- **nit:** formatting, style, or small readability improvement.

## 7. Build, Test, and Lint Commands

These commands are verified from `project.yml`, repository scripts, README, and CI. Run targeted
checks during iteration. Do not run UI tests by default unless requested or doing release validation.

### Prerequisites

```bash
brew install xcodegen swiftlint
```

### Generate Xcode Project

```bash
xcodegen generate
```

`project.yml` is the source of truth. Do not manually edit
`GimMac.xcodeproj/project.pbxproj`; regenerate it.

### Build

```bash
xcodebuild \
  -project GimMac.xcodeproj \
  -scheme GimMac \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

Build and launch for manual verification:

```bash
./scripts/build-and-run.sh
```

This launch script terminates stale GimMac processes and removes the app's saved window state. Use it
only when manual app verification is appropriate.

### Strict Build and Lint Gate

```bash
./scripts/strict-ci.sh
```

This runs strict SwiftLint and an `xcodebuild clean build` with Swift/Clang warnings as errors and
complete Swift concurrency checking.

Lint only:

```bash
swiftlint lint --strict --config .swiftlint.yml
```

### Unit Tests

```bash
xcodebuild test \
  -project GimMac.xcodeproj \
  -scheme GimMac \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:GimMacTests
```

### Integration Tests

```bash
xcodebuild test \
  -project GimMac.xcodeproj \
  -scheme GimMac \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:GimMacIntegrationTests
```

### UI Tests

```bash
xcodebuild test \
  -project GimMac.xcodeproj \
  -scheme GimMac \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:GimMacUITests
```

### Format

No SwiftFormat configuration or repository format command was detected.

```text
TODO: Add an exact format command only if the project adopts SwiftFormat or another formatter.
```

## 8. Definition of Done

A task is not done until:

- The requirement is understood.
- Scope is limited to the user request.
- The implementation is small and reviewable.
- Existing architecture and style are respected.
- Code builds successfully, or the reason it could not be built is documented.
- Tests pass, or failures are documented with cause.
- Lint passes, or remaining warnings are documented and justified.
- Important edge cases are handled.
- UI follows Apple platform conventions when UI is involved.
- Accessibility is considered when UI is involved.
- Senior Engineer blocker and major issues are fixed.
- Regression tests are added for important bug fixes when practical.
- Documentation is updated when behavior, setup, architecture, commands, or public APIs change.
- The final response lists changed files, commands run, results, and remaining risks.

### Apple Engineering Quality Bar

- UI state mutations happen on the main actor/main thread.
- Git, parsing, persistence, filesystem scanning, and expensive rendering do not block the main thread.
- Async work tied to repository or selection state is cancellable and stale results are ignored.
- Swift concurrency isolation and `Sendable` requirements are respected; do not silence warnings.
- SwiftUI state ownership uses the smallest correct wrapper and does not create duplicate sources of
  truth. Existing Observation patterns take precedence over introducing Combine.
- SwiftUI and AppKit presentation code is split into token-efficient files by primary type. Tiny
  private helper views may stay with their parent only when they are not reused, do not obscure the
  parent's behavior, and keeping them inline improves locality.
- AppKit delegates are normally weak; retained closures avoid reference cycles.
- Core Data work uses the correct context/queue and does not leak persistence details into Domain.
- Native controls, system colors, keyboard navigation, VoiceOver labels, dark mode, localization, and
  empty/loading/error/success states are considered where relevant.
- Use Instruments or reproducible evidence before adding performance complexity.
- Git arguments are arrays, `--` precedes file paths, stdout/stderr are separate, commands have timeout
  and cancellation, and failures map to typed `GitAppError` values.
- Repository `.git/config` and content are untrusted. Do not execute repository-controlled hooks,
  fsmonitor, filters, diff drivers, or merge drivers without explicit consent.
- Credentials belong in Keychain and credential-bearing remotes or signing material must not be logged.

## 9. Safety and Permission Rules

Do not run destructive commands without explicit user approval.

Destructive actions include:

- deleting files outside the task scope;
- resetting Git history, hard reset, destructive clean, or force-pushing;
- removing dependencies without approval;
- deleting databases, repositories, or user data;
- changing signing credentials, entitlements, notarization, or production secrets;
- modifying production configuration or systems;
- making network calls that mutate external systems.

Before a risky action, explain:

1. What will be done.
2. Why it is needed.
3. What could go wrong and what can be rolled back.
4. The exact command or action requiring approval.

Do not bypass sandbox, permission, approval, or security mechanisms. Use the safest workflow that can
complete the task. Do not revert user changes or unrelated dirty-worktree changes. Never log or commit
tokens, credentials, signing keys, certificates, `.env` files, or personal machine paths.

## 10. Final Response Format

Use this format for future implementation tasks, omitting empty sections only for trivial work:

```text
## Summary

- <completed outcome>

## Files Changed

- <path>: <purpose>

## Commands Run

- `<exact command>`

## Results

- Build: passed | failed | not run (reason)
- Tests: passed | failed | not run (reason)
- Lint: passed | failed | not run (reason)

## Review Notes

- <important review result or none>

## Documentation

- <updated files or not needed with reason>

## Remaining Risks

- <risk or none>

## Next Steps

- <only genuinely out-of-scope follow-up, or none>
```

Be concise and factual. Report exact commands and outcomes. Do not claim checks passed when they were
not run.
