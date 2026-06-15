# Current Branch Display

## Purpose

Show the user which branch is checked out and summarize its relationship to the remote.

## User Actions

- View current branch name in the toolbar.
- See ahead/behind counts relative to the upstream branch.
- See protected-branch warnings.
- Open the branch menu to switch or create branches.

## Business Logic

- The current branch is refreshed on repository selection and after sync operations.
- States include: on a branch, detached HEAD, or unborn branch (no commits yet).
- The default branch is labeled and listed first in branch menus.
- Ahead/behind counts are computed against the upstream tracking branch.
- If the branch is protected, a warning appears in the commit and push areas.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Refresh branch state | Status / branch lookup | `git status --branch --porcelain=2 -z`, `git branch --format=...` |
| Compute ahead/behind | Count commits | `git rev-list --left-right --count <branch>...<upstream>` |
| Discover default branch | Inspect remote HEAD / refs | `git remote set-head -a <remote>`, `git for-each-ref` |

## Edge Cases

- Detached HEAD.
- Unborn branch (no commits).
- No upstream configured.
- Remote branch has been deleted.
- Multiple remotes with the same branch name.

## Relevant Tests

- Test area: branch tip state
- Behavior verified: unborn, detached, and valid branch states are reported.
- Edge case covered: repositories with a `HEAD` file on disk.
