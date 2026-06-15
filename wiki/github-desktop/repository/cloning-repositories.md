# Cloning Repositories

## Purpose

Create a local copy of a remote repository.

## User Actions

- Enter a remote URL or GitHub shorthand (e.g. `owner/repo`).
- Choose a local destination path.
- Select a branch to check out (optional; default is HEAD).
- Optionally enable recursive submodule cloning.
- Authenticate if required.

## Business Logic

- The destination directory must exist and be empty. Cloning into a non-empty directory is not allowed.
- If the repository is large, the app may prompt to initialize Git LFS.
- Clone progress is reported to the UI.
- After cloning, the repository is added to the repository list and selected.
- If authentication is required, the app shows credential dialogs.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Clone repository | Clone remote repository | `git clone --recursive -b <branch> -- <url> <path>` |
| Initialize LFS | Install LFS hooks | `git lfs install` |
| Validate after clone | Refresh | `git status`, `git remote -v` |

## Edge Cases

- Destination path already exists and is not empty.
- Network failure or timeout.
- Authentication failure.
- Remote branch not found.
- Submodule clone failure.
- Git is not installed or not on PATH.

## Relevant Tests

- Test area: clone behavior
- Behavior verified: clones history and working tree; supports custom default branch and branch selection; emits progress.
- Edge case covered: cloning an empty bare repository with a custom default branch name.

## Notes

Conceptual equivalent: the actual clone command may include `--progress` and default-branch configuration.
