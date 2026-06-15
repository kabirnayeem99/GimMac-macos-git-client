# Merging Branches

## Purpose

Combine work from another branch into the current branch.

## User Actions

- Choose "Merge into current branch".
- Select the source branch.
- Optionally choose a squash merge.
- Resolve conflicts if they occur.

## Business Logic

- Before merging, the app can compute merge status (clean, conflicts, loading) using a merge tree preview.
- A normal merge creates a merge commit if successful.
- A squash merge collapses all incoming changes into one commit and commits automatically if clean.
- "Already up to date" is reported as a banner.
- Conflicts enter the conflict resolution flow.
- Merge hooks can be skipped with the no-verify option.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Preview mergeability | Compute merge tree | `git merge-tree --write-tree --name-only --no-messages -z <ours> <theirs>` |
| Compute merge base | Find common ancestor | `git merge-base <ref1> <ref2>` |
| Merge branch | Merge | `git merge [--squash] [--no-verify] <branch>` |
| Finalize squash merge | Commit squash result | `git commit --no-edit --cleanup=strip` |
| Abort merge | Abort | `git merge --abort` |

## Edge Cases

- Merge conflicts.
- Already up to date.
- Unrelated histories (invalid).
- Active merge in progress.
- Squash merge with conflicts.

## Relevant Tests

- Test area: merge
- Behavior verified: success and already-up-to-date results; merge-base computation.
- Edge case covered: unrelated histories return `null` merge base.
