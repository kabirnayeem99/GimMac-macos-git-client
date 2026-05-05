# GEMINI.md - GimMac Project Instructions

This file contains foundational mandates for AI agents working on GimMac. These rules take precedence over general defaults.

## Project Context
GimMac is a native macOS Git client with a GitHub Desktop-like workflow, implemented using Swift and AppKit.
- **Platform:** macOS 14+ only.
- **Language:** Swift-first.
- **UI:** AppKit-first (no Electron or WebView UI).
- **Architecture:** MVVM with Observation and Clean Architecture boundaries.
- **Git Engine:** Process-based Git CLI wrapper (no libgit2 for MVP).

## Core Mandates & Workflow

### Tooling Preferences
- **Lean-CTX:** ALWAYS prefer `lean-ctx` for terminal reads and searches.
  - `lean-ctx -c "<command>"` for compressed output.
  - `lean-ctx -c --raw "<command>"` for full output.
  - Prefer `rg` via `lean-ctx` over raw `find`/`grep`.
- **jCodeMunch:** Use as the primary symbol/index layer.
  1. `resolve_repo(path)` -> `index_folder(path, incremental=true)`.
  2. Use symbol-aware tools (`search_symbols`, `get_symbol_source`) before raw text search.
  3. Refresh with `index_file` after edits.

### Source of Truth Order
1. `AGENTS.md` / `GEMINI.md`
2. `DESIGN.md`
3. `PLAN.md`
4. `docs/`
5. `wiki/`

## Engineering Standards

### Architecture (Clean Architecture)
```text
Presentation (AppKit + ViewModels @Observable)
  -> Domain (Entities + Service Protocols)
    -> Data/Infrastructure (Git Runner + Parsers)
```
- **Presentation** depends on **Domain** abstractions ONLY.
- **Domain** must NOT depend on AppKit, networking, or process execution.
- **Data/Infrastructure** implements Domain protocols.
- **No AppKit imports** in Domain or Parser modules.

### Clean Code & Style
- **Boring Code:** Prefer small types, small functions, and explicit names.
- **Memory (Swift):** Value types for models; use `[weak self]` in closures.
- **Memory (Obj-C Interop):** Use ARC; avoid strong cycles; use `@autoreleasepool` in heavy loops.
- **Comments:** Comment *intent* and non-obvious behavior, not syntax. Remove stale comments.

### Git Command Rules
- **NEVER** use shell strings (e.g., `/bin/sh -c`).
- **ALWAYS** pass arguments as an array.
- **ALWAYS** use `--` before file paths.
- **ALWAYS** run Git commands off the main thread with timeouts and cancellation support.

### Commit & Branching
- **Semantic Commits:** `<type>(scope): <short imperative summary>`. (Types: feat, fix, perf, refactor, test, docs, style, chore, build, ci, security).
- **Branches:** Short lowercase names (e.g., `feat/status-parser`).

## UI/UX Standards
- **Native AppKit:** Use standard controls, toolbars, and menus. Follow Apple HIG.
- **No Web-style UI:** UI must feel native, not like a web app.
- **Errors:** Must state what failed, why (if known), and what to do next.

## Security & Performance

### Security
- **Do NOT** trust repo-controlled config (`core.hooksPath`, `core.fsmonitor`, `filter.*`).
- **Do NOT** log secrets, tokens, or credentials.
- **Keychain:** Use for all credential storage.
- **Signing:** Delegate GPG/SSH signing to Git/system agents; do not implement manually.

### Performance
- **Main Thread:** UI updates ONLY. No Git, parsing, or FS scanning.
- **Lazy Loading:** Load diffs only for selected files; cancel stale operations.
- **Debounce:** Filesystem refreshes must be debounced.

## Testing Standards
- **Coverage Required:** Parsers, Error Mapping, Status parsing, Ahead/Behind parsing, ViewModels.
- **Triad of Testing:**
  1. **Unit:** Business logic and parsers.
  2. **Integration:** Git command semantics (use real temp repos).
  3. **UI:** Primary success paths (AppKit-based).
- **Agent Policy:** Do not run UI tests by default; run only when release-focused or requested.

## Prohibitions (Locked Decisions)
- NO Electron, WebView, or libgit2.
- NO GitHub Desktop branding/assets.
- NO hunk-level staging in MVP (whole-file only).
- NO GitHub login as MVP blocker.
- NO blocking the main thread.
