# Rebasing Branches

## Purpose

Replay the current branch's commits on top of another branch.

## User Actions

- Choose "Rebase current branch".
- Select the base branch.
- Continue, skip, or abort the rebase if conflicts occur.

## Business Logic

- A warning is shown if rebasing will rewrite commits that have already been pushed.
- The rebase backend is forced to the merge backend.
- Progress is reported as commits are replayed.
- If a replayed commit has no tracked changes after resolving conflicts, it is skipped.
- Conflicts enter the shared conflict resolution flow.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Start rebase | Rebase onto base | `git -c rebase.backend=merge rebase <base-branch> <target-branch>` |
| Continue rebase | Continue | `git rebase --continue [--no-verify]` |
| Skip commit | Skip | `git rebase --skip [--no-verify]` |
| Abort rebase | Abort | `git rebase --abort` |
| Root rebase | Rebase from root | `git rebase --root` |

## Edge Cases

- Conflicts during replay.
- Unresolved conflicts when continuing.
- External rebase state detected on refresh.
- Root-commit rebase.
- Branch has already been pushed.

## Relevant Tests

- Test area: rebase
- Behavior verified: replay commits; abort/continue after conflicts.
- Edge case covered: root commit and external rebase state.
