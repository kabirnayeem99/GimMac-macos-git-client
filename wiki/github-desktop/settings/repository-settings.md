# Repository Settings

## Purpose

Configure settings specific to the selected repository.

## User Actions

- Edit the remote URL.
- Edit the `.gitignore` file.
- Choose local vs. global Git config.
- Configure fork contribution target.
- Set Git description.

## Business Logic

- Saving `.gitignore` creates a new commit.
- Ignore rules are appended respecting existing content and line-ending settings.
- Special glob/regex characters in file paths are escaped.
- Empty `.gitignore` deletes the file.
- Forked repositories show an additional "Fork behavior" tab.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Read remote URL | Get remote URL | `git remote get-url <name>` |
| Update remote URL | Set remote URL | `git remote set-url <name> <url>` |
| Save .gitignore | Write and commit | `git add .gitignore && git commit -m "Update .gitignore"` |
| Delete empty .gitignore | Remove file | `git rm .gitignore` |

## Edge Cases

- Invalid remote URL.
- Config lock file.
- CRLF vs. LF line endings.
- Fork remote handling.
- Empty `.gitignore`.

## Relevant Tests

- Test area: gitignore
- Behavior verified: create/read/overwrite/delete `.gitignore`; escape special characters.
- Edge case covered: CRLF vs. LF line endings.
