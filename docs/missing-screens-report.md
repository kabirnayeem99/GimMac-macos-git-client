# Missing Screens & Features Report

Comparison of GitHub Desktop screen inventory ([github-desktop-screens.md](github-desktop-screens.md))
against the current GimMac codebase. Updated 2026-06-11.

Scope: pure-Git operations only (no GitHub API/auth), per the source inventory.

> Done screens/features removed. This file now tracks only what remains.

---

## Yet to be implemented

| # | Doc Screen | Status | Notes |
|---|---|---|---|
| 8 | **Stash Screen** | ❌ Missing | only auto-stash-on-switch (`StashAndSwitchSheetController`). No stash list/manage screen. Backend supports single stash only (`fetchStash` returns one) |

---

## Detail

### ❌ Stash management screen (doc §8)

- List stashes, apply/pop/drop from UI.
- Only single-stash backend + auto-stash-on-switch exists today.
- `fetchStash` returns one stash — needs multi-stash listing.

---

## Suggested priority

1. **Stash management screen** — top remaining gap (multi-stash backend + list/apply/pop/drop UI)
