# Opening Repositories

## Purpose

Add an existing local Git repository to the app so it can be tracked, refreshed, and worked on.

## User Actions

- Choose **Add existing repository** and select a folder.
- Drag a folder from the file system into the app window.
- Open the selected repository in Finder/Explorer, the configured shell, or the configured editor.
- Remove the repository from the app list.

## Business Logic

- The selected path is validated as a Git repository. If it is not, an error message is shown and the repository is not added.
- If the path is inside another Git repository, a warning is shown suggesting submodules.
- If the chosen folder already is a repository, the user is offered to add it directly.
- Repositories are persisted in an internal list. Removing a repository from the list does not delete files from disk.
- If a repository is moved or deleted on disk, it is marked as missing and Git operations are skipped until the path is restored.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Validate selected path | Check repository type | `git rev-parse --git-dir` |
| Refresh after adding | Repository refresh | `git status`, `git remote -v`, `git branch -a`, `git stash list` |
| Open in external tools | N/A | N/A |

## Edge Cases

- Path is not a Git repository.
- Path is missing or inaccessible.
- Path is a subdirectory of an existing repository.
- Repository was previously added and is now missing.
- Unsafe directory (e.g. `safe.directory` restriction) blocks validation.

## Relevant Tests

- Test area: repository validation and adding
- Behavior verified: non-Git paths are rejected; missing repositories are marked missing.
- Edge case covered: path inside another repository.

## Notes

Conceptual equivalent: the app may use repository-type checks rather than a single CLI command.
