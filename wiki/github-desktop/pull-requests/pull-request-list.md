# Pull Request List

## Purpose

Show open pull requests associated with the repository.

## User Actions

- View open pull requests in the branch menu.
- See CI status for each pull request.
- Open a pull request in the browser.
- Check out a pull request locally.

## Business Logic

- Only open pull requests are shown.
- Pull requests are refreshed in the background for GitHub repositories.
- The current branch can be matched to an associated pull request.
- Stale fork remotes are pruned.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Refresh PRs | API + Git | `git fetch <remote>` (for status), GitHub API |
| Open PR in browser | Browser open | N/A |
| Match current branch | Ref comparison | `git rev-list --left-right --count` |

## Edge Cases

- No signed-in account.
- Repository is not a GitHub repository.
- PR branch or fork repository has been deleted.
- Auth errors when fetching fork remotes.

## Relevant Tests

- Test area: pull request list
- Behavior verified: open PRs listed; CI status refreshed.
- Edge case covered: deleted fork handling.
