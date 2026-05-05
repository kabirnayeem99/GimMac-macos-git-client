# Native Git Desktop

A native macOS Git client inspired by the GitHub Desktop workflow, built with Swift and AppKit-first UI.

![GimMac logo](docs/assets/gimmac-logo.png)

This project is not GitHub Desktop, is not affiliated with GitHub, and does not use GitHub branding, icons, logos, or copied assets.

## Status

Early planning / implementation stage.

Branding assets are currently sourced from `docs/assets/gimmac-logo.png` and the app icon set in
`Sources/GimMac/Resources/Assets.xcassets/AppIcon.appiconset`.

The MVP focuses on local Git workflows first. GitHub login and deeper GitHub API integration are planned for V1, after the local Git experience is stable.

## Goals

- Native macOS Git client.
- GitHub Desktop-like workflow.
- AppKit-first interface.
- Fast local Git operations.
- Clear diff and staging workflow.
- Safe defaults for dangerous Git operations.
- GPG and SSH commit signing through existing Git configuration.

## Platform

- macOS 14.0+
- Swift
- AppKit-first UI
- Observation-based MVVM
- SwiftData for app metadata where appropriate
- System/Homebrew Git for MVP

## MVP Scope

The MVP includes:

- Add local repository.
- Repository switcher.
- Current branch display.
- Detached HEAD display.
- Changed files list.
- Unified diff viewer.
- Whole-file stage / unstage.
- Commit summary and description.
- Commit signing through Git config.
- Branch list.
- Create branch.
- Checkout branch.
- Basic merge.
- Conflict detection.
- Fetch / pull / push for existing remotes.
- Force push only via `--force-with-lease` with explicit confirmation.
- Preferences for Git path, author identity, theme, and signing status.

Out of MVP:

- GitHub login.
- Clone from GitHub account.
- Pull request creation.
- Hunk-level staging.
- Full commit graph.
- Tags.
- Submodule operations.

## Architecture

High-level flow:

```text
AppKit View / ViewController
  -> ViewModel (@Observable)
    -> Service Protocol
      -> GitClient / Store / Parser
```

Rules:

- UI does not run Git commands directly.
- UI does not parse raw Git output.
- Git commands run through a process-based `GitClient`.
- Parsers convert raw Git output into typed models.
- Services expose domain operations to ViewModels.
- ViewModels own screen state and user actions.

## Git Strategy

The app uses the system or Homebrew Git binary in MVP.

Examples of core commands:

```bash
git status --porcelain=v1 -z
git diff -- <file>
git diff --cached -- <file>
git add -- <file>
git restore --staged -- <file>
git commit -m "summary" -m "body"
git switch <branch>
git switch -c <branch>
git merge <branch>
git fetch --prune
git pull --ff-only
git push
git push --force-with-lease
```

Git commands must be executed with argument arrays, not shell strings.

## Signing

The app does not implement cryptographic signing itself.

GPG and SSH signing are delegated to Git and the user's existing Git/GPG/SSH configuration.

Example GPG config:

```bash
git config --global commit.gpgsign true
git config --global user.signingkey <key-id>
git config --global gpg.format openpgp
```

Example SSH signing config:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

## Safety Rules

- Never use raw `git push --force`.
- Use `git push --force-with-lease` only after explicit confirmation.
- Treat repository `.git/config` as untrusted input.
- Do not execute repo-controlled hooks, filters, diff drivers, or merge drivers without explicit user consent.
- Store future GitHub tokens only in Keychain.
- Do not log secrets, tokens, auth headers, or remotes containing credentials.

## Performance Rules

The app should feel like a native macOS app.

Important rules:

- Do not block the main thread with Git work.
- Debounce repository refreshes.
- Lazy-load diffs only for the selected file.
- Cancel stale Git commands when repository or selection changes.
- Avoid rendering huge diffs fully.
- Use a file-too-large fallback for large diffs.
- Use Instruments for real performance problems.

## Repository Documentation

Main docs:

- `PLAN.md` — scope, phases, architecture, risks.
- `DESIGN.md` — UI, state models, diff model, UX and security rules.
- `AGENTS.md` — contributor and AI-agent rules.

Suggested folders:

```text
docs/   contributor-facing technical docs
wiki/   user-facing notes and troubleshooting
```

Examples:

```text
docs/architecture.md
docs/git-client.md
docs/diff-rendering.md
docs/security.md
docs/testing.md
wiki/troubleshooting-gpg.md
wiki/git-basics.md
wiki/faq.md
```

## Build

This project uses XcodeGen for deterministic project generation.

Prerequisites:

- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- [SwiftLint](https://github.com/realm/SwiftLint) for strict lint checks

Commands:

```bash
xcodegen generate
xcodebuild -project GimMac.xcodeproj -scheme GimMac -destination 'platform=macOS' clean build
```

Strict gate (warnings-as-errors + SwiftLint):

```bash
brew install swiftlint
./scripts/strict-ci.sh
```

## Development Rules

Use semantic commits:

```text
feat(git): add status porcelain parser
fix(diff): prevent stale diff render after repo switch
perf(ui): debounce repository refresh events
docs(plan): clarify detached HEAD behavior
```

Keep changes small and scoped. Do not mix unrelated refactors with feature work.

## License

TBD.

Choose a license before public release.
