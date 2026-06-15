# Publish Branch / Repository

## Purpose

Share a local repository or branch that does not yet exist on the remote.

## User Actions

- Publish an unpublished branch.
- Publish the entire repository to GitHub.

## Business Logic

- Publishing a branch adds an upstream tracking ref.
- Publishing a repository creates a remote named `origin`, creates an initial `.gitattributes` commit if needed, pushes the default branch, then pushes the current branch.
- For a repository with no remote, the publish dialog asks for name, description, and visibility.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Add remote | Add origin | `git remote add origin <url>` |
| Initial commit | Commit .gitattributes | `git add .gitattributes && git commit -m "Initial commit"` |
| Push default branch | Push default | `git push -u origin <default-branch>` |
| Push current branch | Publish branch | `git push -u origin <current-branch>` |

## Edge Cases

- Repository already has a remote.
- Network/auth failure during publish.
- Default branch name mismatch.
- Repository has no commits.

## Relevant Tests

- Test area: publish flow
- Behavior verified: publishing sets upstream and pushes branches.
- Edge case covered: repositories with no initial commit.
