# Stash Changes

## Purpose

Temporarily save uncommitted changes so the user can switch context.

## User Actions

- Stash all changes on the current branch.
- Overwrite an existing Desktop stash after confirmation.

## Business Logic

- Desktop-created stash entries are identified by a marker containing the branch name (`!!GitHub_Desktop<branch>`).
- Only one Desktop-managed stash per branch is kept; creating a new stash drops the old one.
- Untracked files are staged before stashing so they are included.
- A confirmation is shown before overwriting an existing stash.
- If there are no local changes, no stash is created.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Stage untracked files | Stage untracked | `git add -- <untracked-files>` |
| Create stash | Push stash | `git stash push -m "!!GitHub_Desktop<branch>"` |
| Drop old stash | Drop stash | `git stash drop <stash>` |

## Edge Cases

- No local changes.
- Existing Desktop stash on the branch.
- Stash creation fails in an unborn repository.
- Untracked files present.

## Relevant Tests

- Test area: stash creation
- Behavior verified: Desktop stash identified; untracked files included; overwrite behavior.
- Edge case covered: CLI-created stash entries ignored; unborn repository.
