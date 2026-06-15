# Pull

## Purpose

Download remote changes and integrate them into the current branch.

## User Actions

- Click the Pull button.

## Business Logic

- Pull respects the user's preference for merge or rebase.
- The default is `--ff` unless `pull.ff` is already configured.
- Submodules are recursed.
- Merge or rebase hooks can be skipped with no-verify.
- Conflicts enter the conflict resolution flow.
- After a successful pull, remote HEAD is updated and local branches are fast-forwarded.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Pull changes | Pull | `git -c rebase.backend=merge pull [--ff] [--recurse-submodules] [--progress] [--no-verify] <remote>` |

## Edge Cases

- Local changes would be overwritten.
- Merge or rebase conflicts.
- Authentication/network failure.
- No upstream configured.
- Pull with `ff=only` fails if not fast-forwardable.

## Relevant Tests

- Test area: pull
- Behavior verified: merge vs. rebase behavior based on config; fast-forward/merge outcomes.
- Edge case covered: `pull.rebase=false` + `pull.ff=false` creates merge commit; `pull.ff=only` fails.
