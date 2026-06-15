# Squashing and Reordering Commits

## Purpose

Rewrite recent commit history by combining or reordering commits.

## User Actions

- Select multiple contiguous commits in history.
- Choose squash or drag commits to reorder.
- Edit the resulting commit message.

## Business Logic

- A warning is shown if the rewritten commits have already been pushed.
- Squash combines selected commits onto a target commit with a new message.
- Reorder moves commits before a target commit.
- The generated interactive rebase todo preserves log order to reduce conflicts.
- The first squashed commit is kept as `pick`; the rest become `squash`.
- Root-commit squash uses `--root`.
- Conflicts enter the shared conflict resolution flow.
- Success offers an undo option.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Squash/reorder commits | Interactive rebase | `git -c sequence.editor='cat <todoFile>' rebase -i [--no-verify] <last-retained-commit>` |
| Undo rewrite | Hard reset | `git reset --hard <undo-sha>` |
| Root squash | Rebase from root | `git rebase -i --root` |

## Edge Cases

- Squash target is inside the selected range (blocked).
- No commits provided.
- Base commit not found in log.
- Conflicts during rewrite.
- Rewriting pushed commits.
- Non-sequential/reordered squashes.

## Relevant Tests

- Test area: squash and reorder
- Behavior verified: combine multiple commits; support squashing up to root; merge messages when no custom message.
- Edge case covered: non-sequential commits and conflicting squashes.

## Notes

Conceptual equivalent: Desktop generates the todo file and overrides the sequence editor rather than opening an editor.
