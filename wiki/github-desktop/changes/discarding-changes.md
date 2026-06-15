# Discarding Changes

## Purpose

Remove unwanted working tree changes and restore files to a clean state.

## User Actions

- Discard a single file, multiple files, or all changes.
- Discard only selected hunks/lines.
- Choose to move new files to trash or delete them permanently.

## Business Logic

- A confirmation dialog is shown by default; it can be disabled in preferences.
- New/untracked files are moved to the system trash when possible, preserving them for recovery.
- If moving to trash fails, a retry dialog offers permanent deletion.
- Modified files are restored from the index or HEAD.
- Partial discards generate a reverse patch to remove only the selected additions/deletions.
- Staged paths are reset before checkout.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Discard whole modified file | Restore from HEAD | `git checkout HEAD -- <path>` |
| Reset staged paths | Reset to HEAD | `git reset HEAD -- <path>` |
| Restore from index | Checkout index | `git checkout-index -f -u -q --stdin -z` |
| Discard partial selection | Reverse patch | `git apply --unidiff-zero --whitespace=nowarn -` (reverse) |
| Remove untracked file | Remove file | `git rm -- <path>` (or OS trash) |
| Discard submodule changes | Update submodule | `git submodule update --recursive --force -- <paths>` |

## Edge Cases

- Discard includes new files that have never been tracked.
- Trash operation fails (permissions, unsupported drive).
- User preference to always delete permanently.
- Partial discard on a file that has changed since the diff was generated.
- Submodule discard updates the submodule checkout.

## Relevant Tests

- Test area: discard changes
- Behavior verified: full-file, full-selection, and partial-selection discards behave correctly.
- Edge case covered: empty selection leaves the file unchanged.

## Notes

Conceptual equivalent: actual discard may first attempt to move new files to the OS trash rather than deleting them.
