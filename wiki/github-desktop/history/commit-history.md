# Commit History

## Purpose

Browse the commits on the current branch and compare against other branches.

## User Actions

- Scroll through commits with author, date, summary, and avatar.
- Select one or more contiguous commits.
- Copy a commit SHA.
- Revert a commit.
- Amend a local commit.
- Compare current branch to another branch.
- Initiate merge, cherry-pick, or squash from the comparison view.
- Drag commits to reorder.

## Business Logic

- History is shown in chronological order.
- Multi-commit selection must be contiguous for diffing and operations.
- The comparison view shows ahead/behind tabs for the selected branch.
- Reverting a merge commit uses the first parent (`-m 1`).
- Amending a non-local commit warns about force push.
- Large diffs are not rendered by default.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Load history | Log | `git log --decorate --format=...` |
| Revert commit | Revert | `git revert [-m 1] <sha>` |
| Amend commit | Amend | `git commit --amend` |
| Compare branches | Diff / merge-base | `git diff --merge-base <base> <compare>` |
| Squash/reorder | Interactive rebase | `git rebase -i <base>` |
| Cherry-pick | Cherry-pick | `git cherry-pick <sha>...` |

## Edge Cases

- Initial commit has no parent.
- Binary files and submodules in diffs.
- Non-renderable diffs.
- Reverting a merge commit.
- Selecting non-contiguous commits.
- Unreachable commits (optional dialog).

## Relevant Tests

- Test area: history and commit selection
- Behavior verified: commits load with summaries, SHAs, tags; changed files listed.
- Edge case covered: signed commits with `log.showSignature=true`; many refs.

## Notes

Conceptual equivalent: revert of merge commit uses `-m 1`.
