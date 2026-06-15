# Fetch

## Purpose

Download the latest refs from a remote without changing the local working tree.

## User Actions

- Click the Fetch button.
- Trigger background fetches automatically.

## Business Logic

- Fetch runs for the current remote, default remote, and upstream remote (for forks) in priority order.
- Stale remote-tracking branches are pruned.
- Submodules are updated on demand.
- After fetching, the app fast-forwards local branches that can be safely updated.
- Network operations are serialized; push/pull/fetch do not run concurrently.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Fetch remote | Fetch refs | `git fetch [--progress] --prune --recurse-submodules=on-demand <remote>` |
| Fast-forward branches | Fast-forward local refs | `git fetch . --show-forced-updates --no-write-fetch-head --stdin` |
| Fetch specific ref | Fetch refspec | `git fetch <remote> <refspec>` |

## Edge Cases

- No remote configured.
- Authentication/network failure.
- Bad refspec.
- Fast-forward failure for some refs is accepted.
- Promisor/partial-clone remotes.

## Relevant Tests

- Test area: fetch
- Behavior verified: remote-tracking refs updated; stale branches pruned; local branches fast-forwarded.
- Edge case covered: ahead/behind/diverged branch combinations.
