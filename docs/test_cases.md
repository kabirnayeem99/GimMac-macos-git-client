# GitHub Desktop — Test Cases (Plain English)

Behavior specifications extracted from the GitHub Desktop reference codebase
(`github-desktop-codebase/app/test/unit/`), translated to plain "when … then …"
statements. **Reference only** — GimMac is Swift/AppKit; do not copy code. Use this
to understand the *correct Git UX behavior* GitHub Desktop expects, then implement the
native equivalent.

Scope: 95 test files, in three batches. **GitHub-, API-, and Electron-only cases have been
pruned** — anything tied to GitHub accounts/GHES endpoints, GitHub repo records, forks, pull
requests, dotcom/enterprise grouping, GitHub issue/@mention linkification, noreply emails, or the
GitHub REST API. What remains is Git domain logic and generic UI/store behavior that maps to a
local-first macOS Git client.
- **Batch 1** (below, first section): core Git ops — status, diff, commit, branch, merge,
  push/pull/fetch, rebase, cherry-pick, stash, reset, revert, squash, tags, remotes, config,
  gitignore, clone, init, refs, reflog, submodules, worktrees, patch formatting.
- **Batch 2** (see "Batch 2" heading further down): remaining Git ops (add, apply, format-patch,
  ref, reorder, description, core, credential, environment, attributes, LFS), terminal/stream
  output, rebase progress/conflict detection, ahead/behind, branch grouping, git-store,
  changes filtering, diff expansion, commit-message formatting, remote URL parsing, repo naming.
- **Batch 3** (see "Batch 3" heading further down): generic UI + store behavior, intended for
  conversion into macOS UI/integration tests — stores (cloning, repositories, state cache, local
  storage, DB schema migration, store update reducers), list/section selection, popup management,
  fuzzy find, path & text truncation, number/byte/duration formatting, progress parsing,
  co-author extraction, repo naming/identity, path security. GitHub/API/Electron-only tests
  (accounts, repo matching, remote-URL sync, fork pruning, grouping/icons, emails, type guards)
  were removed.

---

## Status & Working Directory

### unit/status-parser-test.ts

**parsePorcelainStatus**
- When parsing standard status output, correctly extracts status codes and file paths from porcelain format.
- When parsing renames, extracts old and new file paths with rename status codes.
- When parsing ignored files, ignores them and returns empty result.
- When parsing status headers, extracts all header lines with their values.
- When parsing paths containing newlines, preserves the newline in the file path.
- When parsing typechange entries, correctly identifies type change status codes.
- When parsing submodule changes, extracts submodule status codes from entries.

### unit/status-utils-test.ts

**mapStatus**
- When mapping new files, returns "New" label.
- When mapping untracked files, returns "New" label.
- When mapping modified files, returns "Modified" label.
- When mapping deleted files, returns "Deleted" label.
- When mapping renamed files, returns "Renamed" label.
- When mapping copied files, returns "Copied" label.

**isConflictedFile**
- When checking a conflicted file, returns true.
- When checking non-conflicted files, returns false for all other file kinds.

**hasConflictedFiles**
- When checking an empty working directory, returns false.
- When checking directory with no conflicted files, returns false.
- When checking directory with at least one conflicted file, returns true.

---

## Diffs

### unit/git/diff-test.ts

**getWorkingDirectoryImage**
- When retrieving image for a new file, returns correct media type and base64-encoded content.
- When retrieving image for a modified file, returns correct media type and content.

**getBlobImage**
- When retrieving image for a modified file from HEAD, returns correct media type and content.
- When retrieving image for a deleted file from HEAD, returns correct media type and content.

**imageDiff**
- When generating diff for image files, sets both previous and current image data.
- When generating diff for text files, includes hunks with line changes.

**getWorkingDirectoryDiff**
- When counting lines for a new file, correctly parses hunk header and line additions.
- When counting lines for a modified file, correctly parses multiple hunks with deletions and additions.
- When counting lines for a staged file, correctly parses hunks from index.
- When displaying binary diff for docx file, identifies diff as binary type.
- When generating diff for a renamed file, returns empty hunks list.
- When generating diff for a renamed and modified file, shows only the modification changes in hunks.
- When handling unborn repository with mixed state, correctly parses diff with staged and unstaged changes.

**getWorkingDirectoryDiff / line-endings**
- When displaying line ending change from LF to CRLF, captures the line ending change with from and to values.

**getWorkingDirectoryDiff / unicode**
- When displaying unicode characters, preserves all unicode characters in diff output.

**getBinaryPaths**
- When in empty repo without HEAD, throws error.
- When files use binary merge driver, includes plain text files marked with binary driver in results.
- When repository has text-only files, returns empty array.
- When repository has image changes, returns all changed image files.
- When merge conflicts exist on image files, returns all conflicted image files.

**with submodules**
- When getting diff for submodule with right paths, returns correct full path and relative path.
- When getting diff for submodule with only modified changes, sets modified flag without commit or untracked changes.
- When getting diff for submodule with only untracked changes, sets untracked flag without commit or modified changes.
- When getting diff for submodule with a commit change, sets commit changed flag with SHAs, without other changes.
- When getting diff for submodule with all kinds of changes, sets all three change flags with SHAs.

**getBranchMergeBaseChangedFiles**
- When loading files changed between two branches if merged, returns only files changed since merge base.
- When querying unrelated histories, returns null.

**getBranchMergeBaseDiff**
- When loading diff of a file between two branches if merged, shows only changes since merge base.

### unit/diff-parser-test.ts

**DiffParser**
- When parsing changed files, extracts all hunks with correct line counts and types.
- When parsing new files, creates hunk with correct unified diff range.
- When parsing files containing @@ symbols, correctly handles @@ symbols in file content.
- When parsing new files without trailing newline, sets noTrailingNewLine flag on the last added line.
- When parsing diffs that add newline to end of file, marks deleted line with noTrailingNewLine flag.
- When parsing files where neither version has trailing newline, marks both sides with noTrailingNewLine flag.
- When parsing binary diffs, sets isBinary flag and returns empty hunks.
- When parsing diff of empty file, returns zero hunks.
- When parsing hunk headers with omitted line counts from new file, correctly derives line counts.
- When parsing hunk headers with omitted line counts from old file, correctly derives line counts.

### unit/git/diff-check-test.ts

**getFilesWithConflictMarkers / with one conflicted file**
- When searching for conflicted files, finds the single conflicted file with correct marker count.

**getFilesWithConflictMarkers / with multiple conflicted files**
- When searching for conflicted files in a repo with multiple conflicts, finds all conflicted files with correct marker counts.

**getFilesWithConflictMarkers / with no conflicted files**
- When searching in a repository with no conflicts, returns empty map.

---

## Commits

### unit/git/commit-test.ts

**createCommit normal**
- When files in a fixture repository are modified and committed, the commit SHA is returned and working directory becomes clean.
- When a commit message with comment syntax is created without special handling, comment text is preserved in the commit body.
- When an empty repository receives its first commit with files, the SHA returned is "(root-commit)".
- When a file is renamed and committed, the working directory becomes clean.

**createCommit partials**
- When some lines from a new file are selected, a commit is created with only those lines and the file status changes to Modified in working directory.
- When the second hunk from a modified file is selected, a commit is created with only that hunk and the file remains Modified.
- When a single deletion is selected from a modified file, a commit is created with only that deletion.
- When multiple hunks from a modified file are selected, a commit is created with all selected hunks and the file remains Modified.
- When some lines from a deleted file are selected, a partial commit is created and the file remains Deleted in working directory.
- When a file is renamed and modifications are staged, the commit includes both the rename and modifications.
- When a renamed file with modifications is partially selected, a commit is created with only the selected modifications and remaining changes are preserved.

**createCommit with a merge conflict**
- When a conflicted file is resolved and committed with selection, a merge commit with two parents is created.

**createMergeCommit**
- When a simple merge conflict is resolved with all tracked files, a merge commit is created and working directory becomes clean.
- When resolving a multi-file merge conflict by choosing "ours" for one file, the chosen file is kept and committed.
- When resolving a multi-file merge conflict by choosing "theirs" for one file, the chosen file is deleted and commit is created.
- When a file added in both branches is resolved with "ours", the our version is checked out and committed.
- When a file added in both branches is resolved with "theirs", the their version is checked out and committed.
- When attempting to create a merge commit with no changes, an error is thrown.

**index corner cases**
- When a staged new file is deleted before commit, the commit succeeds with only remaining staged files.
- When a delete is staged and an untracked file with the same name exists, the commit succeeds.
- When a file is removed from index and modified, commits can proceed correctly and file status is tracked properly.

**createCommit allowEmpty**
- When allowEmpty is true and no files are provided, an empty commit is created and HEAD advances.
- When allowEmpty is not set and no files are provided, the commit fails.

### unit/commit-identity-test.ts

**CommitIdentity#parseIdent**
- When a normal ident string is parsed, name, email, and date are extracted correctly.
- When an ident string includes timezone information, the offset in minutes is calculated correctly.
- When an ident string has an unconventional email address format, it is still parsed correctly.
- When an ident string has a malformed email address, it is still parsed correctly.

### unit/git/log-test.ts

**getCommits**
- When loading history from a repository, returns the correct number of commits.
- When loading history, returns commits with correct SHA, shortSha, and summary.
- When handling a repository with HEAD file on disk, loads commits correctly.
- When handling a signed commit with log.showSignature set in config, loads commits correctly without GPG signature issues.
- When parsing commits with tags, returns all tags associated with each commit.

**getChangedFiles**
- When loading files changed in a commit, returns the correct files and their status.
- When detecting renames in commit history, identifies renamed files and indicates whether modifications were included.
- When detecting copies in commit history with diff.renames=copies config, identifies copied files and their original paths.
- When handling commits when HEAD exists on disk, loads changed files correctly.

**Submodules**
- When detecting submodule changes within commits, identifies submodule status in the changed files.

### unit/patch-formatter-test.ts

**formatPatchesForModifiedFile**
- When selecting the second hunk, creates a patch with the correct hunk header and includes only that hunk's content.
- When selecting the first hunk, creates a patch with the correct hunk header and includes only that hunk's content.
- When selecting the first and third hunks, creates a patch with separate hunk headers for each selected hunk.
- When selecting only added lines while skipping preceding deletions, creates a patch that includes the selected addition with necessary context.
- When unselected added lines exist, does not include them as context in the resulting patch.
- When hunk headers need rewriting, updates the header to reflect the new line counts after selection.
- When empty context lines exist, includes them in the patch output.
- When a `No newline` marker is present in the diff, preserves the marker in the resulting patch.

---

## Branches & Refs

### unit/git/checkout-test.ts

- When invalid characters are used for a branch name, checkout fails with a fatal error.
- When checking out an existing valid branch in a fixture repository, the current branch changes to the checked-out branch.
- When a branch exists on multiple remotes, checking out a remote branch creates a local tracking branch with the correct upstream.
- When an existing local branch matches a remote branch name, checkout fails with an error about the name already existing.
- When checking out a branch with changed submodule references, the submodule reference is updated and working directory becomes clean.
- When checking out a branch that requires initializing a submodule, the submodule is initialized with the correct commits.

### unit/create-branch-test.ts

**getStartPoint for default branch**
- When HEAD start point is requested, HEAD is returned.
- When current branch start point is requested, current branch is returned.
- When default branch start point is requested, default branch is returned.

**getStartPoint for a non-default branch**
- When HEAD start point is requested, HEAD is returned.
- When current branch start point is requested, current branch is returned.
- When default branch start point is requested, default branch is returned.

**getStartPoint for detached HEAD**
- When HEAD start point is requested, HEAD is returned.
- When current branch start point is requested, HEAD is returned instead.
- When default branch start point is requested, HEAD is returned instead.

### unit/sanitize-ref-name-test.ts

- When a valid branch name is provided, it is left unchanged.
- When invalid characters are present, they are replaced with dashes.
- When a branch name ends with a slash, it is replaced with a dash.
- When a branch name starts with plus signs, the plus signs are removed.
- When a branch name starts with minus signs, the minus signs are removed.
- When a branch name ends with ".lock", it is replaced with a dash.
- When a branch name contains newlines, they are replaced with dashes.
- When a branch name starts with a dot, the leading dot is removed.
- When a branch name contains double dashes after the first character, they are preserved.

### unit/git/for-each-ref-test.ts

**getBranches**
- When fetching branches from a fixture repository, returns correct branch names, SHAs, and upstream references using `for-each-ref`.
- When repository is empty, returns an empty list.
- When directory lacks a `.git` directory, returns an empty list.

**getBranchesDifferingFromUpstream**
- When filtering branches, includes all branches that are behind upstream, ahead of upstream, or both ahead and behind.
- When filtering branches, excludes the current branch even if it differs from upstream.
- When filtering branches, excludes branches that are up to date with upstream.

### unit/git/reflog-test.ts

**getRecentBranches**
- When checking out multiple branches, returns the recently checked out branch names in order.
- When a branch is renamed after being checked out, excludes the old branch name and includes the renamed branch name in recent branches.
- When requesting a limited number of branches, returns only the most recent branches up to the limit.

**getBranchCheckouts**
- When querying branches checked out before a specific date, returns no branches.
- When querying branches checked out after a specific date, returns only branches checked out after that date, excluding branches created but never checked out.
- When the current branch is orphaned, returns an empty set.

### unit/git/rev-parse-test.ts

**getRepositoryType**
- When run inside a working directory, returns `regular` kind and correctly resolves the top-level directory and `.git` directory paths from subdirectories.
- When run in a directory without a Git repository, returns `missing` kind.
- When examining a submodule path, returns `regular` kind with the submodule's top-level directory and `.git/modules/<name>` path.
- When run on a bare repository, returns `bare` kind.
- When run on an empty directory, returns `missing` kind.
- When run on a missing directory, returns `missing` kind.
- When Git has an unsafe repository configuration set and owner mismatch is enforced, returns `unsafe` kind.

---

## Remote Operations (push / pull / fetch / merge)

### unit/git/merge-test.ts

**merge**
- When merging a branch successfully, returns MergeResult.Success.
- When merging the same branch again (noop), returns MergeResult.AlreadyUpToDate.

**getMergeBase**
- When finding the common ancestor of two branches, returns the correct merge base SHA.
- When two branches have no common ancestor, returns null.
- When a ref cannot be found, returns null.

**abortMerge**
- When there is no merge in progress, throws an error.
- When in the middle of resolving conflicts, aborts the merge successfully.

### unit/git/push-test.ts

- When pushing commits to a local remote, successfully pushes commits to the upstream repository.
- When pushing a new branch with remoteBranch=null, sets the upstream tracking reference.
- When force-pushing after history rewrite, fails with default settings but succeeds with forceWithLease option.
- When pushing with a progress callback, reports at least one progress event with kind="push".

### unit/git/pull/pull-test.ts

**with submodules**
- When pulling changes that update submodule references, updates the submodule to point to the new commit.
- When pulling changes that do not affect submodules, leaves submodule unchanged.

### unit/git/pull/ahead-and-behind-test.ts

**with pull.rebase=false and pull.ff=false set in config**
- When pulling, creates a merge commit with two parents.
- When pulling, the merge commit is different from the remote branch.
- When pulling, the local branch is ahead of the tracking branch by 2 commits.

**with pull.rebase=false set in config**
- When pulling, creates a merge commit with two parents.
- When pulling, the local branch is ahead of the tracking branch by 2 commits.

**with pull.rebase=true set in config**
- When pulling, does not create a merge commit (single parent).
- When pulling, the local branch is ahead of the tracking branch by 1 commit.

**with pull.rebase=false and pull.ff=only set in config**
- When pulling with ff=only preventing merge commits, throws an error.

### unit/git/fetch-test.ts

**fastForwardBranches**
- When fast-forwarding branches using fetch, updates branches that are behind their upstream while leaving branches ahead or ahead-and-behind unchanged.
- When fast-forwarding branches, the current branch remains unmodified.
- When fast-forwarding branches, does not change the FETCH_HEAD file.

---

## History Rewriting (rebase / cherry-pick / squash / revert / reset)

### unit/git/rebase-full-test.ts

**getRebaseInternalState**
- When no rebase is in progress, return null.

**rebase**
- When rebasing a feature branch onto another branch, apply all feature commits on top.
- When rebase encounters conflicting changes, detect and report conflicts.

**abortRebase**
- When aborting an in-progress rebase, stop rebase operation and restore original state.

### unit/git/cherry-pick-test.ts

- When cherry-picking a single commit without conflicts, complete successfully and create new commit.
- When cherry-picking a commit with empty message, preserve the empty message in the new commit.
- When cherry-picking a commit that was already cherry-picked (redundant), create a duplicate commit.
- When cherry-picking an empty commit, create the empty commit successfully.
- When cherry-picking an empty commit within a range of commits, include it in the range.
- When cherry-picking multiple commits without conflicts, apply all commits successfully.
- When cherry-picking with no commits in array, fail to start.
- When cherry-picking with uncommitted working tree changes, throw error or return null result.
- When cherry-picking a merge commit, apply the merge commit successfully.
- When cherry-picking a merge commit after a conflict, detect conflicts and allow resolution.

**cherry-picking with conflicts**
- When cherry-pick encounters conflicts, detect and report them.
- When resolving conflicts by overwriting files, continue cherry-pick and complete successfully.
- When resolving conflicts manually with manual resolution mapping, continue cherry-pick and complete successfully.
- When resolving conflicts manually and keeping only "ours" resolution, complete successfully with no additional changes.
- When continuing cherry-pick with outstanding unresolved files, report outstanding files not staged error.
- When continuing cherry-pick with additional untracked file changes, stage resolved files and leave untracked files in working directory.
- When aborting cherry-pick after conflict, remove conflicted files from working directory.

**cherry-picking progress**
- When cherry-picking a single commit, report progress for that one commit.
- When cherry-picking multiple commits, report progress for each commit applied.
- When cherry-picking multiple commits including one with conflict, report progress up to conflict and resume progress after resolution.

### unit/git/squash-test.ts

- When squashing one commit onto another without conflicts, merge commits and update message.
- When squashOnto commit is in the toSquash array, return error.
- When squashing multiple sequential commits without conflicts, merge all and update message.
- When squashing with null lastRetainedCommit, use repository root as base.
- When squashing non-sequential commits with reordering without conflicts, apply squash with reordering.
- When squashing a commit with conflicts, detect conflict and allow resolution via continue operation.
- When squashing with empty commit message provided, use merged commit messages as fallback.
- When squashing with invalid lastRetainedCommitRef, return error and do not start rebase.
- When squashing with invalid squashOnto commit, return error and do not start rebase.
- When squashing with empty toSquash array, return error and do not start rebase.

### unit/git/revert-test.ts

**revertCommit**
- When reverting a simple commit, create a new revert commit that undoes its changes.
- When reverting a commit that adds a new file, remove that file in the revert commit.

### unit/git/reset-test.ts

**reset**
- When performing a hard reset, discard all working directory changes.

**resetPaths**
- When resetting discarded staged files, restore them to working directory.

---

## Stash

### unit/git/stash-test.ts

**getStash**
- When an unborn repository is queried, return empty list.
- When no stash entries have been created, return empty list.
- When stash entries created by Desktop exist, return all Desktop-created entries filtering out non-Desktop entries.

**createDesktopStashEntry**
- When repo is not unborn and not in conflict or rebase state, create a stash entry successfully.
- When untracked files are stashed, remove them from working directory.

**getLastDesktopStashEntryForBranch**
- When no stash entries exist for the specified branch, return null.
- When multiple stash entries exist for a branch, return the last (most recent) entry.

**createDesktopStashMessage**
- When creating a message, format it as `!!GitHub_Desktop<branch-name>`.

**dropDesktopStashEntry**
- When deleting a stash entry by SHA, remove it from the stash list.
- When attempting to delete from empty stash, do not fail.
- When attempting to delete a non-existent stash entry, do not fail.

**popStashEntry**
- When popping a stash without conflicts, restore changes to working directory.
- When popping a stash with resolvable conflicts, restore changes and drop the stash entry.
- When popping a stash with unresolvable conflicts, throw an error.

---

## Tags & Remotes

### unit/git/tag-test.ts

**createTag**
- When a tag with a given name is created on HEAD, the tag appears in the commit's tag list.
- When a tag containing a comma is created, the full comma-containing name is preserved in the tag list.
- When multiple tags are created on the same commit, all tags appear in the commit's tag list.
- When a tag is created on a specified non-HEAD commit, the tag is attached to that commit.
- When attempting to create a tag with a name that already exists, the operation raises an error containing "already exists".

**deleteTag**
- When a tag is deleted, it no longer appears in the commit's tag list.

**getAllTags**
- When the repository has no tags, an empty map is returned.
- When tags are created, all tags are returned as a map of tag names to commit SHAs.

**fetchTagsToPush**
- When no tags have been created locally, an empty array is returned.
- When a local tag hasn't been pushed, the tag name is returned in the array.
- When a local tag is pushed to the remote, it no longer appears in the tags to push.
- When a tag is created on a local unpushed branch, the tag does not appear in the tags to push.
- When a branch push would fail, local unpushed tags are still returned.

### unit/git/remote-test.ts

**getRemotes**
- When multiple remotes exist in a repository, all remotes are returned in the list.
- When remotes are added out of order, they are returned sorted alphabetically by name.
- When querying a directory without a .git folder, an empty array is returned.
- When a remote has a partial clone filter applied, the remote is returned in the list.

**findDefaultRemote**
- When given an empty array of remotes, null is returned.
- When multiple remotes exist, the "origin" remote is returned as the default.
- When the "origin" remote is removed, another remote is returned as the default.
- When a new repository with no remotes is queried, null is returned.

**addRemote**
- When an "origin" remote is added to a repository, it is recognized as the default remote.

**removeRemote**
- When removing a remote that does not exist, the operation completes without error.

**setRemoteURL**
- When setting a URL on an existing remote, the remote's URL is updated and the operation returns true.
- When attempting to set a URL on a non-existent remote, an error is raised.

---

## Config & Gitignore

### unit/git/config-test.ts

**config**
- When looking up a config value that exists, the value is returned.
- When looking up a config value that doesn't exist, null is returned.

**GIT_CONFIG_PARAMETERS**
- When a git command includes GIT_CONFIG_PARAMETERS in the environment, the config parameters are applied.
- When both GIT_CONFIG_PARAMETERS and GIT_CONFIG_* environment variables are set, GIT_CONFIG_PARAMETERS takes precedence.

**getGlobalConfigPath**
- When the global config file exists, its real path is returned.

**setGlobalConfigValue**
- When a global config value has multiple entries, setting a new value replaces all existing entries.

**getGlobalBooleanConfigValue**
- When a global config value is "false" / "off" / "no" / "0", it is interpreted as boolean false.
- When a global config value is "true" / "yes" / "on" / "1", it is interpreted as boolean true.

### unit/git/gitignore-test.ts

**readGitIgnoreAtRoot**
- When no .gitignore file exists, null is returned.
- When a .gitignore file exists, its contents are read and returned.
- When autocrlf is true and safecrlf is true, the .gitignore file ends with CRLF line endings.
- When autocrlf is input, the .gitignore file ends with LF line endings.

**saveGitIgnore**
- When saving rules and no .gitignore exists, the file is created.
- When saving an empty string to a .gitignore file that exists, the file is deleted.
- When saving a gitignore rule, the rule is applied and matching files are ignored in repository status.
- When a file path contains special git characters, they are properly escaped in the output.

**appendIgnoreRule**
- When appending one rule to an existing .gitignore, the rule is added as a new line.
- When appending multiple rules, all rules are added as separate lines.
- When appending a file with special characters, the characters are properly escaped.

---

## Repository Setup (clone / init)

### unit/git/clone-test.ts

- When cloning a local repository, the .git directory and working files are created at the destination.
- When cloning with a specific branch specified, that branch is checked out in the cloned repository.
- When a progress callback is provided, at least one progress event is emitted with kind "clone".
- When cloning with a custom default branch name, the custom branch name is used for the cloned repository's HEAD.

### unit/git/init-test.ts

- When initializing a git repository in a directory, a .git directory is created.
- When initializing a git repository, it is created with the default branch name and status exists.

---

## Submodules & Worktrees

### unit/git/submodule-test.ts

**listSubmodules**
- When listing submodules in a fixture repository, returns the submodule SHA, path, and description tag.
- When a submodule branch is checked out, returns the updated SHA and branch description for that submodule.

**resetSubmodulePaths**
- When resetting submodule paths, reverts the submodule to its original tracked commit.
- When eliminating submodule dirty state, resets modified files in the submodule to their tracked state.

### unit/git/worktree-test.ts

**getWorktreeCheckedOutBranches**
- When main worktree exists with no linked worktrees, returns only the main branch.
- When linked worktrees are added, returns the branches checked out in both main and linked worktrees.
- When multiple linked worktrees exist, returns branches from all worktrees including the main worktree.
- When a worktree has a detached HEAD, does not include that worktree in the branch set but still includes the main worktree branch.

---
---

# Batch 2

Second set of 36 test files (no overlap with Batch 1). Same plain-English convention.

---

## Staging, Patching & Discard

### unit/git/add-test.ts

**addConflictedFile**
- When a file is conflicted, manually resolved, then staged, it should no longer appear as conflicted in status.

### unit/git/apply-test.ts

**checkPatch / on related repository without conflicts**
- When applying a patch from a related repository with no conflicting changes, returns true.

**checkPatch / on a related repo with conflicts**
- When applying a patch to a related repository with conflicting changes, returns false.

**discardChangesFromSelection**
- When an empty selection is passed, the file contents do not change.
- When a full selection is passed, all file changes are discarded.
- When a single removed line is selected for discard, that line is re-added to the file.
- When a removed hunk is selected for discard, the entire hunk is re-added to the file.
- When an added line is selected for discard, that line is removed from the file.
- When an added hunk is selected for discard, the entire hunk is removed from the file.

### unit/git/format-patch-test.ts

**in a repo with commits**
- When formatting a patch for a single commit range, returns a non-empty string.
- When formatting a patch for a multi-commit range, returns a non-empty string.
- When formatting a patch for no range (same commit), returns an empty string.

**applied in a related repo**
- When a patch is applied to a related clone repository, it applies cleanly without conflicts.

**in a repo with 105 commits**
- When creating a patch from the initial commit to HEAD in a large repository, returns a valid patch string.

---

## Refs & Reorder

### unit/git/ref-test.ts

**formatAsLocalRef**
- When formatting common branch syntax, returns refs/heads/master.
- When formatting an explicit heads/ prefix, returns refs/heads/something-important.
- When formatting a ref with a remote name included, returns the full path with remote included.

**getSymbolicRef**
- When resolving a valid symbolic ref (HEAD), returns the correct ref path.
- When attempting to resolve a missing ref, returns null.

### unit/git/reorder-test.ts

- When moving the second commit before the first, the rebase completes successfully and commits appear in the new order.
- When moving multiple commits (first and fourth) after a different commit while respecting their original log order, the rebase completes with all commits in the correct order.
- When moving the first commit after the last one, the rebase completes with the moved commit appearing at the end.
- When reordering with the root of the branch (null lastRetainedCommit), the rebase completes and uses the provided root correctly.
- When a reordering operation causes conflicts, the rebase reports conflicts, conflicts are resolved, and continuing completes successfully.
- When an invalid lastRetainedCommitRef is provided, the rebase returns an error without starting.
- When an invalid base commit is provided, the rebase returns an error without starting.
- When no commits are provided to reorder, the rebase returns an error without starting.

### unit/git/description-test.ts

**getGitDescription**
- When reading the description of an initialized repository without custom text, returns empty string.
- When the description file path is missing, returns empty string.
- When reading a custom description text that exists, returns the exact custom text.

---

## Git Core, Credentials & Environment

### unit/git/core-test.ts

**error handling**
- When expected errors are provided in options, GitError.BadRevision is returned without throwing.
- When an error is not in the expected set, the git function throws.

**exit code handling**
- When expected exit codes are provided in options, exit code 128 is returned without throwing.
- When an exit code is not in the success set, the git function throws.

**config lock file error handling**
- When a .git/config.lock file exists, the lock file path is parsed from stderr and resolved to an absolute path.
- Path normalization converts forward slashes to backslashes on Windows for gitconfig paths.
- Path normalization preserves backslashes on Windows for Windows-style gitconfig paths.
- Path normalization preserves forward slashes on Unix for gitconfig paths.

### unit/git/credential-test.ts

**parseCredential**
- When parsing credential with array syntax (wwwauth[]=foo / wwwauth[]=bar), arrays are expanded into numeric entries ([0], [1]).

**formatCredential**
- When formatting numbered array entries (wwwauth[0], wwwauth[1]), numbered brackets are transformed into unnumbered brackets with newlines between.

### unit/git/environment-test.ts

**envForProxy**
- When given an https URL with a working resolver, https_proxy is set with the resolved value.
- When given an http URL with a working resolver, http_proxy is set with the resolved value.
- When the resolver throws an error, the function fails gracefully and returns undefined.
- When the resolver returns undefined, no environment variables are set.
- When given an ftp URL, no environment variables are set as the protocol is not recognized.
- When https_proxy is already set in the environment, the function returns undefined and does not override it.
- When HTTPS_PROXY (uppercase) is already set, the function returns undefined and does not override it.
- When http_proxy is already set, the function returns undefined and does not override it.
- When ALL_PROXY is already set, the function returns undefined and does not override it.
- When all_proxy (lowercase) is already set, the function returns undefined and does not override it.

### unit/git/git-attributes-test.ts

**writeGitAttributes**
- When called on a repository path, a .gitattributes file is created containing "* text=auto".

### unit/git/lfs-test.ts

**isUsingLFS**
- When a repository does not have LFS configured, returns false.
- When LFS is tracking a path pattern (*.psd), returns true.

**isTrackedByLFS**
- When a repository is not using LFS and a file exists, returns false.
- When a file matches an LFS track pattern (*.md), returns true.
- When a file with special characters matches an LFS track pattern (*.md), returns true.

**filesNotTrackedByLFS**
- When given a file that does not match any LFS track pattern, the file is included in the returned list.
- When given a file matching an LFS track pattern (*.png), the file is excluded from the returned list.
- When given a file in a subfolder matching an LFS track pattern (*.png), the file is excluded.
- When given a file matching a subfolder-specific LFS pattern (app/src/*.png), the file is excluded.

---

## Terminal & Stream Output

### unit/git/create-tail-stream-test.ts

**createTailStream**
- When piped a stream with max length 3 and input "hello", keeps only the tail "llo".
- When piped a stream with max length 5 and input "hello", keeps the entire "hello".
- When piped a stream with max length 10 and inputs "hello" + "world", keeps the entire "helloworld".
- When piped a stream with max length 8 and inputs "hello" + "world", keeps only the tail "lloworld".
- When piped a stream with max length 10 and inputs "0" through "9", keeps the entire "0123456789".
- When piped a stream with max length 8 and inputs "0" through "9", keeps only the tail "23456789".
- When piped individual characters "helloworld" with max length 8, keeps only the tail "lloworld".

### unit/git/create-terminal-stream-test.ts

**terminal-stream**
- When piped git clone progress output, outputs correctly formatted lines without progress bar artifacts.
- When written varying chunk sizes from 1 to 2048 bytes and back down, handles all chunk sizes and preserves all data.
- When written an empty buffer, outputs an empty string.

### unit/git/push-terminal-chunk-test.ts

**basic functionality**
- When appending a string chunk to an empty buffer, the chunk is added to the array.
- When appending multiple string chunks, all chunks are preserved in order.
- When appending a Buffer chunk, it is converted to string and added.
- When appending an empty string chunk, the empty string is added.
- When appending an empty Buffer chunk, the empty buffer as string is added.

**capacity management**
- When total length equals capacity, no trimming occurs.
- When total length is under capacity, no trimming occurs.
- When overrun exceeds the first chunk length, the entire first chunk is removed and remaining chunks trimmed.
- When overrun is less than the first chunk length, only the first chunk is partially trimmed.
- When multiple chunks must be removed to stay under capacity, all excess chunks are removed.
- When a single chunk exceeds capacity, it is trimmed from the beginning to fit exactly.
- When capacity is zero, everything is trimmed and the result is empty.
- When capacity is one, only the last character is kept.

**rolling buffer behavior**
- When repeatedly pushing chunks with capacity 15, the buffer keeps only the most recent 15 characters.
- When repeatedly pushing chunks, the newest content is preserved when trimming occurs.

**edge cases**
- When handling unicode characters (e.g. 日本語), counts characters not bytes and respects capacity.
- When trimming unicode characters, trims correctly while counting characters.
- When handling emoji characters that are 2 code units in JavaScript, counts correctly.
- When mixing Buffer and string inputs, both types are handled and stored as strings.
- When handling newlines and special characters (\r\n), they are preserved.
- When handling ANSI escape sequences, they are preserved in the output.

**pre-existing buffer state**
- When pushing to a pre-populated buffer, new chunks are appended without affecting existing content.
- When adding a chunk that exceeds capacity, pre-existing content is trimmed correctly.

**boundary conditions**
- When the buffer is exactly at capacity boundary, no trimming occurs.
- When one character over capacity, trimming removes exactly one character from the start.
- When capacity is very large and chunks are small, content is stored without trimming.
- When many small chunks are added, the rolling buffer correctly limits total size.
- When overrun exactly equals a chunk length, the chunk is removed entirely and the remaining buffer trimmed.

**realistic terminal output scenarios**
- When simulating git push output with multiple progress lines, all lines are captured and preserved.
- When simulating progress output with carriage returns, output includes the final progress message.
- When adding 50 lines of output with capacity 100, only the most recent content fits within capacity.

### unit/git/multi-operation-terminal-output-test.ts

- When executing two sequential git operations, output from each operation is collected separately.
- When two git operations execute before a subscriber subscribes, output is buffered and available when the subscriber attaches.
- When two git operations execute through a callback-based interface, the original callback is invoked exactly once.
- When small capacity (10) is set, output from streaming operations is not trimmed when pushed immediately.
- When small capacity (10) is set, output is trimmed to capacity when buffered operations are accessed by a late subscriber.
- When multiple subscribers attach, both receive the same buffered output chunk.

---

## Rebase Conflict Detection & Progress

### unit/git/rebase/detect-conflict-test.ts

**detect conflicts**
- When rebasing a feature branch onto a base branch with conflicts, rebase returns ConflictsEncountered.
- When rebasing encounters conflicts, REBASE_HEAD status contains correct original branch tip, base branch tip, and target branch.
- When rebasing encounters conflicts, the working directory contains exactly 2 conflicted files.
- When rebasing encounters conflicts, the repository is in detached HEAD state.

**abort after conflicts found**
- When aborting a rebase after conflicts, REBASE_HEAD is no longer present in status.
- When aborting a rebase after conflicts, the working directory contains no changes.
- When aborting a rebase after conflicts, the repository returns to the feature branch.

**attempt to continue without resolving conflicts**
- When attempting to continue rebase without resolving conflicts, returns OutstandingFilesNotStaged.
- When attempting to continue without resolving, REBASE_HEAD remains in status with original information.
- When attempting to continue without resolving, conflicted files remain in the working directory.

**continue after resolving conflicts**
- When resolving conflicts by rewriting files and continuing, returns CompletedWithoutError.
- When rebase completes successfully, REBASE_HEAD is no longer present in status.
- When rebase completes successfully, the working directory contains no changes.
- When rebase completes successfully, the repository returns to the feature branch.
- When rebase completes successfully, the branch tip is updated to a new ref.

**continue with additional changes unrelated to conflicted files**
- When continuing rebase with unrelated tracked file changes, returns CompletedWithoutError.
- When continuing with unrelated changes, untracked files remain in the working directory.
- When continuing with unrelated changes, modified unconflicted files are included in the commit.
- When continuing with unrelated changes, the repository returns to the feature branch.
- When continuing with unrelated changes, the branch tip is updated to a new ref.

**continue with tracked change omitted from list**
- When continuing rebase while omitting a required tracked file, returns OutstandingFilesNotStaged error.

### unit/git/rebase/progress-test.ts

**skips a normal repository**
- When calling getRebaseSnapshot on a normal repository without rebase state, returns null.

**can parse progress**
- When starting a rebase that encounters conflicts, returns ConflictsEncountered.
- When rebasing and capturing progress, reports step-by-step progress before encountering conflicts.
- When rebase is in progress with conflicts, getRebaseSnapshot returns a snapshot with correct commit count and progress.
- When rebase is in progress, the repository is in detached HEAD state.

**can parse progress for long rebase**
- When starting a long rebase (10 commits) that encounters conflicts, returns ConflictsEncountered.
- When rebasing 10 commits and capturing progress, reports initial progress (1/10) before conflicts.
- When resolving conflicts through all commits in a long rebase, progress updates for each commit up to 10/10.
- When a long rebase is in progress, getRebaseSnapshot returns a snapshot with all 10 commits and correct progress.
- When a long rebase is in progress, the repository is in detached HEAD state.

---

## Pull (ahead-only / behind-only) & Ahead/Behind Store

### unit/git/pull/only-ahead-test.ts

**by default**
- When pulling with default config and local branch is ahead, does not create a new commit.
- When pulling with default config and local branch is ahead, the local branch remains different from the tracking branch.
- When pulling with default config and local branch is ahead, the local branch remains ahead of the tracking branch.

**with pull.ff=false set in config**
- When pulling with pull.ff=false and local branch is ahead, does not create a new commit.
- When pulling with pull.ff=false and local branch is ahead, the local branch remains different from the tracking branch.
- When pulling with pull.ff=false and local branch is ahead, the local branch remains ahead of the tracking branch.

**with pull.ff=only set in config**
- When pulling with pull.ff=only and local branch is ahead, does not create a new commit.
- When pulling with pull.ff=only and local branch is ahead, the local branch remains different from the tracking branch.
- When pulling with pull.ff=only and local branch is ahead, the local branch remains ahead of the tracking branch.

### unit/git/pull/only-behind-test.ts

**with pull.rebase=false and pull.ff=false set in config**
- When pulling with merge strategy and local branch is behind, creates a new merge commit.
- When pulling with merge strategy and local branch is behind, the merge commit is different from the remote branch.
- When pulling with merge strategy and local branch is behind, the local branch becomes ahead of the tracking branch after merge.

**with pull.ff=only set in config**
- When pulling with fast-forward only and local branch is behind, fast-forwards without creating a merge commit.
- When pulling with fast-forward only and local branch is behind, the local branch becomes the same as the remote branch.
- When pulling with fast-forward only and local branch is behind, the local branch is no longer behind the tracking branch.

### unit/ahead-behind-store-test.ts

**tryGetAheadBehind**
- When the range is not cached, returns undefined.

**getAheadBehind**
- When calculating ahead/behind for diverged branches, correctly computes ahead and behind counts for both branches.
- When calling getAheadBehind multiple times for the same range, returns the cached result without recalculating.
- When disposing the returned disposable, aborts the operation and prevents the callback from being called even after the worker completes.

---

## Branch Grouping & Multi-Commit Operations

### unit/group-branches-test.ts

**Branches grouping**
- When grouping branches with current, default, recent, and other branches, returns three groups: default branch, recent branches, and other branches.

### unit/multi-commit-operation-test.ts

**isIdMultiCommitOperation**
- When called with 'Rebase' / 'Cherry-pick' / 'Squash' / 'Merge' / 'Reorder', returns true.
- When called with unknown operation strings, returns false.

**conflictSteps**
- When checking the conflict steps array, it includes the ShowConflicts step.
- When checking the conflict steps array, it includes the ConfirmAbort step.
- When checking the conflict steps array, it does not include the ChooseBranch step.

**isConflictsFlow**
- When the popup is not open, returns false regardless of state.
- When the state is null, returns false regardless of popup status.
- When the step is not a conflict step, returns false even if the popup is open.
- When in the ShowConflicts step with the popup open, returns true.
- When in the ConfirmAbort step with the popup open, returns true.

**getMultiCommitOperationChooseBranchStep**
- When the tip state is not valid, throws an error.
- When the tip state is valid, returns a ChooseBranch step containing current branch, default branch, and all branches.

---

## Git Store, Cache & Changes Filtering

### unit/git-store-test.ts

**loadCommitBatch**
- When loading commits from HEAD with a limit of 100, includes HEAD and returns exactly 100 commits with the correct SHA.

**Discarding changes**
- When discarding a single changed file from a repo with multiple uncommitted files, only that file is removed and the rest remain.
- When discarding a renamed file that appears as a modified change, the file is successfully removed from the working directory.

**undo first commit**
- When undoing the first commit, the repository transitions to an unborn state with no current tip.
- When undoing the first commit, the commit message is pre-filled with the original commit message.
- When undoing the first commit, the local commit list is cleared and the undo dialog state is reset.
- When undoing the first commit, no files remain staged in the index (verified against the empty tree).

**repository with HEAD file**
- When a repository contains a file named HEAD and that file is modified, it can be discarded cleanly without error.

**loadBranches**
- When a cloned repository is queried for remotes, it has exactly one remote defined.
- When loading branches with a tracking branch set, local and remote branches are merged correctly and the tracking relationship is preserved.
- When the upstream remote branch is deleted and the repository is fetched with prune, local tracking information is preserved and not cleared.

### unit/git-store-cache-test.ts

**GitStoreCache**
- When the same repository is requested twice, the same GitStore instance is returned both times.
- When a repository is removed from the cache and then requested again, a different GitStore instance is returned.

### unit/filter-changes-logic-test.ts

**applyFilterOptions**
- When no status or selection filters are enabled, all files of any type are shown.
- When multiple filters are active (staged + new file), only files matching all active filters are shown (AND logic).
- When both included and excluded filters are active simultaneously, no files match (a file cannot be both staged and unstaged).
- When filtering for new files, untracked files are treated as new files and pass the filter.
- When the excluded filter is active, only unstaged files are shown and staged files are hidden.

**isCommittingFileHiddenByFilter**
- When no filters are active, returns false even if some files would be hidden by filtering.
- When filtering is active and the commit includes files not in the filtered list, returns true (hidden files are being committed).
- When all committed files remain visible in the filtered list, returns false.

**getNoResultsMessage**
- When no filters are active, returns undefined with no message.
- When a text filter is active, the message includes the search text in quotes.
- When multiple filters are active, the message includes labels for each active filter.
- When three or more filters are active, the message formats them with commas and "and" before the last filter.

**hasActiveFilters**
- When both text and option filters are empty, returns false.
- When either text or option filters are enabled, returns true.

**applyFilters**
- When the changes filter UI is hidden, filter logic is bypassed and files are always shown; when shown, normal filter logic applies.

### unit/text-diff-expansion-test.ts

- When a diff's last hunk does not reach the end of the file, a dummy hunk is added at the bottom to enable expansion.
- When a diff's last hunk already reaches the end of the file, no dummy hunk is added.
- When expanding a hunk upward without reaching the top, the hunk header updates to reflect the expanded range and the first line remains the header.
- When expanding a hunk upward and reaching the top, the hunk header adjusts to start at line 1.
- When expanding a hunk downward without reaching the bottom, the hunk header updates with correct line counts.
- When expanding a hunk downward and reaching the bottom, the hunk header adjusts to include all remaining lines.
- When expanding and the gap between this and the next hunk is smaller than the expansion size, the two hunks merge into one.
- When expanding the entire file, the result is a single hunk with all lines plus the header, with consecutive correct line numbers.

### unit/repository-test.ts

**name**
- When a repository path is a nested directory, the repository name is derived from the last path component.
- When a repository path is at the root of a drive, the repository name is the drive letter with backslash.

---

## Commit Message Formatting & Text Parsing

### unit/format-commit-message-test.ts

**formatCommitMessage**
- When given a summary only, always adds a trailing newline.
- When given a summary with null description, omits the description.
- When given a summary with empty-string description, omits the description.
- When given a summary and description, adds two newlines between them.
- When appending trailers to a summary-only message, adds trailer lines after the summary with a blank-line separator.
- When appending trailers to a message with description, adds trailer lines after the description with a blank-line separator.
- When duplicate trailers are in the description and provided, merges them into a single trailer section.
- When malformed trailers (missing space after colon) are in the description, fixes them up.
- When `---` appears in the description, does not treat it as the end of the commit message.

### unit/wrap-rich-text-commit-message-test.ts

**wrapRichTextCommitMessage**
- When text is exactly 72 characters, does not hard wrap.
- When text exceeds 72 characters, hard wraps at the 72-character boundary with ellipsis continuation.
- When the summary exceeds 72 characters and body text is provided, hard wraps the summary and joins continuation with the body.
- When the summary is exactly 72 characters after link shortening, maintains wrap correctly.
- When an issue link would push the summary over 72 chars, takes link shortening into consideration.
- When multiple issue links exist in the summary, all are shortened correctly.
- When the link itself exceeds the 72-character boundary, wraps the link with ellipsis on both sides.

### unit/squashed-commit-description-test.ts

**getSquashedCommitDescription**
- When building squashed descriptions with no coauthors, combines commit summaries and descriptions in sequence.
- When building squashed descriptions with coauthor trailers, excludes coauthor trailers from output.
- When building squashed descriptions, trims whitespace from summaries and descriptions.

## Remote URL Parsing & Repository Naming

### unit/remote-parsing-test.ts

**URL remote parsing**
- When parsing an HTTPS URL with `.git` suffix, extracts hostname, owner, and repo name.
- When parsing an HTTPS URL with `-git` suffix, extracts components with `-git` preserved.
- When parsing an HTTPS URL with both `-git` and `.git` suffixes, removes `.git` and preserves `-git`.
- When parsing an HTTPS URL without git suffix, extracts hostname, owner, and repo name.
- When parsing an HTTPS URL with trailing slash, strips slash and extracts components.
- When parsing an HTTPS URL with embedded username, ignores username and extracts components.
- When parsing an SSH URL, extracts hostname, owner, and repo name.
- When parsing an SSH URL with custom username, uses the custom username and extracts components.
- When parsing an SSH URL without `.git` suffix, extracts components.
- When parsing an SSH URL with `-git` suffix only, preserves `-git` in repo name.
- When parsing an SSH URL with both `-git` and `.git` suffixes, removes `.git` and preserves `-git`.
- When parsing an SSH URL with trailing slash, strips slash and extracts components.
- When parsing a git protocol URL, extracts hostname, owner, and repo name.
- When parsing a git protocol URL without `.git` suffix, extracts components.
- When parsing a git protocol URL with trailing slash, strips slash and extracts components.
- When parsing an SSH URL with `ssh://` prefix, extracts hostname, owner, and repo name.
- When parsing an SSH URL with `ssh://` prefix and trailing slash, strips slash and extracts components.
- When parsing an invalid HTTP URL with missing repo name, returns null.
- When parsing an invalid SSH URL with missing repo name, returns null.
- When parsing an invalid git protocol URL with missing repo name, returns null.
- When parsing an invalid HTTP URL with missing owner, returns null.
- When parsing an invalid SSH URL with missing owner, returns null.
- When parsing an invalid git protocol URL with missing owner, returns null.

### unit/remove-remote-prefix-test.ts

**removeRemotePrefix**
- When removing the remote prefix from `remote/branch`, extracts the branch name.
- When removing the remote prefix from `remote/branch/path`, removes only the remote part and preserves remaining slashes.
- When the string has no remote prefix, returns null.

### unit/sanitized-repository-name-test.ts

**sanitizedRepositoryName**
- When given a valid repo name, leaves it unchanged.
- When given a name with invalid characters, replaces them with dashes.
- When given a name with spaces, replaces them with dashes.
- When given a name ending with a slash, replaces it with a dash.
- When given a name starting with a plus sign, replaces it with dashes.
- When given a name starting with a minus sign, allows it unchanged.
- When given a name with escape sequences, replaces backslash characters with dashes.
- When given a name starting with a dot, allows it unchanged.
- When given a name with double dashes, allows them unchanged.
- When given a name with emoji, replaces emoji with a single dash.

### unit/write-default-readme-test.ts

**writeDefaultReadme**
- When writing a default README without description, creates README.md with only the repository name as heading.
- When writing a README with description provided, creates README.md with heading and description text.

---
---

# Batch 3 — UI & Store (for macOS UI/integration tests)

Generic **store and UI behavior** specs — the intent is to port them into native macOS
UI/integration tests. GitHub-, API-, and Electron-only cases (accounts, GitHub repo records,
repo matching, remote-URL sync, fork pruning, owner/dotcom/enterprise grouping, repo icons,
emails, type guards) have been removed. What remains maps cleanly to a local-first macOS model;
`localStorage` → `UserDefaults`, the flux stores → `@Observable` view-model state.

---

## Stores — Repositories & State

### unit/cloning-repositories-store-test.ts

- When initialized, the store starts with no repositories.

**remove**
- When removing a repository that was added, it is removed from the store.
- When removing a repository that does not exist, no error is thrown.

**getRepositoryState**
- When getting the state of an unknown repository, null is returned.

**emitUpdate**
- When state changes, listeners are notified of the update.

### unit/repositories-store-test.ts

**adding a new repository**
- When a new repository is added by path, it is contained in the store.

**getting all repositories**
- When multiple repositories are added, all are returned.

### unit/repository-state-cache-test.ts

- When updating branches state, the cached branches state reflects branch loading status.
- When updating changes state, the cached changes state reflects the working directory, commit message, and co-authoring flag.
- When updating compare state, the cached compare state reflects the history form state, filter text, and commit SHAs.

### unit/local-storage-test.ts

**setBoolean / getBoolean**
- When setting a boolean to true, the value round-trips correctly.
- When setting a boolean to false, the value round-trips correctly.
- When no key is found, the default value is returned.
- When a malformed string is encountered, the default value is returned.
- When the string '0' is found, false is returned and the default value is ignored.
- When the string 'true' is found, true is returned.
- When the string 'false' is found, false is returned.

**setNumber / getNumber**
- When setting a valid number, it round-trips correctly.
- When setting zero with a default value provided, zero is returned and the default value is ignored.
- When no key is found, the default value is returned.
- When a malformed string is encountered, the default value is returned.
- When the string '0' is found, zero is returned and the default value is ignored.

### unit/database-migration-test.ts

**conditionalVersion**
- When schemaVersion is undefined, all versions are registered and the database opens successfully.
- When schemaVersion equals the highest version number, all versions are registered and the database opens successfully.
- When schemaVersion is lower than the highest version, versions higher than schemaVersion are skipped and their indexes are not created.

---

## Stores — Update Reducers

### unit/stores/updates/update-changed-files-test.ts

**workingDirectory**
- When clearPartialState is true, partial line selection on files is cleared to None.
- When clearPartialState is false, partial line selection on files is preserved.
- When updateChangedFiles is called, a new working directory object is returned instead of reusing the old one.

**selectedFileIDs**
- When no file selection exists in the previous state, the first file (sorted alphabetically) is selected.
- When a previously selected file still exists in the new status, that file remains selected.
- When a previously selected file no longer exists in the new status, the selection is cleared to an empty list.

**diff**
- When a selected file from the previous state is not found in the current status, the diff is cleared to null.
- When a selected file from the previous state is found in the current status, the previous diff is preserved and returned.

### unit/stores/updates/update-conflict-state-test.ts

**merge conflicts**
- When MERGE_HEAD is not found, conflict state returns null.
- When MERGE_HEAD exists and merging, manual resolutions from the previous state are preserved.
- When MERGE_HEAD is set but branch or tip are undefined, conflict state returns null.
- When MERGE_HEAD is set and conflicted files exist, a new merge conflict state is created with an empty manual resolutions map.
- When the branch changes during a merge, the abort counter is incremented.
- When the conflict is resolved and the commit tip has not changed, the abort counter is incremented.
- When the conflict is resolved and the commit tip has changed, the success counter is incremented.

**rebase conflicts**
- When REBASE_HEAD is not found, conflict state returns null.
- When REBASE_HEAD is set and conflicted files exist, a new rebase conflict state is created with an empty manual resolutions map.
- When rebase is ongoing, manual resolutions from the previous state are preserved.
- When the branch changes during rebase while conflicts remain, the abort counter is incremented.
- When the conflict is resolved but the tip has not changed, the abort counter is incremented.
- When the conflict is resolved and the tip has changed, the abort counter is not incremented.

---

## UI — List & Section Selection

### unit/list-selection-test.ts

**findNextSelectableRow**
- When selecting down from outside the list (row -1), returns the first row (0).
- When the first row is not selectable and selecting down from outside the list, returns the first selectable row (1).
- When selecting down from the last row, wraps to the first row (0).
- When selecting up from the top row, wraps to the last row.

### unit/section-list-selection-test.ts

**findNextSelectableRow**
- When selecting down from outside the list (invalid index path), returns the first row of the first section.
- When the first row of the first section is not selectable and selecting down from outside the list, returns the first selectable row.
- When selecting down from the last row of a section, wraps to the first row of the first section.
- When selecting up from the top row of the first section, wraps to the last row of the last section.
- When selecting down from the last row of a section, moves to the first row of the next section.
- When selecting up from the first row of a section, moves to the last row of the previous section.

---

## UI — Popups, Search & Icons

### unit/popup-manager-test.ts

**currentPopup**
- When no popups are added, returns null.
- When multiple popups are added, returns the last added non-error popup.
- When an error popup is added after non-error popups, returns the error popup (error popups have priority).

**isAPopupOpen**
- When no popups are added, returns false.
- When a popup is added, returns true.

**getPopupsOfType / areTherePopupsOfType**
- When popups of a given type exist, returns an array containing those popups.
- When no popups of a given type exist, returns an empty array.
- When a popup of a given type exists, areTherePopupsOfType returns true.
- When no popup of a given type exists, areTherePopupsOfType returns false.

**addPopup**
- When a popup is added, it appears in the stack with the correct type and can be retrieved.
- When multiple popups of the same type are added, only one is kept in the stack.
- When popups of different types are added, all are stored in the stack.
- When the popup limit is reached, the oldest popup is removed and the newest is added.

**addErrorPopup**
- When an error popup is added, it appears in the stack with Error type.
- When multiple error popups are added, all are stored (error popups can duplicate).
- When the error popup limit is reached, the oldest error popup is removed.

**updatePopup / removePopup**
- When a popup is updated with new properties, the stored popup reflects the updated values.
- When a popup with an id is removed, only that specific popup is deleted.
- When attempting to remove a popup using only its type, the popup is not removed (only id-based removal works).
- When popups of a given type are removed, all popups of that type are deleted while others remain.
- When a popup is removed by its id, only that specific popup is deleted while others remain.

**popup id increment**
- When the first popup is added, it is assigned id 1.
- When multiple popups are added sequentially, each gets an incrementing id (1, 2, 3…).
- When error popups are added, they receive incrementing ids along with non-error popups.
- When a popup is removed, new popups continue incrementing from the last used id (not resetting).

### unit/fuzzy-find-test.ts

(Generic fuzzy-matching UI util — reusable for filtering any list, e.g. branches or repositories.)
- When searching by a numeric field, returns the matching item containing that number.
- When searching by a name field, returns the matching item containing that name.
- When searching by title keywords, returns the matching item with a matching title.
- When searching for a non-matching pattern, returns no results.

---

## UI — Path & Text Truncation

### unit/path-text-test.ts

**truncateMid**
- When the string fits within the length, returns the string unchanged.
- When the length is zero or negative, returns an empty string.
- When the length is 1, returns a single ellipsis character.
- When the string exceeds the length, truncates from the middle keeping both ends, with an ellipsis in the middle.

**truncatePath**
- When the string fits within the length, returns the string unchanged.
- When the length is zero or negative, returns an empty string.
- When the length is 1, returns a single ellipsis character.
- When the string exceeds the length, truncates from the middle keeping both ends, with an ellipsis.
- When a path separator exists and truncation is needed, favors removing directory components over the filename.

**extract**
- When given an untracked submodule path with trailing separator, extracts the submodule name as filename and the parent directory path.
- When given a tracked submodule path without trailing separator, extracts the submodule name as filename and the parent directory path.
- When given a file path, extracts the filename and the containing directory path.

### unit/truncate-with-ellipsis-test.ts

- When the string is shorter than the max length, does not truncate.
- When the string equals the max length, does not truncate.
- When the string exceeds the max length, truncates to the max length with an ellipsis.
- When a unicode string is shorter than the max length, does not truncate.
- When a unicode string equals the max length, does not truncate.
- When a unicode string exceeds the max length, truncates to the max length with an ellipsis.

---

## UI — Formatting (duration / number / bytes)

### unit/format-duration-test.ts

**formatPreciseDuration**
- When the duration is less than 1000 ms, returns "0s".
- When the duration is a whole unit (days, hours, minutes, seconds), shows all units from largest down with zeroes.
- When the duration is negative, treats it as the absolute value.

### unit/format-number-test.ts

**formatNumber — integers**
- When the number is 0–999, formats without a thousands separator.
- When the number is 1000–999999, inserts a comma thousands separator.
- When the number is 1000000 and above, formats with multiple separators.
- When using European-style format, inserts a dot thousands separator.
- When using a space thousands separator, formats with spaces.
- When the thousands separator is disabled, formats without any separator.

**formatNumber — decimals & negatives**
- When the decimal has a dot separator configured, uses a dot for the decimal point.
- When the decimal has a comma separator configured (European), uses a comma for the decimal point.
- When a large number has decimals, formats both integer and decimal parts correctly.
- When the value is a negative integer, formats with a minus sign and thousands separator.
- When the value is a negative decimal, formats with a minus sign and decimal point.

**formatNumber — edge cases**
- When the value is Infinity, returns "Infinity".
- When the value is -Infinity, returns "-Infinity".
- When the value is NaN, returns "NaN".
- When the value is a very small decimal, displays all decimal places.

**formatCompactNumber — magnitudes**
- When the number is 0–999, formats without compaction.
- When a decimal is under 1000, formats without compaction.
- When the number is 1000+, uses the k suffix; under 10k shows one decimal, 10k+ shows none.
- When the number is 1,000,000+, uses the m suffix; under 10m shows one decimal, 10m+ shows none.
- When the number is 1,000,000,000+, uses the b suffix; under 10b shows one decimal, 10b+ shows none.
- When the number is 1,000,000,000,000+, uses the t suffix; beyond 1 quadrillion caps at t with a thousands separator.
- When a configured decimal separator is comma or space, uses that separator in compact format.

**formatCompactNumber — edge cases & explicit decimals**
- When the value is Infinity / -Infinity / NaN, returns the corresponding literal string.
- When the value is a negative large number, applies the k/m suffix to the absolute value with a minus sign.
- When a decimals parameter is provided, it overrides the default decimal logic.
- When decimals is 0, removes decimal places even for values under 10.
- When decimals is explicit across magnitude boundaries, uses the specified precision.
- When a decimals parameter is provided with a non-default separator, uses the configured separator.
- When using space thousands and dot decimal / space thousands and comma decimal, formats correctly.
- When the thousands separator is disabled, formats without a thousands separator in compact form.

### unit/format-test.ts

**formatRebaseValue**
- When the value is negative, clamps to 0.
- When the value is positive and above 1, clamps to 1.
- When the value is a fraction, rounds to two significant figures.
- When the value is infinity, returns a value between 0 and 1.

### unit/bytes-test.ts

**formatBytes**
- When given a byte count with a decimal-places parameter, rounds to the specified decimal places.
- When the byte count reaches the KiB threshold (1024), uses the KiB unit.
- When the byte count reaches the MiB threshold, uses the MiB unit.
- When the byte count reaches the GiB threshold, uses the GiB unit.
- When the byte count reaches the TiB threshold, uses the TiB unit.
- When the value is NaN, returns "NaN".
- When the value is Infinity, returns "Infinity".

---

## UI — Welcome Flow, Grouping & Progress

### unit/welcome-test.ts

**hasShownWelcomeFlow**
- When no localStorage value exists, returns false.
- When localStorage contains a non-numeric value, returns false.
- When localStorage contains "0", returns false.
- When localStorage contains "1", returns true.

**markWelcomeFlowComplete**
- When called, sets the localStorage value to "1".

### unit/progress/clone-test.ts

**CloneProgressParser#parse**
- When parsing a "Receiving objects" line, returns a non-null progress result.
- When parsing a "Resolving deltas" line, returns a non-null progress result.
- When parsing a "Checking out files" line, returns a non-null progress result.
- When parsing a remote compression line, returns a non-null progress result.
- When parsing progress in relative weight order (compression → receiving → resolving → checking out), weights each step to 10%, 60%, 10%, and 20% respectively.
- When receiving a line out of step order, ignores the out-of-order line and returns a context result.
- When parsing an unrecognized line (e.g. "Counting objects…"), returns a context result.

### unit/progress/git-test.ts

**GitProgressParser**
- When creating a parser with zero steps, throws an error.
- When parsing with one step, calculates progress as a fraction of that step.
- When parsing with multiple weighted steps, applies each step's weight to the overall percentage.
- When steps occur out of order, enforces that subsequent steps cannot go backward and returns a context result.
- When parsing a line without a total (only current count), extracts title, text, value and marks done=false with undefined percent/total.
- When parsing a final line without a total (with "done."), extracts title, text, value and marks done=true with undefined percent/total.
- When parsing a line with a total, extracts title, text, value, done=false, percent, and total.
- When parsing a final line with a total (100%), extracts title, text, value, done=true, percent, and total.
- When parsing a line with total and throughput, extracts the progress fields and ignores throughput data.
- When parsing a final line with total and throughput, extracts the fields with done=true.
- When parsing a non-progress line (e.g. server messages), returns null.

### unit/progress/lfs-test.ts

**GitLFSProgressParser#parse**
- When parsing a valid LFS progress line, returns a result with kind "progress".
- When parsing an unrelated line, returns a result with kind "context".

---

## Models & Commit Authorship

### unit/unique-coauthors-as-authors-test.ts

**getUniqueCoauthorsAsAuthors**
- When processing commits with no coauthors (only Signed-Off-By trailers), returns an empty array.
- When extracting a coauthor from a commit, returns the coauthor with the correct name and email.
- When a coauthor appears in multiple commits, returns only one unique instance.
- When the same email appears with different names across commits, returns both as separate coauthors.
- When the same name appears with different emails across commits, returns both as separate coauthors.
- When extracting multiple distinct coauthors, returns all unique coauthors with their emails and names.

### unit/parse-files-to-be-overwritten-test.ts

**parseFilesToBeOverwritten**
- When parsing a pull error with conflicting changes, correctly extracts the list of affected files from stderr.
- When parsing a pull rebase error with conflicting changes, returns an empty list (these errors cannot be parsed).
- When parsing a merge error with local changes, correctly extracts the list of affected files from stderr.
- When parsing a checkout error with local changes, correctly extracts the list of affected files from stderr.

### unit/cloning-repository-test.ts

**name**
- When extracting the repository name from the path and URL, returns the name from the URL, not the path.
- When extracting the repository name with a .git suffix in the URL, removes the suffix from the name.
- When providing the name of the repository being cloned, correctly extracts the name.

**identity**
- When generating repository identifiers, each repository gets a unique ID.
- When generating a hash from repository identity, produces a hash containing the repository path.

### unit/path-test.ts

**encodePathAsUrl**
- On Windows, normalizes mixed forward/backward slash separators in paths.
- On Windows, URL-encodes spaces and hash characters in paths.
- On macOS and Linux, URL-encodes spaces and hash characters in paths.

**resolveWithin**
- When resolving paths outside the root directory, returns null to reject traversal outside bounds.
- When resolving paths that traverse out and then back into the root, succeeds and returns the root path.
- When resolving paths containing null bytes, returns null to reject invalid paths.
- When resolving absolute relative paths that stay within the root, succeeds and returns the resolved path.
- On non-Windows systems, when resolving symlink paths that traverse outside the root, returns null to block the traversal.
- On non-Windows systems, when resolving symlink paths that traverse outside and back into the root, succeeds and returns the resolved path.
