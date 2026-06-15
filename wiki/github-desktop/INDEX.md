# GitHub Desktop Business Logic Wiki

## Purpose

This wiki documents the user-facing behavior, product rules, and underlying Git operations of the GitHub Desktop application. It is derived from the reference codebase, but it intentionally avoids implementation details such as class names, function names, components, or file paths. The focus is on what each screen or feature does, what actions a user can take, what rules govern those actions, and which Git operations are conceptually equivalent.

## Reading Guide

The documentation is organized by feature area. Each page follows a consistent structure:

- **Purpose** — why the feature exists.
- **User Actions** — what the user can do.
- **Business Logic** — the rules that enable or disable actions, preconditions, success/failure outcomes, and state changes.
- **Git Operations** — high-level operation names and conceptual Git CLI equivalents.
- **Edge Cases** — important special cases and error states.
- **Relevant Tests** — tests that clarify rules or edge cases.
- **Notes** — caveats or approximations.

Start with a feature area below, or use the operation index to find a specific Git command.

## Feature Areas

- [Repository management](repository/opening-repositories.md)
  - [Opening repositories](repository/opening-repositories.md)
  - [Cloning repositories](repository/cloning-repositories.md)
  - [Creating repositories](repository/creating-repositories.md)
  - [Repository list](repository/repository-list.md)
  - [Remotes](repository/remotes.md)
- [Changes workflow](changes/working-tree-changes.md)
  - [Working tree changes](changes/working-tree-changes.md)
  - [Staging and unstaging](changes/staging-and-unstaging.md)
  - [Discarding changes](changes/discarding-changes.md)
  - [Committing](changes/committing.md)
  - [Amend and undo](changes/amend-and-undo.md)
- [Branches](branches/current-branch.md)
  - [Current branch display](branches/current-branch.md)
  - [Creating branches](branches/creating-branches.md)
  - [Switching branches](branches/switching-branches.md)
  - [Deleting branches](branches/deleting-branches.md)
  - [Renaming branches](branches/renaming-branches.md)
  - [Merging branches](branches/merging-branches.md)
  - [Rebasing branches](branches/rebasing-branches.md)
  - [Cherry-picking](branches/cherry-picking.md)
  - [Squashing and reordering](branches/squashing-and-reordering.md)
- [Sync](sync/fetch.md)
  - [Fetch](sync/fetch.md)
  - [Pull](sync/pull.md)
  - [Push](sync/push.md)
  - [Publish branch](sync/publish-branch.md)
  - [Tags](sync/tags.md)
- [History](history/commit-history.md)
  - [Commit history](history/commit-history.md)
  - [Commit details](history/commit-details.md)
- [Merge conflicts](merge-conflicts/conflict-detection.md)
  - [Conflict detection](merge-conflicts/conflict-detection.md)
  - [Conflict resolution](merge-conflicts/conflict-resolution.md)
- [Pull requests](pull-requests/pull-request-list.md)
  - [Pull request list](pull-requests/pull-request-list.md)
  - [Creating pull requests](pull-requests/creating-pull-requests.md)
  - [Checking out pull requests](pull-requests/checking-out-pull-requests.md)
- [Stashing](stashing/stash-changes.md)
  - [Stash changes](stashing/stash-changes.md)
  - [Restore stash](stashing/restore-stash.md)
- [Settings](settings/git-settings.md)
  - [Git settings](settings/git-settings.md)
  - [Repository settings](settings/repository-settings.md)
  - [Application settings](settings/application-settings.md)
- [Onboarding](onboarding/welcome-and-onboarding.md)
- [Other](other/submodules.md)
  - [Submodules](other/submodules.md)
  - [LFS and large files](other/lfs-and-large-files.md)
  - [Error handling patterns](other/error-handling.md)

## Git Operations Covered

- Repository validation and refresh (`git status`, `git remote`, `git branch`, `git config`, `git log`, `git stash list`)
- Working tree inspection (`git status`, `git diff`)
- Staging and unstaging (`git add`, `git reset`, `git update-index`, `git apply`)
- Discarding changes (`git checkout`, `git checkout-index`, `git reset`, `git rm`, `git apply -R`)
- Committing (`git commit`, `git interpret-trailers`)
- Amend and undo (`git commit --amend`, `git reset --soft HEAD~1`)
- Branch management (`git branch`, `git checkout`, `git switch`, `git branch -m`, `git branch -D`)
- Merging (`git merge`, `git merge-base`, `git merge-tree`)
- Rebasing (`git rebase`, `git rebase --continue`, `git rebase --abort`)
- Cherry-picking (`git cherry-pick`, `git cherry-pick --continue`, `git cherry-pick --abort`)
- Squashing and reordering (`git rebase -i`)
- Fetching (`git fetch`, `git remote update`, fast-forward logic)
- Pulling (`git pull`, `git pull --rebase`)
- Pushing (`git push`, `git push --force-with-lease`, `git push --tags`)
- Publishing branches and repositories (`git remote add`, `git push -u`)
- Tagging (`git tag`, `git tag -d`, `git push --tags`)
- Stashing (`git stash push`, `git stash pop`, `git stash drop`, `git stash list`)
- Submodule operations (`git submodule status`, `git submodule update`)
- LFS operations (`git lfs install`, `git check-attr`)
- Configuration (`git config`, `.gitignore` editing)

## Notes on Git CLI Equivalents

The Git CLI commands shown in this wiki are **conceptual equivalents**. GitHub Desktop invokes Git with explicit argument arrays (not shell strings), and in some cases uses internal parsing, progress callbacks, or library helpers. The flags listed are the important ones observed in the codebase; the exact invocation may vary by platform or Git version. Where a behavior is driven by the GitHub API rather than Git itself, that is noted.
