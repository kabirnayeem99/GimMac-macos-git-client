# Conflict Detection

## Purpose

Recognize when a Git operation has left the repository in a conflicted state.

## User Actions

- See a banner or dialog indicating conflicts.
- Open conflicted files from the Changes tab or conflict dialog.

## Business Logic

- Conflicts are detected during status refresh.
- Conflict states include merge, rebase, cherry-pick, and stash-pop conflicts.
- Each conflicted file shows conflict-marker counts.
- Binary/image conflicts are identified separately.
- The operation cannot continue until all conflicts are resolved.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Detect conflicts | Status / diff check | `git status --porcelain=2 -z`, `git diff --check` |
| Identify binary conflicts | Check attributes | `git check-attr merge`, `git diff --numstat` |

## Edge Cases

- `assume-unchanged` or `skip-worktree` files block checkout/stash.
- Conflicts from stash pop without `MERGE_HEAD`.
- Binary conflicts with no text markers.
- Deleted-by-them conflicts.
- Files added in both branches.

## Relevant Tests

- Test area: conflict detection
- Behavior verified: status parses conflicted files; stash-pop conflicts detected.
- Edge case covered: binary/image conflicts and deleted-by-them scenarios.
