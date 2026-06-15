# Creating Branches

## Purpose

Create a new branch to start isolated work.

## User Actions

- Open the create-branch dialog.
- Enter a branch name.
- Choose a start point (current branch, another branch, or a commit).
- Optionally check out the new branch immediately.

## Business Logic

- Branch names are sanitized to be valid Git refs; invalid characters are replaced or rejected.
- Duplicate branch names are rejected.
- Creating a branch from a protected branch automatically brings uncommitted changes along.
- If the start point is a remote branch, the new branch is created without tracking the upstream fork.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Create branch | Create branch | `git branch <name> [<start-point>] [--no-track]` |
| Create and checkout | Create and switch | `git checkout -b <name> [<start-point>]` |

## Edge Cases

- Invalid branch name.
- Branch already exists.
- Start point is a remote branch.
- Uncommitted changes present.
- Repository is in detached HEAD or unborn state.

## Relevant Tests

- Test area: branch creation
- Behavior verified: branches are created from the selected start point.
- Edge case covered: protected branch behavior and no-track creation from remote branch.

## Notes

Conceptual equivalent: branch names are validated using `git check-ref-format` rules.
