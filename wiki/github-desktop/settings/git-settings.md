# Git Settings

## Purpose

Configure user identity and default Git behavior.

## User Actions

- Set global and per-repository Git user name and email.
- Set the default branch name for new repositories.
- Choose the external editor and shell.
- Configure custom integrations.
- Toggle confirmation dialogs.

## Business Logic

- If global Git config is missing, the app falls back to the signed-in account's login/email.
- Repository Git config can override global config.
- Confirmation dialogs are enabled by default for destructive actions.
- A Git config lock file blocks saving and surfaces a warning.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Set user name/email | Config | `git config --global user.name <name>`, `git config --global user.email <email>` |
| Set repo user name/email | Local config | `git config --local user.name <name>`, `git config --local user.email <email>` |
| Set default branch | Config | `git config init.defaultBranch <name>` |
| Add safe directory | Safe directory | `git config --global --add safe.directory <path>` |

## Edge Cases

- Missing global config.
- Config lock file present.
- Invalid editor/shell path.
- Custom integration executable not found.

## Relevant Tests

- Test area: config
- Behavior verified: local/global config read/write; boolean parsing.
- Edge case covered: `GIT_CONFIG_PARAMETERS` precedence; config lock.
