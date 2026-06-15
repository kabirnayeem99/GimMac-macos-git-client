# Restore Stash

## Purpose

Restore stashed changes to the working directory.

## User Actions

- View stashed changes.
- Restore (pop) a stash.
- Discard a stash.

## Business Logic

- Restoring pops the stash by default.
- If popping produces conflicts, the stash may remain until conflicts are resolved.
- Discarding a stash shows a confirmation by default.
- Renaming a branch moves the associated Desktop stash entry to the new branch name.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Pop stash | Pop stash | `git stash pop --quiet <stash>` |
| Drop stash | Drop stash | `git stash drop <stash>` |
| Move stash on rename | Recreate stash | `git commit-tree`, `git stash store`, `git stash drop` |

## Edge Cases

- Pop conflicts leave stash in place.
- Stash entry does not exist.
- Local changes already present when popping.
- Renaming branch with stash.

## Relevant Tests

- Test area: stash pop/drop
- Behavior verified: pop restores changes; drop removes stash.
- Edge case covered: conflicts when popping.
