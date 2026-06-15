# Tags

## Purpose

Create, delete, and push annotated tags.

## User Actions

- Create a tag on HEAD or a specific commit.
- Delete a local tag.
- Push tags.

## Business Logic

- Tags are annotated with an empty message.
- Annotated tag output is normalized so the underlying commit SHA is stored.
- Unpushed tags are listed and can be pushed.
- Tags on unpushed local commits are not suggested for push.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Create tag | Annotated tag | `git tag -a -m '' <name> <target-sha>` |
| Delete tag | Delete tag | `git tag -d <name>` |
| List tags | Show refs | `git show-ref --tags -d` |
| Find unpushed tags | Dry-run push | `git push <remote> <branch> --follow-tags --dry-run --no-verify --porcelain` |
| Push tags | Push tags | `git push <remote> --tags` |

## Edge Cases

- Tag already exists.
- Tag target commit not pushed.
- Annotated tag resolves to underlying commit.
- Deleting a tag that does not exist.

## Relevant Tests

- Test area: tags
- Behavior verified: create/delete/list tags; identify unpushed tags.
- Edge case covered: commas in tag names; tags on unpushed commits.
