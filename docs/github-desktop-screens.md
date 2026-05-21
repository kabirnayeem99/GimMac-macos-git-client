Here is a practical inventory of **GitHub Desktop (2026)**: major screens, features, and the approximate underlying Git operations they map to. GitHub Desktop is essentially a GUI over Git + some GitHub APIs. ([GitHub][1])

## 1. Welcome / Onboarding

**Functions**

* Sign into GitHub
* Configure Git identity
* Clone repository
* Create repository
* Add existing local repository

**Underlying Git**

* Login → GitHub OAuth/API (not Git)
* Configure name/email → `git config --global user.name`, `git config --global user.email`
* Clone → `git clone`
* Create local repo → `git init`
* Add existing repo → repo detection (`.git` folder)

---

## 2. Repository Selector (Current Repository dropdown)

**Functions**

* Switch repository
* Add/remove repositories
* Filter/search repos
* Open recent repos

**Underlying Git**

* Mostly UI/state only
* Reads repo metadata:

  * `git remote -v`
  * `git branch`
  * `git status`

---

## 3. Changes Screen (Main working area)

This is the screen most people use.

### Left panel: changed files

**Functions**

* View modified files
* Stage/unstage selected files
* Stage specific hunks/lines
* Ignore files
* Discard changes

**Underlying Git**

* File status → `git status`
* Stage file → `git add <file>`
* Stage hunk → `git add -p` equivalent
* Unstage → `git reset HEAD <file>` / `git restore --staged`
* Discard unstaged changes → `git checkout -- <file>` or `git restore`
* Ignore → update `.gitignore`

### Right panel: diff viewer

**Functions**

* Unified diff
* Split diff
* Syntax highlighting
* Line-level review

**Underlying Git**

* `git diff`
* `git diff --staged`

### Bottom commit box

**Functions**

* Commit message
* Commit description
* Commit selected files only
* Co-author commit
* Amend previous commit

**Underlying Git**

* Commit → `git commit`
* Commit staged subset → `git commit`
* Amend → `git commit --amend`
* Co-author → commit trailer metadata

---

## 4. History Screen

Timeline of commits.

**Functions**

* View commit history
* Inspect diffs
* Compare commits
* Search commits
* View author/time

**Underlying Git**

* `git log`
* `git show <commit>`
* `git diff SHA1 SHA2`

### Right-click commit actions

**Functions**

* Revert commit
* Cherry-pick commit
* Create branch from commit
* Reset to commit
* Tag commit
* Open on GitHub

**Underlying Git**

* Revert → `git revert`
* Cherry-pick → `git cherry-pick`
* Branch from commit → `git checkout -b`
* Reset → `git reset --soft|mixed|hard`
* Tag → `git tag`
* View on GitHub → browser/API

---

## 5. Branches Screen / Branch Menu

**Functions**

* Create branch
* Switch branch
* Delete branch
* Rename branch
* Compare branches
* Update from default branch

**Underlying Git**

* Create → `git branch` / `git switch -c`
* Checkout → `git checkout` / `git switch`
* Delete → `git branch -d`
* Rename → `git branch -m`
* Compare → `git diff branchA..branchB`
* Update branch → `git merge` or rebase flow

---

## 6. Pull Request Screen

GitHub-specific feature.

**Functions**

* Create PR
* Select base branch
* Add title/body
* Open PR in browser
* View CI status

**Underlying Git**

* Push branch → `git push -u origin branch`
* PR creation → GitHub API (not Git)
* CI status → GitHub API

---

## 7. Fetch / Pull / Push Bar (Top toolbar)

### Fetch origin

**Function**

* Check remote changes

**Underlying Git**

* `git fetch origin`

### Pull origin

**Function**

* Bring remote changes locally

**Underlying Git**

* `git pull`
* sometimes merge/rebase strategy underneath

### Push origin

**Function**

* Upload commits

**Underlying Git**

* `git push`

### Force push (advanced)

**Underlying Git**

* `git push --force-with-lease`

---

## 8. Merge Conflict Resolution Screen

**Functions**

* Detect conflicts
* Open editor
* Mark resolved
* Continue merge

**Underlying Git**

* `git merge`
* conflict markers
* `git add`
* `git commit`

---

## 9. Stash Screen

**Functions**

* Stash local work
* Restore stash
* Auto stash during branch switch

**Underlying Git**

* `git stash`
* `git stash pop`
* `git stash apply`

---

## 10. Clone Repository Dialog

**Sources**

* GitHub account repos
* URL
* Enterprise GitHub
* Local path

**Underlying Git**

* `git clone <url>`

---

## 11. Create Repository Screen

**Functions**

* New local repo
* README
* Git ignore template
* License
* Publish to GitHub

**Underlying Git**

* `git init`
* initial commit
* `git remote add origin`
* `git push -u origin main`

---

## 12. Publish Repository Screen

**Functions**

* Make repo public/private
* Push local repo to GitHub

**Underlying Git**

* `git remote add origin`
* `git push -u origin`

GitHub API:

* create remote repository

---

## 13. Repository Settings

**Functions**

* Remote URL
* Default branch
* Git LFS support
* Open in terminal/editor

**Underlying Git**

* `git remote set-url`
* `git branch -M`
* `git lfs`
* shell open

---

## 14. External Editor Integration

**Functions**

* Open in VS Code/Xcode/etc.
* Open terminal

**Underlying**

* OS shell execution only

---

## 15. Compare / Review Changes Before Merge

**Functions**

* Compare branch changes
* Preview incoming commits

**Underlying Git**

* `git diff`
* `git log`
* `git merge-base`

---

## 16. Advanced History Editing (recent versions)

**Functions**

* Reorder commits
* Squash commits
* Drop commits
* Cherry-pick by drag-drop

**Underlying Git**

* Interactive rebase:

  * `git rebase -i`
* Squash:

  * `git rebase -i squash`
* Drop:

  * rebase removing commit
* Cherry-pick:

  * `git cherry-pick`

---

## What GitHub Desktop does *not* cover well

You still usually need CLI for:

* Advanced rebases
* Bisect → `git bisect`
* Reflog recovery → `git reflog`
* Complex submodules
* Worktrees → `git worktree`
* Hooks
* Advanced stash ops
* Custom merge strategies
* Signed commits (some cases)
* Low-level plumbing (`rev-parse`, `cat-file`, etc.)

A useful mental model:

**GitHub Desktop = ~80% of daily Git workflow**

* clone
* branch
* commit
* diff
* stash
* pull/push
* PR
* merge
* cherry-pick
* squash

**CLI = edge cases + power user workflows**. ([GitHub][1])

[1]: https://github.com/apps/desktop?utm_source=chatgpt.com "GitHub Desktop | Simple collaboration from your desktop · GitHub"

