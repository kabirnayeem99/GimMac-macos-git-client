# Creating Pull Requests

## Purpose

Start a new pull request on GitHub from the current branch.

## User Actions

- Click "Create Pull Request".
- Preview the pull request diff and changed files.
- Push branch commits if needed.
- Open the compare page in the browser.

## Business Logic

- Creating a PR requires the repository to be associated with GitHub.
- If the current branch is unpushed, the user is prompted to push first or create the PR without pushing.
- Preview computes the commits and changed files between the base and compare branches.
- Mergeability is computed using a merge tree.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Push before PR | Push branch | `git push -u origin <branch>` |
| Compute commits | Log range | `git log <base>..<compare>` |
| Compute changed files | Diff range | `git diff <base>...<compare> -C -M -z --raw --numstat --` |
| Check mergeability | Merge tree | `git merge-tree --write-tree --name-only --no-messages -z <base> <compare>` |

## Edge Cases

- Unpushed branch.
- No upstream/base branch.
- Auth failure.
- Repository is not a GitHub repository.

## Relevant Tests

- Test area: PR creation
- Behavior verified: push-before-PR prompt; mergeability check.
- Edge case covered: PR from unpushed branch.
