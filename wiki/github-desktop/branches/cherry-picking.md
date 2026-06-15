# Cherry-Picking

## Purpose

Copy one or more existing commits onto the current branch.

## User Actions

- Select commits in history.
- Choose cherry-pick.
- Choose a target branch or create a new one.
- Resolve conflicts if they occur.

## Business Logic

- If there are uncommitted changes, the user is prompted to stash and retry.
- The target branch is checked out (or created) before cherry-picking.
- Commits are supplied in ascending order to reduce conflicts.
- Merge commits use the first parent history (`-m 1`).
- Empty commits are kept.
- If a cherry-pick results in no tracked changes, the commit is skipped via an empty commit.
- Conflicts enter the shared conflict resolution flow.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Cherry-pick commits | Apply commits | `git cherry-pick <sha>... --empty=keep -m 1` |
| Continue cherry-pick | Continue | `git cherry-pick --continue` |
| Abort cherry-pick | Abort | `git cherry-pick --abort` |
| Switch target branch | Checkout target | `git checkout <target-branch>` |

## Edge Cases

- Uncommitted changes at start.
- Merge commits.
- Empty or redundant commits.
- Conflicts.
- Single-commit cherry-pick vs. sequencer-based multi-commit.
- Target branch creation.

## Relevant Tests

- Test area: cherry-pick
- Behavior verified: single and multiple commits; merge commits; empty commits; conflicts.
- Edge case covered: redundant commits and range conflicts.
