# Application Settings

## Purpose

Configure application-wide behavior and integrations.

## User Actions

- Sign in/out of GitHub.com and GitHub Enterprise accounts.
- Choose theme (light/dark/system).
- Set tab size and accessibility options.
- Configure notifications.
- Opt in/out of usage data.
- Install the command-line tool.
- Check for updates.

## Business Logic

- Signed-in accounts enable GitHub-specific features (PRs, co-authors, rules, Copilot).
- The command-line tool installs a `github` shim on macOS.
- Updates check for new releases and can download and restart.

## Git Operations

| User Action | Git Operation | Conceptual Git CLI |
|---|---|---|
| Install CLI shim | Install launcher | N/A |
| Sign in | OAuth/API | N/A |

## Edge Cases

- No network for sign-in/update.
- Multiple accounts.
- Invalid enterprise URL.

## Relevant Tests

- Test area: preferences and onboarding
- Behavior verified: preferences save/cancel; theme switching.
- Edge case covered: confirmation toggles.

## Notes

Most application settings do not involve Git commands directly.
