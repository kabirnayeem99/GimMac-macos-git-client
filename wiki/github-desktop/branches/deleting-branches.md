# Deleting Branches

## Purpose

Remove local or remote branches that are no longer needed.

## User Actions

- Delete a local branch from the branch menu.
- Optionally delete the remote branch at the same time.

## Business Logic

- The default branch and protected branches cannot be deleted or renamed.
- Deleting the currently checked-out branch first switches to the default branch or the most recent branch.
- Remote branch deletion is optional.
- If the remote branch was already deleted, the local remote-tracking ref is cleaned up.
- Branches checked out in other worktrees are guarded.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Delete local branch | Delete branch | `git branch -D <name>` |
| Delete remote branch | Delete remote ref | `git push <remote> :<branch>` |
| Find worktree checkouts | List worktrees | `git worktree list --porcelain -z` |

## Edge Cases

- Deleting the checked-out branch.
- Deleting the default or protected branch (blocked).
- Remote branch already deleted.
- Branch has unmerged commits (force delete).
- Branch is checked out in another worktree.

## Relevant Tests

- Test area: branch deletion
- Behavior verified: local and remote deletion; cleanup of remote-tracking refs.
- Edge case covered: delete checked-out branch switches first.
