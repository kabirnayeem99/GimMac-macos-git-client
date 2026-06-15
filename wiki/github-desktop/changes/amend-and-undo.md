# Amend and Undo Commit

## Purpose

Rewrite the most recent commit or undo it entirely.

## User Actions

- Undo the last commit, moving its changes back to the working directory.
- Amend the last commit with new changes or a new message.
- See a warning when amending/undoing a commit that has already been pushed.

## Business Logic

- Undo is a soft reset of HEAD by one commit. It is not offered if the commit has been pushed and would require a force push.
- Undoing a merge commit always shows a warning.
- Amend rewrites the latest commit with the current selection and/or an edited message.
- Amending a commit that has already been pushed marks the branch as needing a force push.
- The commit UI locks during the operation to prevent duplicate actions.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Undo last commit | Soft reset | `git reset --soft HEAD~1` |
| Amend last commit | Amend commit | `git commit --amend [--no-verify] [--signoff]` |

## Edge Cases

- No commits to undo/amend (unborn branch).
- Commit has been pushed; undo/amend requires force push.
- Undoing a merge commit.
- Amending during an active merge/rebase/cherry-pick.

## Relevant Tests

- Test area: undo and amend
- Behavior verified: undo restores changes; amend rewrites commit.
- Edge case covered: pushed commits and merge commits.

## Notes

Force-push tracking is used to warn the user before pushing an amended branch.
