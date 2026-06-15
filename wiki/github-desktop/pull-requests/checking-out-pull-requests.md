# Checking Out Pull Requests

## Purpose

Download and check out a pull request branch locally for review.

## User Actions

- Select a pull request to check out.
- Open a PR from a notification or URL.

## Business Logic

- For a PR from a fork, a dedicated fork remote is added.
- A local branch named `pr/<number>` is created and checked out.
- If a local branch already tracks the PR branch, it is reused.
- Existing local branches with the same name as a remote branch are handled.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Add fork remote | Add remote | `git remote add <name> <url>` |
| Fetch PR ref | Fetch ref | `git fetch <remote> <ref>` |
| Create local PR branch | Checkout tracking branch | `git checkout -b pr/<number> <remote>/<branch>` |

## Edge Cases

- PR branch has been deleted.
- Fork repository has been deleted.
- Remote add fails.
- Local branch name conflicts.
- Auth errors.

## Relevant Tests

- Test area: PR checkout
- Behavior verified: fork remote added; local branch created.
- Edge case covered: PR branch deleted.
