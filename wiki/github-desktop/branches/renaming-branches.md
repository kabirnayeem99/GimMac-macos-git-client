# Renaming Branches

## Purpose

Rename a local branch.

## User Actions

- Choose rename from the branch menu.
- Enter the new name.

## Business Logic

- The default branch and protected branches cannot be renamed.
- If the new name differs only by case, a force rename is used.
- Any Desktop-managed stash entry associated with the old branch name is moved to the new name.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Rename branch | Rename branch | `git branch -m <old> <new>` |
| Force case-only rename | Force rename | `git branch -M <old> <new>` |
| Move stash entry | Recreate stash on new branch | `git commit-tree`, `git stash store`, `git stash drop` |

## Edge Cases

- New name already exists.
- Case-only rename.
- Default/protected branch rename blocked.
- Stash entry exists for the branch.

## Relevant Tests

- Test area: branch rename
- Behavior verified: rename moves branch and stash entry.
- Edge case covered: case-only rename.
