# Repository List

## Purpose

Switch between and manage the repositories the app knows about.

## User Actions

- Select a repository to make it active.
- Filter/search the list.
- Remove a repository from the list.
- Open the selected repository in external tools.
- See repository state indicators (changed files count, ahead/behind, missing state).

## Business Logic

- Repositories are grouped by owner/account: GitHub.com, GitHub Enterprise, and Other.
- Recently opened repositories are surfaced.
- Selecting a repository triggers a full refresh and starts background fetching.
- If the repository is missing locally, it is shown with a warning and Git operations are skipped.
- Removing a repository from the list may show a confirmation depending on preferences.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Select repository | Full refresh | `git status`, `git remote -v`, `git branch -a`, `git stash list`, `git log` |
| Background sync | Fetch remote refs | `git fetch <remote>` |
| Fork upstream setup | Add upstream remote | `git remote add upstream <url>` |

## Edge Cases

- No repositories → welcome/onboarding screen shown.
- Selected repository is missing.
- Repository has no remote (unpublished).
- Fork with missing upstream remote.

## Relevant Tests

- Test area: repository list and selection
- Behavior verified: grouping/filtering; background fetching starts on selection.
- Edge case covered: missing repository handling.

## Notes

Menu items are disabled when no repository is selected or when the repository is missing.
