# Instant Status and Diff Loading

## Purpose

Make the changed-file list and selected-file diff feel responsive when a repository opens, refreshes, or the user switches between changed files.

The product goal is not to make every Git operation instantaneous. The product goal is to show the first useful state quickly, keep the interface stable while slower work continues, and prevent stale background work from replacing the user's current selection.

## User Actions

- Open the app and see the last selected repository quickly.
- See changed files as soon as working tree status is available.
- Select a changed file and get immediate row selection feedback.
- Switch rapidly between changed files without old diffs flashing into view.
- Continue viewing the previous diff briefly while the next diff is loading.
- See a loading state only when diff loading is perceptibly slow.

## Business Logic

- Repository shell state is shown before every repository detail has loaded.
- Working tree status is treated as the first high-value repository result because it drives the changed-file list and initial diff selection.
- Changed-file list loading is separate from diff loading.
- The changed-file list is allowed to update before the selected file's diff is ready.
- On repository open or refresh, the app preserves the current selected changed file if that file still exists.
- If no changed file is selected and the repository has changes, the first changed file is selected automatically.
- The app loads a diff only for the selected changed file, not for every changed file in the repository.
- Switching the selected file updates selection state immediately, then starts a new asynchronous diff request.
- Each diff request is associated with the selected repository, selected file, and current selection state.
- Before applying a completed diff, the app checks whether the same repository and file are still selected.
- If the user has selected another file, the older diff result is ignored.
- If a diff is already available for the same selected file and equivalent file state, it can be reused instead of reloaded.
- Previous renderable diff content may remain visible while the next diff is loading, but user actions on stale content are disabled.
- A loading indicator is delayed briefly so fast diff loads do not produce flicker.
- If loading exceeds the delay threshold, the UI communicates that the next diff is still loading.
- Large, binary, image, submodule, and unrenderable files are classified before normal text-diff rendering is attempted.
- Background repository details can continue loading after the changed-file list is already usable.

## Startup Flow

1. Restore persisted app state such as the selected repository, window state, and repository list.
2. Render the repository shell as soon as enough persisted state is available.
3. Start repository refresh work asynchronously.
4. Prioritize working tree status so changed files can be shown quickly.
5. Parse the working tree status into changed-file records.
6. Preserve existing file selection and check state where paths still exist.
7. Select the first changed file when there is no valid current selection.
8. Publish the changed-file list to the UI.
9. Start loading the selected file's diff.
10. Continue loading slower repository metadata such as history, remotes, branch state, stash state, and pull request context.

## File Selection Flow

1. The user selects a changed file.
2. The selected row updates immediately.
3. Any in-flight diff request for the previous selection is made obsolete.
4. The app checks whether a matching diff is already cached or still valid.
5. If a cached diff is valid, it is shown immediately.
6. Otherwise, the app starts a new per-file diff request.
7. The previous renderable diff may remain visible during the short transition.
8. If the new diff completes quickly, it replaces the previous diff without showing a loading indicator.
9. If the new diff is slow, a delayed loading state is shown.
10. When the diff completes, it is applied only if the same file is still selected.

## Git Operations

| User-Facing Need | Git Operation | Conceptual Git CLI |
|---|---|---|
| Load changed-file list | Read working tree status | `git --no-optional-locks status --untracked-files=all --branch --porcelain=2 -z` |
| Load selected tracked-file diff | Compute one file diff | `git diff --no-ext-diff --patch-with-raw -z --no-color HEAD -- <path>` |
| Load selected untracked-file diff | Compare file with empty input | `git diff --no-index -- /dev/null <path>` |
| Load changed files for history/ranges | Read names and counts without full patches | `git diff -C -M -z --raw --numstat <range> --` |
| Detect unrenderable or special diff cases | Inspect diff metadata and attributes | `git diff --numstat -z`, `git check-attr` |

## Performance Rules

- Prefer one compact status operation over multiple path-by-path status calls.
- Use machine-readable Git output with NUL delimiters for reliable and fast path parsing.
- Avoid optional Git locks when reading status.
- Avoid external diff tools for app-rendered diffs.
- Do not compute every changed file's patch during startup.
- Do not block changed-file list rendering on history, remote, stash, pull request, or branch-protection data.
- Use stable file identifiers or stable paths for selection preservation.
- Use fixed row heights and virtualized rendering for long changed-file lists.
- Preserve scroll position across refreshes when the list contents still correspond to the same repository view.
- Treat stale asynchronous results as expected, not exceptional.

## Edge Cases

- The selected file is deleted, renamed, or no longer changed during refresh.
- The selected file changes again while its diff is loading.
- The user switches files faster than Git can produce diffs.
- A previously selected file still exists but has a new status or old path.
- An untracked file is too large or cannot be decoded as text.
- A file is binary, an image, a submodule, or otherwise not renderable as a normal text patch.
- A repository has no changed files after refresh.
- A status refresh completes after the user has switched repositories.

## Relevant Tests

- Status parsing tests clarify how changed-file states are derived from Git status output.
- Diff parsing tests clarify how text, binary, renamed, deleted, and untracked-file diffs are represented.
- Selection and stale-result tests should verify that an older diff cannot replace a newer selection.
- UI tests should verify that fast diff switches do not show unnecessary loading flicker.

## Notes

This behavior is a perceived-performance strategy. The app still waits for Git when a diff is required, but it avoids making the whole repository view wait for work that is not needed for the user's immediate next action.
