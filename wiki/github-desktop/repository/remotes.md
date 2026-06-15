# Remotes

## Purpose

Manage the remote repositories associated with a local repository.

## User Actions

- View configured remotes.
- Add, remove, or update a remote URL.
- Set the default remote (prefer `origin`).
- Add an upstream remote for forks.

## Business Logic

- The default remote is `origin` if present; otherwise the first available remote is used.
- Remotes are listed alphabetically.
- Removing a remote that does not exist is handled gracefully.
- When a forked repository is selected, an upstream remote is added automatically if one does not exist and the user is asked if there is a conflict.
- Remote URLs are validated when changed.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| List remotes | List remotes | `git remote -v` |
| Add remote | Add remote | `git remote add <name> <url>` |
| Remove remote | Remove remote | `git remote remove <name>` |
| Update remote URL | Set remote URL | `git remote set-url <name> <url>` |
| Discover default branch | Update remote HEAD | `git remote set-head -a <remote>` |
| Add fork upstream | Add upstream remote | `git remote add upstream <url>` |

## Edge Cases

- No remotes configured (unpublished repository).
- Duplicate remote name.
- Invalid remote URL.
- Remote URL uses HTTPS, SSH, or `git:` protocol.
- Upstream remote name already exists with a different URL.

## Relevant Tests

- Test area: remote management
- Behavior verified: remotes are listed alphabetically; promisor/partial-clone remotes are preserved.
- Edge case covered: multiple remotes and URL matching.
