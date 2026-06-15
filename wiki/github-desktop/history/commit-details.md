# Commit Details

## Purpose

Inspect the files and diff of a single commit or a contiguous selection.

## User Actions

- See the list of files changed by the commit.
- View the diff for each file.
- Copy the commit SHA.
- Revert or amend the commit.
- View image diffs in multiple modes.

## Business Logic

- The changed-files list shows status: new, modified, renamed, copied, deleted, submodule changes.
- Rename/copy detection follows configuration.
- Text diffs are shown as hunks.
- Image diffs support 2-up, swipe, onion skin, and difference views.
- Binary, submodule, and too-large files have specialized rendering.
- For root commits, diff falls back to the null tree.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Show commit | Show commit | `git show <commit> -m -1 --first-parent --patch-with-raw --format= -z --no-color -- <path>` |
| Show range diff | Range diff | `git diff <oldest>^ <latest> --patch-with-raw --format= -z --no-color -- <path>` |
| List changed files | Changed files | `git diff <range> -C -M -z --raw --numstat --` |
| Root commit diff | Null tree diff | `git diff <null-tree> <commit>` |

## Edge Cases

- Root commit (no parent).
- Renamed/copied files.
- Binary/image files.
- Submodule changes.
- Deleted files.
- Large diffs exceeding thresholds.
- Signed commits.

## Relevant Tests

- Test area: commit details / diff viewer
- Behavior verified: text, image, binary, and submodule diffs handled.
- Edge case covered: deleted image files; binary merge driver conflicts.
