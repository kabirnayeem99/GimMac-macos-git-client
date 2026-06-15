# Error Handling Patterns

## Purpose

Surface actionable feedback when Git or network operations fail.

## User Actions

- See error dialogs with Git output.
- Retry, abort, or follow the suggested resolution.

## Business Logic

- Errors are wrapped with context (repository, retry action, Git context).
- Errors from background operations are silently ignored.
- Specific error types trigger dedicated dialogs:
  - Missing repository
  - Push needs pull
  - Merge/rebase/cherry-pick conflicts
  - Local changes overwritten
  - Authentication / permission / SAML
  - Secret scanning push protection
  - Discard retry
  - Upstream already exists

## Git Operations

| Error Type | Conceptual Git CLI Context |
|---|---|
| Not a repository | `git status` returns `128` |
| Push rejected | `git push` non-fast-forward |
| Conflicts | `git merge` / `git rebase` / `git cherry-pick` exit with conflicts |
| Local changes overwritten | `git checkout` / `git merge` / `git rebase` overwrites local files |
| Auth failure | `git fetch` / `git push` credential failure |

## Edge Cases

- Multiple error handlers registered.
- Retry after resolving external issue.
- Background task errors suppressed.

## Relevant Tests

- Test area: error handling
- Behavior verified: specific errors map to correct dialogs.
- Edge case covered: retry actions carry original operation context.

## Notes

Conceptual equivalent: the app inspects exit codes and stderr to classify errors.
