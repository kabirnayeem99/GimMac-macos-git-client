# Conflict Resolution

## Purpose

Help the user resolve conflicts and finish an in-progress merge, rebase, cherry-pick, or stash pop.

## User Actions

- View conflicted files in a dedicated dialog.
- Open a file in the configured editor or shell.
- Choose "Use ours" or "Use theirs" for a conflicted file.
- Mark a file as resolved.
- Continue or abort the operation.

## Business Logic

- For merges, only conflicted files need to be staged because Git has already staged the rest.
- For rebase/cherry-pick, resolved files must be staged before continuing.
- Binary conflicts can be resolved by choosing either side.
- Aborting a partially resolved operation shows a confirmation.
- The app verifies conflict markers are gone before continuing.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Choose ours/theirs | Checkout side | `git checkout --ours|--theirs -- <file>` |
| Mark resolved | Stage file | `git add -- <file>` |
| Continue merge | Commit | `git commit` |
| Continue rebase | Continue rebase | `git rebase --continue` |
| Continue cherry-pick | Continue cherry-pick | `git cherry-pick --continue` |
| Continue stash pop | Resolve and drop stash | `git stash drop` (after resolution) |
| Abort operation | Abort | `git merge --abort`, `git rebase --abort`, `git cherry-pick --abort` |

## Edge Cases

- User tries to continue with unresolved conflicts.
- Aborting after some files are resolved.
- Stash pop conflicts leave the stash in place.
- Cherry-pick with all conflicts resolved but no tracked changes requires an empty commit.

## Relevant Tests

- Test area: conflict resolution
- Behavior verified: manual choices applied; markers verified before continuing.
- Edge case covered: mixed manual resolutions and binary conflicts.
