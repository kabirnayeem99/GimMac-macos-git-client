# Creating Repositories

## Purpose

Initialize a brand-new local Git repository with optional starting files.

## User Actions

- Provide a repository name and local path.
- Optionally initialize with a README.
- Optionally choose a `.gitignore` template.
- Optionally choose a license.
- Configure the default branch name (via preferences).

## Business Logic

- The app creates the directory if it does not exist; if directory creation fails due to permissions, an error is shown.
- The name is sanitized for filesystem safety; invalid filesystem characters are replaced.
- If the target directory is already a Git repository, the user is offered to add it instead.
- If README, `.gitignore`, or license are selected, the files are written to disk.
- A `.gitattributes` file is written if one does not already exist.
- If any files were created, an initial commit is made.
- The new repository is added to the repository list and selected.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Initialize repository | Create new Git repo | `git -c init.defaultBranch=<name> init` |
| Create starting files | Write README, .gitignore, license, .gitattributes | N/A |
| Make initial commit | Create commit from starting files | `git add --all && git commit -m "Initial commit"` |
| Add to app | Repository refresh | `git status`, `git remote -v` |

## Edge Cases

- Directory cannot be created (permissions).
- Target path already exists as a repository.
- Target path is a subdirectory of another repository.
- Existing `README.md` may be overwritten (warning shown).
- No files selected → repository is initialized without an initial commit.

## Relevant Tests

- Test area: repository creation
- Behavior verified: `init` creates a `.git` directory and unborn repo with the configured default branch.
- Edge case covered: unborn repositories and custom default branch names.

## Notes

The exact initial commit message is "Initial commit" when files are generated.
