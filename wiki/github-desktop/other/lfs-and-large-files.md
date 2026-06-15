# LFS and Large Files

## Purpose

Detect and set up Git LFS for repositories with large files.

## User Actions

- Install/initialize Git LFS when prompted.
- Configure LFS globally or per-repository.

## Business Logic

- Large files may trigger a Git LFS initialization prompt when adding or cloning a repository.
- Global LFS install skips repo hooks.
- Repo LFS install sets up hooks.
- The app checks whether a path is tracked by LFS using attributes.
- LFS attribute mismatches are handled.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Install LFS globally | Global LFS install | `git lfs install --skip-repo [--force]` |
| Install LFS in repo | Repo LFS install | `git lfs install [--force]` |
| Check LFS tracking | Track list | `GIT_LFS_TRACK_NO_INSTALL_HOOKS=1 git lfs track` |
| Check if path tracked | Check attribute | `git check-attr filter <path>` |

## Edge Cases

- LFS not installed.
- Large file already committed without LFS.
- LFS attribute mismatch.
- Network failure fetching LFS objects.

## Relevant Tests

- Test area: LFS detection
- Behavior verified: LFS install and tracking detection.
- Edge case covered: LFS attribute mismatch.
