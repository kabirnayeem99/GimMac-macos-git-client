# Plan: Full Git Workflow Integration Test

**Status:** Planned, not yet implemented.

**Original ask:** "Do a integration test for full git process, clone, save, modified files, git move,
git move, git push, git squash 2-3 commits, git tag, delete files. all" — one continuous flow, not
separate per-operation tests.

**Target file:** `Tests/GimMacIntegrationTests/GitFullWorkflowIntegrationTests.swift` (new file, added to
the existing `GimMacIntegrationTests` target already declared in `project.yml` — no `xcodegen generate`
needed for a new file in an existing target directory).

---

## Design principles

- Exercise the app's own service layer (`GitRepositoryCloneService`, `GitCommitProvider`,
  `GitRemoteSyncService`, `GitSquashProvider`, `GitTagProvider`) for every mutating step — not raw shell
  git — so the test actually verifies the code the app ships. Raw `git` via `Process` is used only for
  setup (`init --bare`) and for verification/assertions, matching the convention already established in
  `GitHistoryEditIntegrationTests.swift` and `RepositorySnapshotIntegrationTests.swift`.
- One test method, one continuous repository and remote — this is an end-to-end workflow test, not a
  unit-per-operation suite. Assertions happen inline after each step so a failure localizes to the exact
  step, not just a final blob of assertions.
- No network. The "remote" is a second temporary directory initialized with `git init --bare`. Git
  clones/pushes/fetches against a local filesystem path exactly like a URL — no stub/mock required.
- Helper functions (`makeTemporaryDirectory`, `runGit`, `runGitCapturing`, `commitCount`, etc.) are
  duplicated into this file rather than extracted to a shared support file — that is the existing
  convention across every file in `Tests/GimMacIntegrationTests/` (confirmed: no shared `TestSupport.swift`
  exists today). Not proposing to change that as part of this task.

---

## Resolved open questions (defaults chosen — flag if you want different behavior)

1. **Force-push after squash:** included. Squash rewrites commits already pushed in the initial push
   step; a plain `push` would be rejected (non-fast-forward) by the bare remote, which would make the
   test either fail or silently skip verifying the post-squash remote state. Using
   `GitRemoteSyncService.pushForceSafely(remote:in:)` (`--force-with-lease`) after squash keeps the test
   demonstrating a realistic, working end-to-end flow.
2. **Tag push:** **not** included. No dedicated service method exists for pushing a single tag
   (`GitRemoteSyncService` only has `fetch`/`pull`/`push`/`pushForceSafely`/`publishBranch`). Tag creation
   stays local-only, matching the literal ask ("git tag", not "git push tag"). A raw
   `client.run(["push", "origin", "v1.0.0"])` could be added later if remote-tag verification becomes
   wanted.
3. **Final push after delete:** included, using plain `push` (fast-forward, no force needed since the
   delete commit sits cleanly on top of what the force-push already synced). This is what proves the
   *entire* chain round-trips to the remote, not just the middle of it.

---

## Step-by-step

| # | Step | Service call | What it does under the hood |
|---|---|---|---|
| 0 | Bare remote + identity | raw `git init --bare`; raw `git config user.name/user.email/commit.gpgsign` on the clone | Sets up the stand-in remote and repo-local identity (`GitCommitProvider.commit()` does not inject `-c user.name=...`, so identity must already be configured or the commit step fails) |
| 1 | Clone | `GitRepositoryCloneService.clone(from: originURL.path, to: workDir)` | Runs `git clone --recursive --progress -- <path> <dest>` from `workDir`'s parent. `workDir` must not exist yet — clone creates it. Cloning an empty bare repo yields unborn HEAD, same as cloning a brand-new empty GitHub repo. |
| 2 | Save | write `notes.txt` → `GitCommitProvider.commit(paths: ["notes.txt"], summary: "Add notes", ...)` | First real commit; creates the default branch (e.g. `main`) from unborn HEAD |
| 3 | Modify | overwrite `notes.txt` → commit "Update notes" | Second commit on the same file |
| 4 | Move #1 | `client.run(["mv", "--", "notes.txt", "journal.txt"])` → commit "Rename notes.txt to journal.txt" | `git mv` stages the rename in the index immediately; the follow-up `commitProvider.commit(paths:)` call runs its internal `add -A -- <path>` on both old and new paths (no-ops since already staged) — same call path the real UI uses for a rename |
| 5 | Move #2 | `client.run(["mv", "--", "journal.txt", "diary.txt"])` → commit "Rename journal.txt to diary.txt" | Same as above, second rename |
| 6 | Push | `GitRemoteSyncService.publishBranch(named: branch, remote: "origin", in: workDir)` | First push needs `-u`/upstream since none is set after a clone of an empty repo — `publishBranch` runs `push --set-upstream origin <branch>`, not plain `push` |
| 7 | Squash | fetch last 3 commit SHAs (`log --format=%H -n 3`, newest-first) → wrap as `Commit` structs → `GitSquashProvider.squash(commits:, message:, in:)` | Runs a *real* `git rebase -i` against a controlled `GIT_SEQUENCE_EDITOR`/`GIT_EDITOR` script pair — squashes "Update notes" + both renames into one commit, keeping "Add notes" as the untouched base |
| 8 | Re-sync remote | `GitRemoteSyncService.pushForceSafely(remote: "origin", in: workDir)` | `push --force-with-lease origin` — required because step 6 already pushed the now-rewritten commits |
| 9 | Tag | `GitTagProvider.createTag(named: "v1.0.0", message: "Release 1.0.0", at: headCommit, in: workDir)` | `git tag -a -m "Release 1.0.0" -- v1.0.0 <sha>` (annotated tag) at the post-squash HEAD |
| 10 | Delete | `FileManager.removeItem(diary.txt)` → `GitCommitProvider.commit(paths: ["diary.txt"], summary: "Delete diary.txt", ...)` | Internal `add -A -- diary.txt` correctly stages a deletion |
| 11 | Final push | `GitRemoteSyncService.push(remote: "origin", in: workDir)` | Plain fast-forward push; proves the whole chain (clone → save → modify → 2 renames → push → squash → force-push → tag → delete → push) round-trips cleanly to the remote |

---

## Implementation sketch

```swift
import XCTest
@testable import GimMac

final class GitFullWorkflowIntegrationTests: XCTestCase {
    func testFullGitWorkflow_cloneModifyRenamePushSquashTagDelete() async throws {
        let parent = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }

        let originURL = parent.appendingPathComponent("origin.git", isDirectory: true)
        let workDir = parent.appendingPathComponent("work", isDirectory: true)
        try runGit(["init", "--bare", originURL.path], in: parent)

        let client = ProcessGitClient()
        let cloneService = GitRepositoryCloneService(client: client)
        let commitProvider = GitCommitProvider(client: client, logger: GimMacLogger())
        let syncService = GitRemoteSyncService(client: client)
        let squashProvider = GitSquashProvider(client: client)
        let tagProvider = GitTagProvider(client: client)

        // Step 1 — clone
        try await cloneService.clone(from: originURL.path, to: workDir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDir.appendingPathComponent(".git").path))

        // Step 0b — identity (must happen after workDir exists)
        try runGit(["config", "user.name", "Integration Test"], in: workDir)
        try runGit(["config", "user.email", "integration@test.local"], in: workDir)
        try runGit(["config", "commit.gpgsign", "false"], in: workDir)

        // Step 2 — save
        let notesURL = workDir.appendingPathComponent("notes.txt")
        try "hello\n".write(to: notesURL, atomically: true, encoding: .utf8)
        try await commitProvider.commit(
            in: workDir, paths: ["notes.txt"], summary: "Add notes",
            description: nil, options: CommitOptions()
        )
        XCTAssertEqual(try commitCount(in: workDir), 1)

        // Step 3 — modify
        try "hello world\n".write(to: notesURL, atomically: true, encoding: .utf8)
        try await commitProvider.commit(
            in: workDir, paths: ["notes.txt"], summary: "Update notes",
            description: nil, options: CommitOptions()
        )
        XCTAssertEqual(try commitCount(in: workDir), 2)

        // Step 4 — move #1
        _ = try await client.run(["mv", "--", "notes.txt", "journal.txt"], in: workDir, timeout: 15)
        try await commitProvider.commit(
            in: workDir, paths: ["notes.txt", "journal.txt"], summary: "Rename notes.txt to journal.txt",
            description: nil, options: CommitOptions()
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: notesURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workDir.appendingPathComponent("journal.txt").path))

        // Step 5 — move #2
        _ = try await client.run(["mv", "--", "journal.txt", "diary.txt"], in: workDir, timeout: 15)
        try await commitProvider.commit(
            in: workDir, paths: ["journal.txt", "diary.txt"], summary: "Rename journal.txt to diary.txt",
            description: nil, options: CommitOptions()
        )
        let diaryURL = workDir.appendingPathComponent("diary.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: diaryURL.path))
        XCTAssertEqual(try commitCount(in: workDir), 4)

        // Step 6 — push
        let branch = try runGitCapturing(["rev-parse", "--abbrev-ref", "HEAD"], in: workDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try await syncService.publishBranch(named: branch, remote: "origin", in: workDir)
        let localHead = try headSHA(in: workDir)
        let remoteHead = try runGitCapturing(["rev-parse", branch], in: originURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(localHead, remoteHead)

        // Step 7 — squash last 3 commits (Update notes + both renames), keep "Add notes" as base
        let shaLog = try runGitCapturing(["log", "--format=%H", "-n", "3"], in: workDir)
        let shas = shaLog.split(separator: "\n").map(String.init)
        let commitsToSquash = shas.map { sha in
            Commit(id: sha, shortHash: String(sha.prefix(7)), authorName: "x", authorEmail: "x@x",
                   date: Date(timeIntervalSince1970: 0), summary: "x", body: nil)
        }
        try await squashProvider.squash(commits: commitsToSquash, message: "Squash update+renames", in: workDir)
        XCTAssertEqual(try commitCount(in: workDir), 2)
        // squashed-away commits are no longer reachable from HEAD
        for sha in shas.dropLast() {
            let result = try? await client.run(["merge-base", "--is-ancestor", sha, "HEAD"], in: workDir, timeout: 10)
            XCTAssertNotEqual(result?.exitCode, 0)
        }

        // Step 8 — re-sync remote (history was rewritten under an already-pushed branch)
        try await syncService.pushForceSafely(remote: "origin", in: workDir)
        let remoteHeadAfterSquash = try runGitCapturing(["rev-parse", branch], in: originURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let localHeadAfterSquash = try headSHA(in: workDir)
        XCTAssertEqual(remoteHeadAfterSquash, localHeadAfterSquash)

        // Step 9 — tag
        let headCommit = Commit(id: localHeadAfterSquash, shortHash: String(localHeadAfterSquash.prefix(7)),
                                 authorName: "x", authorEmail: "x@x", date: Date(timeIntervalSince1970: 0),
                                 summary: "x", body: nil)
        try await tagProvider.createTag(named: "v1.0.0", message: "Release 1.0.0", at: headCommit, in: workDir)
        let taggedSHA = try runGitCapturing(["rev-list", "-n", "1", "v1.0.0"], in: workDir)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(taggedSHA, localHeadAfterSquash)

        // Step 10 — delete
        try FileManager.default.removeItem(at: diaryURL)
        try await commitProvider.commit(
            in: workDir, paths: ["diary.txt"], summary: "Delete diary.txt",
            description: nil, options: CommitOptions()
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: diaryURL.path))
        let status = try await client.run(["status", "--porcelain"], in: workDir, timeout: 10)
        XCTAssertEqual(status.stdout, "")
        XCTAssertEqual(try commitCount(in: workDir), 3)

        // Step 11 — final push, full round-trip check
        try await syncService.push(remote: "origin", in: workDir)
        let localLog = try runGitCapturing(["log", "--format=%H"], in: workDir)
        let remoteLog = try runGitCapturing(["log", "--format=%H", branch], in: originURL)
        XCTAssertEqual(localLog, remoteLog)
        // tag was never pushed (by design) — confirm it does not exist on the remote
        let remoteTagCheck = try? await client.run(["tag", "--list", "v1.0.0"], in: originURL, timeout: 10)
        XCTAssertEqual(remoteTagCheck?.stdout.trimmingCharacters(in: .whitespacesAndNewlines), "")
    }

    // MARK: - Helpers (duplicated per existing repo convention, see other files in this target)

    private func makeTemporaryDirectory() throws -> URL { /* same as other integration test files */ }
    private func runGit(_ args: [String], in directory: URL) throws { /* same */ }
    private func runGitCapturing(_ args: [String], in directory: URL) throws -> String { /* same */ }
    private func commitCount(in root: URL) throws -> Int { /* same, git rev-list --count HEAD */ }
    private func headSHA(in root: URL) throws -> String {
        try runGitCapturing(["rev-parse", "HEAD"], in: root).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

---

## Acceptance criteria

- New file `Tests/GimMacIntegrationTests/GitFullWorkflowIntegrationTests.swift` added, one test method
  covering the full sequence in order: clone → save → modify → move → move → push → squash → force-push →
  tag → delete → push.
- Every mutating git operation goes through the app's own service classes
  (`GitRepositoryCloneService`, `GitCommitProvider`, `GitRemoteSyncService`, `GitSquashProvider`,
  `GitTagProvider`), not hand-rolled shell calls — raw `Process`/`git` calls are used only for the bare
  remote setup, identity config, and read-only verification.
- Assertions after each step, not just at the end — a broken step fails at that step, not three steps
  later with a confusing symptom.
- No network access; a local bare repo stands in for the remote.
- Test passes under:
  `xcodebuild test -project GimMac.xcodeproj -scheme GimMac -destination 'platform=macOS,arch=arm64' -only-testing:GimMacIntegrationTests/GitFullWorkflowIntegrationTests`

## Suggested verification

- Run the single new test target above in isolation first.
- Run the full `GimMacIntegrationTests` target to confirm no interference with existing tests
  (temp-directory isolation should make this safe — each test creates its own UUID-named directory).
- `swiftlint lint --strict --config .swiftlint.yml` on the new file before considering it done.

## Known corpus correction found while researching this plan

`GitTagProvider.swift:14-15` was flagged in `docs/queue/full-codebase-review-2026-07-05.md` as missing a
`--` separator before the tag name. Re-checked directly against current source — both branches already
have `--` (`["tag", "--", name, commit.id]` / `["tag", "-a", "-m", trimmedMessage, "--", name, commit.id]`).
That finding was stale/incorrect and should be removed from the review doc; not fixed here since it's out
of scope for this test-planning task.
