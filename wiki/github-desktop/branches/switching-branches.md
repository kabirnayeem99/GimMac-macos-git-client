# Switching Branches

## Purpose

Move the working directory to a different branch.

## User Actions

- Select a branch from the branch menu.
- Choose how to handle uncommitted changes when switching.

## Business Logic

- The user can configure the default behavior for uncommitted changes:
  - Ask every time.
  - Always stash on the current branch.
  - Always bring changes to the new branch.
- If bringing changes would overwrite local files, the app can create a transient stash, check out the branch, and then pop the stash.
- Detached HEAD, unborn branch, or protected branch forces the "bring changes" behavior.
- Submodules are updated recursively after checkout.
- The current branch's protected status is cleared after switching.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Switch branch | Checkout branch | `git checkout <branch>` |
| Switch to remote branch | Create tracking branch | `git checkout <remote/branch> -b <local-name>` |
| Handle uncommitted changes | Stash / checkout / pop | `git stash push`, `git checkout <branch>`, `git stash pop` |
| Update submodules | Submodule update | `git submodule update --init --recursive` |

## Edge Cases

- Local changes would be overwritten.
- Existing local branch with the same name as a remote branch.
- Target branch is already checked out.
- Repository is in a merge/rebase/cherry-pick state.
- Submodule update fails.
- Detached HEAD or unborn branch.

## Relevant Tests

- Test area: checkout
- Behavior verified: local branches are created from remotes; submodules are initialized.
- Edge case covered: same branch name on multiple remotes.

## Notes

Conceptual equivalent: the app may use `git checkout` rather than `git switch`.
