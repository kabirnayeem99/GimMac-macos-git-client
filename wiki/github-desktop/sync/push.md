# Push

## Purpose

Upload local commits to the remote.

## User Actions

- Click the Push button.
- Confirm force push when required.
- Publish a branch that has no upstream.

## Business Logic

- Push is disabled when there is no remote, the branch is unborn, or HEAD is detached.
- A new branch is published by setting upstream (`--set-upstream`).
- Force push uses `--force-with-lease` and requires explicit confirmation.
- Unpushed tags are pushed along with the branch.
- After pushing, the app fetches again and fast-forwards tracking branches.
- Push rejection because the local branch is behind triggers a "Push needs pull" dialog.
- Auth, permission, SAML, secret-scanning, and fork-permission errors show specialized dialogs.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Push branch | Push | `git push <remote> [<local-branch>:<remote-branch>] [--set-upstream] [--no-verify] [--progress]` |
| Force push | Force push with lease | `git push <remote> <branch> --force-with-lease [--no-verify]` |
| Push tags | Push tags | `git push <remote> --tags` |
| Delete remote branch | Delete remote ref | `git push <remote> :<branch>` |

## Edge Cases

- Non-fast-forward push.
- Protected branch on remote.
- Authentication failure.
- `pre-push` hook failure.
- Push with secrets detected.
- SAML reauthentication required.
- File size limit / private email rejection.
- No remote configured.

## Relevant Tests

- Test area: push
- Behavior verified: push to bare upstream; set upstream; force-with-lease; progress.
- Edge case covered: force-with-lease after rewriting history.
