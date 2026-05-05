# AGENTS.md

## Lean-CTX

Prefer `lean-ctx` for terminal reads/searches to reduce token usage and keep outputs compact.

Use:

- `lean-ctx -c "<command>"` for normal compressed command output.
- `lean-ctx -c --raw "<command>"` when full uncompressed output is required.

Command preferences:

- Prefer `lean-ctx -c "rg --files"` over raw `find` for file discovery.
- Prefer `lean-ctx -c "rg <pattern> <path>"` over raw `grep` for text search.
- Prefer `lean-ctx -c "sed -n 'N,Mp' <file>"` for targeted file reads.
- Prefer `lean-ctx -c "git <...>"` for Git command output summaries.

## jCodeMunch + Lean-CTX Workflow

Use `jcodemunch` as the primary symbol/index layer and `lean-ctx` as the primary
shell/file-compression layer.

Preferred flow:

1. Resolve repository identity with `resolve_repo(path)`.
2. If not indexed or stale, run `index_folder(path, incremental=true)`.
3. Use symbol-aware tools first (`search_symbols`, `get_symbol_source`,
   `get_context_bundle`) before raw text search.
4. Use `lean-ctx` for focused surrounding reads and compressed shell output.
5. After edits, refresh index coverage with `index_file` for touched files.

Compatibility rules:

- Avoid duplicate discovery: run symbol search first, raw grep second.
- Use jcodemunch to choose what to inspect, then `lean-ctx` to inspect the exact lines.
- For multi-file refactors, assess impact first via symbol-level context tools.

## Purpose

This file defines how AI agents and contributors should work in this repository.

The project is a native macOS Git client with a GitHub Desktop-like workflow, implemented with Swift and AppKit-first UI. The MVP is local Git-first, uses system/Homebrew Git, supports whole-file staging, and delegates GPG/SSH signing to Git configuration.

## Source of Truth

Read these files before making architectural changes:

1. `PLAN.md` — product scope, phases, architecture, technical stack, Git operations, risks.
2. `DESIGN.md` — UI layout, state model, diff model, UX rules, security model.
3. `AGENTS.md` — contributor and agent rules.
4. `docs/` — long-form technical documentation.
5. `wiki/` — user-facing or knowledge-base style notes.

When instructions conflict, follow this order:

```text
AGENTS.md > DESIGN.md > PLAN.md > docs/ > wiki/ > inline code comments
```

Do not silently change the locked decisions in `PLAN.md`. Update `PLAN.md` and `DESIGN.md` together when changing product scope, architecture, platform target, or Git behavior.

## Locked Project Decisions

- Platform: macOS 14+ only.
- Language: Swift-first.
- UI: AppKit-first.
- Architecture: MVVM with Observation.
- Git engine: process-based Git CLI wrapper.
- Git binary: system/Homebrew Git for MVP.
- MVP: local Git first.
- Staging: whole-file staging in MVP.
- Signing: support both GPG and SSH signing through Git config.
- GitHub login: V1, not MVP.
- Do not use Electron, WebView UI, or libgit2 for MVP.
- Do not use GitHub Desktop branding, icons, logos, or copied assets.

## Commit Convention

Use semantic commits.

Format:

```text
<type>(optional-scope): <short imperative summary>
```

Examples:

```text
feat(git): add status porcelain parser
fix(diff): prevent stale diff render after repo switch
perf(ui): debounce repository refresh events
docs(plan): clarify detached HEAD behavior
refactor(appkit): split repository window controller
test(git): add merge conflict fixture
chore(repo): add gitattributes and gitignore
```

Allowed types:

- `feat` — user-visible feature
- `fix` — bug fix
- `perf` — performance improvement
- `refactor` — behavior-preserving code change
- `test` — tests only
- `docs` — documentation only
- `style` — formatting only, no behavior change
- `chore` — tooling, repo maintenance, build config
- `build` — build system, Xcode project, dependencies
- `ci` — CI/CD changes
- `security` — security hardening

Rules:

- Use imperative mood: `add parser`, not `added parser`.
- Keep subject under 72 characters where possible.
- Body is required for non-trivial changes.
- Mention risk, migration, and user-visible behavior in the body.
- Do not mix unrelated changes in one commit.
- Do not commit generated build artifacts.
- Do not commit signing keys, certificates, tokens, `.env`, or local machine paths.

Good commit body:

```text
feat(git): add whole-file staging

Adds GitService methods for staging and unstaging full files using
`git add -- <file>` and `git restore --staged -- <file>`.

Hunk-level staging remains out of MVP scope.
```

## Branch Naming

Use short lowercase branch names:

```text
feat/status-parser
fix/detached-head-display
perf/diff-rendering
security/git-config-sanitization
docs/readme
```

## Clean Code Rules

Write boring, obvious code.

Prefer:

- Small types.
- Small functions.
- Explicit names.
- Protocol boundaries for services.
- Value types for models.
- Typed errors.
- Dependency injection for testability.
- Async work outside the main thread.
- Main-thread UI updates only.

Avoid:

- God view controllers.
- Hidden global state.
- Stringly typed Git state.
- Shell command strings.
- Clever abstractions before the second real use case.
- Long methods that mix parsing, process execution, and UI updates.
- Silent failures.

## Architecture Rules

Use this flow:

```text
AppKit View / ViewController
  -> ViewModel (@Observable)
    -> Service Protocol
      -> GitClient / Store / Parser
```

Rules:

- ViewControllers coordinate views and bind to ViewModels.
- ViewModels own UI state and user actions.
- Services own domain operations.
- `GitClient` only runs Git commands and returns raw `GitResult`.
- Parsers convert raw output into typed models.
- UI must not parse raw Git output.
- UI must not directly run `Process`.
- Services must not import AppKit unless there is a hard platform reason.

### Clean Architecture Enforcement

Use explicit layer boundaries:

```text
Presentation (AppKit Views/ViewControllers + ViewModels)
  -> Domain (entities, use cases, service protocols)
    -> Data/Infrastructure (Git process runner, parsers, persistence, API clients)
```

Rules:

- `Presentation` depends on `Domain` abstractions only.
- `Domain` must not depend on `AppKit`, networking, storage, or process execution details.
- `Data/Infrastructure` implements `Domain` protocols and can depend on Foundation/system APIs.
- Dependency injection wiring is done at app startup/composition root.
- Do not import `AppKit` in `Domain` or parser modules.
- Do not import concrete data services directly into view controllers; go through ViewModels + protocols.

## Git Command Rules

Never execute through shell strings.

Good:

```swift
try await gitClient.run(["status", "--porcelain=v1", "-z"], in: repoURL, timeout: 10)
```

Bad:

```swift
git status --porcelain=v1 -z
/bin/sh -c "git status"
```

Rules:

- Always pass arguments as an array.
- Always use `--` before file paths.
- Always capture stdout and stderr separately.
- Always convert non-zero exits into typed `GitAppError`.
- Always run Git commands away from the main thread.
- Add cancellation for commands tied to selected repository or selected file.
- Add timeout for commands that can hang.
- Treat repository `.git/config` as untrusted input.

## Security Rules

Do not trust repository-controlled configuration.

Specifically:

- Do not execute `core.hooksPath` scripts.
- Do not honor repo-defined `core.fsmonitor` executables.
- Do not execute repo-defined `filter.*`, `diff.*`, or `merge.*` drivers without explicit user consent.
- Do not log tokens, auth headers, signing material, or remotes containing credentials.
- Store credentials only in Keychain.
- Do not implement cryptographic signing manually.
- Delegate GPG and SSH signing to Git/GPG/ssh-agent/pinentry.

## Performance Rules

The app must feel native and fast.

Required practices:

- Debounce filesystem refreshes.
- Lazy-load diffs only for selected files.
- Cancel stale diff/status/fetch operations when selection changes.
- Avoid rendering huge diffs fully.
- Use a large-diff fallback when a diff exceeds the configured threshold.
- Do not block the main thread with Git, parsing, filesystem scanning, or network work.
- Use Instruments for real performance issues instead of guessing.
- Prefer incremental UI updates where practical.
- Avoid excessive allocation in diff parsing hot paths.
- Avoid repeatedly constructing attributed strings for unchanged diff lines.

Main performance risk areas:

- Diff rendering.
- Large repository status refresh.
- Branch list and history rendering.
- File watching.
- Process spawning frequency.

## Memory and CPU Rules

For Swift:

- Prefer value types for immutable models.
- Avoid retain cycles in closures: use `[weak self]` where needed.
- Keep ViewModels free of large raw text buffers when parsed models are enough.
- Release stale diff data when repository or file selection changes.
- Do not cache unbounded command output.
- Use `autoreleasepool` around Objective-C-heavy loops if needed.

For Objective-C interop:

- Use ARC.
- Do not use manual retain/release unless maintaining legacy code that already requires it.
- Avoid strong reference cycles between delegates, controllers, and blocks.
- Delegates should usually be `weak`.
- Blocks capturing `self` should usually use weak/strong dance when retained.
- Wrap allocation-heavy Objective-C loops in `@autoreleasepool`.
- Avoid creating temporary `NSString`, `NSAttributedString`, and `NSDictionary` objects in tight rendering loops without measurement.
- Keep bridging between Swift collections and Foundation collections out of hot paths where possible.

Example Objective-C block pattern:

```objc
__weak typeof(self) weakSelf = self;
[self.loader loadWithCompletion:^{
    __strong typeof(weakSelf) self = weakSelf;
    if (!self) { return; }
    [self refreshUI];
}];
```

## Apple UI/UX Rules

Follow native macOS expectations.

Required Apple references for AppKit, macOS UI, Xcode, and performance work:

- AppKit overview: https://developer.apple.com/documentation/appkit
- `NSApplicationDelegate` app lifecycle: https://developer.apple.com/documentation/appkit/nsapplicationdelegate
- `NSWindow`: https://developer.apple.com/documentation/appkit/nswindow
- `NSWindowController`: https://developer.apple.com/documentation/appkit/nswindowcontroller
- `NSSplitViewController`: https://developer.apple.com/documentation/appkit/nssplitviewcontroller
- `NSViewController`: https://developer.apple.com/documentation/appkit/nsviewcontroller
- `NSTableView`: https://developer.apple.com/documentation/appkit/nstableview
- `NSCollectionView`: https://developer.apple.com/documentation/appkit/nscollectionview
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- Menus: https://developer.apple.com/design/human-interface-guidelines/menus
- Sheets: https://developer.apple.com/design/human-interface-guidelines/sheets
- Lists and tables: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables
- Xcode build system: https://developer.apple.com/documentation/xcode
- Performance and metrics: https://developer.apple.com/documentation/xcode/performance-and-metrics
- Addressing CPU bottlenecks: https://developer.apple.com/documentation/xcode/addressing-cpu-bottlenecks
- Gathering memory-use information: https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use

Use:

- AppKit controls where they fit naturally.
- Standard toolbar behavior.
- Standard keyboard shortcuts.
- Native menus.
- Native dialogs and sheets.
- System colors and dynamic appearance.
- VoiceOver labels for controls.
- Clear focus behavior for keyboard users.
- Destructive action confirmation for force push, reset, squash, and abort operations.

Avoid:

- Web-app style UI inside AppKit.
- Custom controls where native controls work.
- Blocking modal alerts for routine status messages.
- Vague errors like `Something went wrong`.
- Hiding detached HEAD state.
- Showing ignored files as if Git is tracking them.

Error messages should say:

1. What failed.
2. Why Git says it failed, if known.
3. What the user can do next.

## Comments Rule

Comment intent, not obvious syntax.

Good comments:

```swift
// Git returns `HEAD` here when the repository is detached.
// The UI must show a detached-state warning instead of an empty branch name.
```

```swift
// Use `--force-with-lease` only. Raw `--force` can overwrite remote work
// created after the user's last fetch.
```

Bad comments:

```swift
// Increment i by 1
// Create a string
// Call the function
```

Rules:

- Public types and non-obvious services should have short documentation comments.
- Complex Git behavior needs a comment with the reason.
- Security-sensitive code needs comments explaining the threat model.
- Do not comment every line.
- Remove stale comments immediately when behavior changes.

## Testing Rules

Required test coverage:

- Git output parsers.
- `GitAppError` mapping.
- Status parser with staged, unstaged, untracked, renamed, deleted, and conflicted files.
- Detached HEAD behavior.
- Ahead/behind count parsing.
- Whole-file stage/unstage service behavior.
- ViewModel behavior with mock services.
- UI flows for repository selection, changed-file selection, diff display, and commit action states.

Use real temporary repositories for integration tests where needed.

Every user-visible feature must include:

- unit tests for business logic/parsers/ViewModels,
- integration tests for Git behavior when command semantics are involved,
- UI tests for the primary success path and at least one failure state.

Do not require a real GitHub account for MVP tests.

Testing gates:

- Do not merge feature work without passing unit tests.
- Do not merge UI-affecting work without passing relevant UI tests.
- Do not merge Git-behavior changes without integration coverage for the changed command flow.

## Documentation Rules

Use these folders deliberately.

### `docs/`

Use for contributor-facing technical docs.

Examples:

```text
docs/architecture.md
docs/git-client.md
docs/diff-rendering.md
docs/security.md
docs/testing.md
docs/release.md
```

Rules:

- Keep docs precise and implementation-oriented.
- Update docs in the same PR as code changes.
- Link back to `PLAN.md` or `DESIGN.md` when changing major behavior.
- Prefer diagrams only when they clarify architecture.

### `wiki/`

Use for user-facing or knowledge-base style notes.

Examples:

```text
wiki/how-signing-works.md
wiki/troubleshooting-gpg.md
wiki/git-basics.md
wiki/faq.md
```

Rules:

- Write for app users, not internal contributors.
- Avoid leaking implementation details unless needed for troubleshooting.
- Keep language clear and short.
- Do not put secrets, tokens, screenshots with private repository names, or personal paths.

## README Rules

`README.md` should stay high-level.

It should include:

- What the app is.
- Current status.
- Platform target.
- Core architecture.
- MVP scope.
- Build instructions.
- Documentation links.
- Legal/branding note.

Do not turn README into a full architecture document. Put details in `PLAN.md`, `DESIGN.md`, and `docs/`.

## Pull Request Rules

Every PR should include:

- Summary.
- Screenshots or screen recording for UI changes.
- Testing done.
- Risks.
- Follow-ups, if any.

PRs that change Git behavior must mention exact Git commands added or changed.

PRs that affect UI state must mention affected ViewModels.

PRs that affect docs must update links if file names changed.

## Do Not Do

- Do not introduce Electron.
- Do not introduce libgit2 in MVP.
- Do not use GitHub Desktop name/assets.
- Do not run shell commands via `/bin/sh -c`.
- Do not block the main thread with Git or parsing work.
- Do not add hunk-level staging before whole-file staging is stable.
- Do not make GitHub login a blocker for local Git MVP.
- Do not store tokens outside Keychain.
- Do not add broad dependencies for small tasks.
