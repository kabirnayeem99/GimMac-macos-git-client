# Committing

## Purpose

Record the selected changes as a new commit on the current branch.

## User Actions

- Write a commit summary (required) and description (optional).
- Add co-authors.
- Toggle commit options: skip hooks, add `Signed-off-by`, allow empty commit.
- Click the commit button.
- Handle warnings about protected branches, unknown authors, conflicted files, or hidden changes.

## Business Logic

- The commit button is disabled when there is no summary, no selected changes, or the repository is in an invalid state.
- The index is cleared and rebuilt from the user's selection before the commit is created.
- Co-author trailers are appended to the commit message.
- The button shows the number of files to be committed and the target branch.
- If conflicted files are included, a warning is shown.
- If the current branch is protected, a warning is shown.
- If unknown commit authors are detected, a warning is shown.
- If a filter hides files from the changes list, a confirmation is shown so the user does not accidentally omit changes.
- Repository rules (e.g. required commit-message patterns) may surface warnings before committing.
- An optional AI-generated commit summary/description is available when signed in to GitHub.
- Hook progress and failure output are surfaced; the user can retry or skip hooks.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Commit selected changes | Create commit | `git commit -F - [--no-verify] [--signoff] [--allow-empty]` |
| Stage before commit | Rebuild index | `git add` / `git apply --cached` / `git reset` (as needed) |
| Merge commit | Finalize merge | `git commit --no-edit --cleanup=strip` |

## Edge Cases

- Empty commit message.
- No selected changes (unless allow-empty is enabled).
- Conflicted files selected.
- Hook failure aborts the commit.
- Protected branch warning.
- Unknown authors warning.
- Repository is on an unborn branch or detached HEAD.
- Generated commit message would overwrite user-entered message.

## Relevant Tests

- Test area: committing
- Behavior verified: commits from selected files; handles renames, partial selections, root commit, `allowEmpty`, and `#` in message body.
- Edge case covered: empty commit messages vs. empty commits.

## Notes

Conceptual equivalent: the commit message is supplied via stdin; co-author trailers are merged with `git interpret-trailers`.
