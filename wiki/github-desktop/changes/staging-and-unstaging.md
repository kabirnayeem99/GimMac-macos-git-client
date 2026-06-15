# Staging and Unstaging

## Purpose

Choose which changes will be included in the next commit, at file, hunk, or line granularity.

## User Actions

- Check/uncheck whole files to include/exclude them.
- Select individual hunks or lines within a diff.
- Toggle the inclusion of all changes.

## Business Logic

- Only checked files/lines are committed.
- The index is rebuilt from the user's selection before each commit.
- Whole-file selections are staged using index updates.
- Partial selections are converted into a patch and applied to the index.
- Renamed files require removing the old path from the index before adding the new path.
- Untracked files are not staged unless explicitly selected.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Stage whole files | Update index | `git update-index --add --remove --replace -z --stdin` |
| Stage partial selection | Apply patch to index | `git apply --cached --unidiff-zero --whitespace=nowarn -` |
| Unstage all | Reset index | `git reset -- .` |
| Unstage paths | Reset selected paths | `git reset -- <paths>` |

## Edge Cases

- Partial staging of binary, image, submodule, or too-large files is not supported.
- Patch application fails because the working tree changed after the diff was generated.
- Renamed file with modifications only shows the modification in the diff.
- A staged new file that is later deleted in the working tree is handled specially.
- A staged delete coexisting with an untracked file at the same path is deduplicated.

## Relevant Tests

- Test area: staging and partial commits
- Behavior verified: whole-file and partial staging produce correct commits; rename handling works.
- Edge case covered: partial selection across multiple hunks; staged new file deleted afterward.

## Notes

Conceptual equivalent: whole-file staging uses `update-index`; partial staging uses a generated unified patch.
