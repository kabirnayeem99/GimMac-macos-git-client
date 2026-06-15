# Submodules

## Purpose

Detect and update Git submodules within a repository.

## User Actions

- See submodule changes in the changes/history list.
- Open a submodule directory as a repository.
- Update submodules after checkout or pull.

## Business Logic

- Only top-level submodules are listed.
- Submodule changes show old and new submodule commit SHAs.
- Submodules are initialized and updated recursively after checkout or pull.
- File-protocol access can be allowed when explicitly requested.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| List submodules | Submodule status | `git submodule status --` |
| Update submodules | Submodule update | `git submodule update --init --recursive` |
| Reset submodule paths | Force update | `git submodule update --recursive --force -- <paths>` |

## Edge Cases

- Missing submodule repository.
- Invalid submodule SHA.
- Submodule update fails.
- Submodule checked out in a different commit.

## Relevant Tests

- Test area: submodules
- Behavior verified: status, diff, checkout, pull, and history submodule behavior.
- Edge case covered: uninitialized submodules on checkout.
