# Working Tree Changes

## Purpose

Show the user what has changed in the working directory and allow review before staging or discarding.

## User Actions

- See a list of changed files with status icons.
- Select a file to view its diff.
- Toggle ignore-whitespace and side-by-side diff modes.
- View text, image, binary, submodule, and unrenderable diffs.
- See line-ending change warnings.

## Business Logic

- The working tree is refreshed automatically when the repository is selected or after Git operations.
- File statuses include added, modified, deleted, renamed, copied, untracked, and conflicted.
- Rename/copy detection follows Git's `status.renames` / `diff.renames` configuration.
- For renames, both the old and new paths are shown.
- Submodule changes show the old and new submodule commit SHAs.
- Image diffs support 2-up, swipe, onion skin, and difference views for supported formats.
- Diffs above a size threshold (large binary or very long text) are not rendered by default; the user can choose to show them.
- Conflict markers are counted and binary conflict files are identified separately.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Refresh changes | Load working tree status | `git status --untracked-files=all --branch --porcelain=2 -z` |
| View file diff | Compute diff | `git diff --no-ext-diff --patch-with-raw -z --no-color HEAD -- <path>` |
| View new file diff | Diff against empty tree | `git diff --no-index -- /dev/null <path>` |
| Check conflict markers | Diff check | `git diff --check` |
| Detect binary/image | Check attributes / numstat | `git check-attr merge`, `git diff --numstat -z HEAD` |

## Edge Cases

- No changes in the working tree.
- Untracked files only.
- Binary files cannot be partially staged/discarded.
- Submodule modifications that do not change the submodule commit are not selected by default.
- Large files exceed diff rendering limits.
- Line-ending changes produce warnings.
- Conflicted files block committing.

## Relevant Tests

- Test area: status parsing
- Behavior verified: new, modified, deleted, renamed, copied, untracked, and staged states are reported correctly.
- Edge case covered: unborn repository with mixed staged/unstaged content; renamed-and-modified files.

## Notes

Conceptual equivalent: diff commands include `--no-ext-diff` to ignore user-configured external diff tools.
