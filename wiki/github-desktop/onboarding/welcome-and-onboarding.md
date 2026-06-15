# Welcome and Onboarding

## Purpose

Guide new users through initial setup when no repositories exist.

## User Actions

- Sign in to GitHub.
- Configure Git identity.
- Opt in/out of usage data.
- Create, clone, or add a first repository.
- Complete an optional tutorial repository.

## Business Logic

- The welcome screen is shown when the repository list is empty.
- The tutorial repository creates a guided local project.
- Identity configured during onboarding is written to global Git config.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Configure identity | Global config | `git config --global user.name <name>`, `git config --global user.email <email>` |
| Create tutorial repo | Init + commits | `git init`, `git add`, `git commit` |

## Edge Cases

- No network for sign-in.
- Git not installed.
- User skips onboarding.

## Relevant Tests

- Test area: welcome flow
- Behavior verified: onboarding screen appears for empty list.
- Edge case covered: tutorial repository creation.
