# GimMac — AI Orchestration & Agent Routing

Native macOS Git client. Swift + AppKit-first. Clean Architecture + MVVM with Observation framework.

---

## Source of Truth

Read these before making architectural changes:

1. `AGENTS.md` — contributor rules, architecture rules, security model, commit convention
2. `PLAN.md` — product scope, phases, locked decisions, Git operations, risks
3. `DESIGN.md` — UI layout, state model, diff model, UX rules
4. `docs/architecture.md` — dependency rules, module layout, test strategy

**Conflict resolution:** `AGENTS.md > DESIGN.md > PLAN.md > docs/ > inline comments`

---

## GitHub Desktop Reference Codebase

Path: `github-desktop-codebase/`

This is the GitHub Desktop source (Electron + TypeScript). **Do not copy its code** — GimMac is Swift/AppKit and the locked decisions explicitly forbid Electron. Use this folder as a reference only.

**When to consult it:**
- Designing a Git UX flow (commit panel, branch switching, merge conflict UI, history view) — look at how GitHub Desktop structures the user interaction, then adapt to native AppKit patterns.
- Unsure how to handle a specific Git edge case (detached HEAD display, rebase state, partial-merge recovery) — check GitHub Desktop's implementation for the correct user-facing behavior.
- Planning a new feature where the correct UX behavior is ambiguous — GitHub Desktop's approach is a good baseline before designing the native equivalent.

**How to use it:**
1. Find the relevant TypeScript component or model in `github-desktop-codebase/app/src/`.
2. Read the logic and UX intent — ignore the React/Electron mechanics.
3. Implement the equivalent behavior in Swift using AppKit patterns and the GimMac architecture.

**Key paths inside the reference codebase:**
- `app/src/models/` — Git domain models (branches, commits, diffs, status)
- `app/src/lib/git/` — Git command wrappers (equivalent to GimMac's Data layer)
- `app/src/ui/` — UI components by feature area

---

## Mandatory Task Sequence

1. Read the relevant source-of-truth doc for the area you are touching
2. Invoke the matching skill (table below) if the task hits one
3. Select the right sub-agent (table below)
4. Make changes — sub-agent reads code via lean-ctx + jcodemunch
5. After changes: update relevant doc + agent `.md` if behavior changed

---

## Architecture Layers

```
Presentation (AppKit Views/ViewControllers + @Observable ViewModels)
  → Domain (entities, service protocols, GitAppError, value objects)
    → Data/Infrastructure (ProcessGitClient, parsers, CoreData persistence)
```

Rules:
- `Presentation` imports only `Domain` abstractions
- `Domain` has no `AppKit`, no process execution, no network, no storage
- `Data` implements `Domain` protocols; may use Foundation/system APIs
- Dependency injection is wired at composition root (app startup only)

---

## Agent Selection Guide

| Task Type | Agent |
|---|---|
| ViewModel, service protocols, Clean Architecture, MVVM, Observation | `gimmac-ops` |
| Unit tests, integration tests, mock patterns, TemporaryGitRepository | `tester` |
| Swift language features, protocols, generics, async/await, actors | `swift-language` |
| AppKit performance, main thread, diff rendering, debounce, cancellation | `appkit-performance` |
| Tech debt, architecture violations, test coverage gaps, data-source tracing | `tech-debt-tracker` |
| AppKit components, SwiftUI screens, HIG, accessibility, system colors | `design-system` |
| Xcode project, xcodegen, SwiftLint, CI/GitHub Actions, build scripts | `xcode-build` |

### Model Tiering

Match model to reasoning load — Opus is not free. Each agent pins its tier in its `.md` frontmatter.

| Tier | Agents | Why |
|---|---|---|
| **Opus 4.8** (`claude-opus-4-8`) | `gimmac-ops`, `swift-language`, `design-system`, `appkit-performance` | Architecture, concurrency correctness, HIG/perf judgment — reasoning-heavy, errors are expensive |
| **Sonnet 4.6** (`claude-sonnet-4-6`) | `tech-debt-tracker`, `tester`, `xcode-build` | Patterned/mechanical: audit checklists, fixture tests, YAML/config — no deep reasoning, faster + cheaper |
| **Haiku 4.5** (`claude-haiku-4-5-20251001`) | trivial mechanical edits only (rename, comment strip, format tweak) — typically `cavecrew-builder`, not a pinned agent | Near-zero reasoning; use for bounded, obvious edits where correctness is visually checkable |

Rule: when a Sonnet agent hits genuine reasoning (a subtle concurrency bug, an architecture call), it should hand back to the main thread to escalate to an Opus agent rather than guess.

---

## Skill Selection Guide

Project skills live in `.claude/skills/`. Invoke the matching skill (via the Skill tool, or
`/<skill-name>`) **before** writing code in that area — skills carry platform rules, HIG
guidance, and review checklists the sub-agents must follow. Skills and sub-agents compose:
skill supplies domain knowledge, sub-agent does the wiring.

| Task / Trigger | Skill |
|---|---|
| Swift 6+ language patterns, concurrency, actors, value types | `swift` |
| macOS code review, AppKit bridging, macOS 26 APIs, platform best practices | `macos` |
| AppKit/SwiftUI design, Liquid Glass, animations, visual polish | `design` |
| SwiftUI secondary screens (per locked decisions) | `swiftui` |
| Main-thread, diff rendering, debounce, large-file handling | `performance` |
| TDD, characterization tests, snapshot tests, test infra | `testing` |
| Secure storage, biometric/Keychain, network security review | `security` |
| Pre-release / App Store submission critical review | `release-review` |
| App Store listing, screenshots, ASO, marketing copy | `app-store` |
| Pricing, tiers, trials, monetization strategy | `monetization` |
| Privacy policy, EULA, GDPR/CCPA, App Store legal | `legal` |
| Market research, PRD, UX specs, product planning | `product` |
| User acquisition, analytics, press outreach, indie growth | `growth` |
| Scaffold logging/analytics/settings/persistence/etc. boilerplate | `generators` |
| SwiftData persistence patterns | `swiftdata` |

Out of scope for GimMac (macOS Git client) unless a feature explicitly calls for it:
`ios`, `watchos`, `visionos`, `mapkit`, `core-ml`, `apple-intelligence`.

Always-available global skills: `/code-review`, `/simplify`, `/verify`, `/run`,
`/security-review` — use for diff review, cleanup, and manual verification.

---

## Sub-Agent Protocol

All sub-agents:
- Run on the model pinned in their `.md` frontmatter (see Model Tiering) — not Opus by default
- May run in an isolated git worktree for independent changes
- Must read `AGENTS.md` before making architectural changes
- Must update their own `.md` file and relevant docs when behavior changes
- Must not violate the locked decisions listed below

---

## Orchestration & Token Discipline

Rules for whoever spawns sub-agents (the main thread). Context is the scarce resource — protect it.

1. **Delegate reads, keep conclusions.** For "where is X / what calls Y / map this dir", spawn
   `cavecrew-investigator` or `Explore` — the sub-agent burns the search tokens and returns a small
   answer; your main context stays lean. Do not read whole files inline when a finder can return the
   `file:line` you need. (jcodemunch + lean-ctx are wired — use `get_file_outline` → `get_symbol_source`
   over a full `Read`.)

2. **Scope sub-agent prompts tight.** A vague prompt makes the agent over-explore and return a fat
   result. Name the exact deliverable. ✅ "Find the 3 call sites of `fetchDiff`, return `file:line`."
   ❌ "Look into how diffs work."

3. **Prefer read-only agents for investigation/audit/review.** No `Write`/`Edit` (e.g.
   `tech-debt-tracker`, `cavecrew-investigator`) → the agent can't wander into edit-debug loops that
   balloon context. Give any new auditor/reviewer `tools: Read, Grep, Glob, Bash` only.

4. **Demand structured returns.** A fixed result block (e.g. gimmac-ops `RESULT/FILES/REVIEW/FOLLOWUPS`,
   tech-debt-tracker `SUMMARY/TOP`) is parsed once. Prose forces the main thread to re-read to extract
   facts. When spawning via Workflow, use the `schema` option to force a typed return.

5. **Spawn independent agents in ONE message.** Reviewing 5 files / 5 dimensions → 5 agents at once,
   not serial. Same total tokens, ~5× faster wall-clock, and each runs in its own context so main
   stays small. Only serialize when stage N genuinely needs all of stage N-1.

6. **`register_edit` after edits** (already in gimmac-ops) keeps the jcodemunch index fresh → fewer
   stale-lookup retries on the next search.

---

## Locked Decisions

Never change without also updating `PLAN.md` and `DESIGN.md`:

- Platform: macOS 14+ only
- Language: Swift-first
- UI: AppKit-first; SwiftUI only for simple isolated secondary screens
- Architecture: MVVM with Observation framework (`@Observable`)
- Git engine: process-based CLI wrapper (`ProcessGitClient`) only
- Git binary: system/Homebrew Git — no bundled Git in MVP
- MVP: local Git first; no GitHub login
- Staging: whole-file only in MVP; hunk-level is V1
- Signing: delegate entirely to Git/GPG/ssh-agent; never implement manually
- No Electron, no libgit2, no GitHub Desktop branding

---

## Flow Diagram

```
User Prompt
    ↓
Claude Code (Sonnet) — reads CLAUDE.md + memory
    ↓ (if task matches a skill → invoke skill for domain rules)
    ↓ (if task matches a specialized agent)
Spawns sub-agent (Opus) with agent .md as system prompt
    ↓ (optionally in isolated git worktree)
Sub-agent reads code via lean-ctx + jcodemunch
Sub-agent writes code + updates its own docs
    ↓
Results returned to main agent → reported to user
```
