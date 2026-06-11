# Missing Screens & Features Report

Comparison of GitHub Desktop screen inventory ([github-desktop-screens.md](github-desktop-screens.md))
against the current GimMac codebase. Updated 2026-06-11.

Scope: pure-Git operations only (no GitHub API/auth), per the source inventory.

> Done screens/features removed. This file now tracks only what remains.

---

## Yet to be implemented

_All tracked screens from the source inventory are now implemented._

---

## Detail

### ✅ Stash management screen (doc §8) — done 2026-06-11

- Multi-stash backend: `StashProviding.fetchAllStashes` (`git stash list --format=%gd%x00%s%x00%ct`)
  plus ref-targeted `applyStash(ref:)` / `popStash(ref:)` / `dropStash(ref:)` in `GitStashProvider`.
- AppKit sheet `StashManagementViewController` (Branch → "Manage Stashes…") lists every stash
  (message / branch / date) with Apply / Pop / Drop; Drop confirms via `NSAlert`.
- Driven by `StashManagementViewModel`; integration coverage in `GitStashIntegrationTests`.
