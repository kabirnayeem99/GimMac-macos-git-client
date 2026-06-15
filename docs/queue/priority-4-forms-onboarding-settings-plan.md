# Priority 4 — Forms, Onboarding, Settings: Implementation Plan

Detailed plan for Priority 4 of [presentation-micro-interactions.md](presentation-micro-interactions.md)
(Onboarding, Create/Clone Repository, Settings, Repository Settings, Sheets and Destructive Actions),
plus Implementation Order step 8 — profile large repositories and diffs before expanding motion.

Priorities 1–3 are complete. Reuse the existing shared motion layer; do not rebuild it.

## Existing Shared Motion Layer (reuse)

SwiftUI policy: `Sources/GimMac/Presentation/Shared/Motion.swift`
AppKit policy: `Sources/GimMac/Presentation/Shared/AppKitMotion.swift`

Relevant for Priority 4:

| Helper | Location | Use in Priority 4 |
|---|---|---|
| `Motion.feedback` / `.snappy` / `.spatial` | Motion.swift:10–13 | SwiftUI step/validation motion |
| `Motion.resolve(_:reduceMotion:)` | Motion.swift:15 | gate onboarding step animation |
| `Motion.inlineStatus(reduceMotion:)` | Motion.swift:19 | validation/status insert-remove |
| `View.motion(_:reduceMotion:value:)` | Motion.swift:29 | progress / count interpolation |
| `View.symbolReplacement(reduceMotion:)` | Motion.swift:34 | completion checkmark |
| `OpOutcome` enum | Motion.swift:4 | save/create/clone outcome |
| `AppKitMotion.reduceMotion` | AppKitMotion.swift:13 | AppKit reduce-motion gate |
| `NSView.animateAlpha(to:duration:)` | AppKitMotion.swift:23 | Settings banner fade |
| `NSView.crossfade(out:in:duration:)` | AppKitMotion.swift:38 | Settings/RepoSettings pane + label swap |
| `NSImageView.setSymbolImage(_:contentTransition:)` | AppKitMotion.swift:137 | terminal/editor confirm symbol |

## Phase 0 — Shared Helper Gap-Fill (do first)

Add only these; each has two or more Priority-4 callers, so the extraction criterion is met. No larger
framework.

1. **AppKit banner fade helper** — `func fadeBanner(_ label: NSTextField, visible: Bool)` (reduce-motion
   aware, opacity-only, sets `isHidden` after fade-out). Callers: Settings Git banner, Repository
   Settings banner. Add to `AppKitMotion.swift`. Wraps `animateAlpha`; consolidates the repeated
   `isHidden` toggle pattern.
2. **AppKit auto-dismiss timer for banners** — small cancellable timer that fades a banner out after a
   dwell (≈3 s). Callers: Settings Git banner, Repository Settings remote/branch/LFS banners. Add
   alongside the banner helper. Must be cancellable so a new message replaces the old predictably.

Everything else reuses `crossfade`, `animateAlpha`, `setSymbolImage`, and the SwiftUI `Motion` helpers.

## Phase 1 — Onboarding

Files: `Presentation/Onboarding/OnboardingView.swift`, `Presentation/Onboarding/OnboardingViewModel.swift`.
Hosted in `NSHostingView` by `OnboardingWindowController`; completion via `onComplete` callback.

- **Route existing step animation through the shared layer (fix).** OnboardingView.swift:16 currently
  uses a hardcoded `.animation(.easeInOut(duration: 0.18), value: viewModel.step)` that ignores
  reduce-motion and the `Motion` helpers. Replace with `Motion`-based animation gated by
  `@Environment(\.accessibilityReduceMotion)`.
- **Directional step continuity** — step is an enum (`welcome` / `configureGit`,
  OnboardingViewModel.swift:12; `advance()`/`goBack()` at :33–34). Add an asymmetric slide+fade keyed on
  direction (forward vs back), reduce-motion → opacity only.
- **Progress interpolation** — no progress indicator today. Add a 2-step progress indicator and
  interpolate with `.motion(Motion.snappy, value: step)`.
- **Inline validation/status** — error text at OnboardingView.swift:91–97 appears with no transition;
  `isSaving` (OnboardingViewModel.swift:15, 42–54) has no UI feedback. Add
  `.transition(Motion.inlineStatus)` to the error and a stable-size progress indicator while saving.
- **Completion checkmark before close** — `onComplete` fires immediately on save success
  (OnboardingViewModel.swift:50). Show a brief checkmark before invoking the callback; reduce-motion →
  shorter/!instant.

## Phase 2 — Create and Clone Repository

Files: `Presentation/Repository/CreateRepositorySheet.swift` (SwiftUI),
`Presentation/Repository/CreateRepositoryWindowController.swift` (AppKit host),
`Presentation/Repository/CloneRepositoryWindowController.swift` (AppKit).

CreateRepositorySheet (SwiftUI):
- **Inline validation + button enable** — `canCreate` (CreateRepositorySheet.swift:40–42) only disables
  the button; no field-level feedback. Add `.motion(Motion.feedback, value: canCreate)` to the button
  and an inline validation message with `.transition(Motion.inlineStatus)`.
- **Destination-path confirmation crossfade** — label color flips instantly when `parentDirectory` sets
  (CreateRepositorySheet.swift:123–125). Crossfade the placeholder→path text.
- **Stable progress** — `ProgressView` at :102–105 already stable-size; keep, do not resize the sheet.
- **Success before dismiss** — `create()` (:142–155) dismisses immediately via the AppKit host. Add a
  brief success checkmark before `onCreate` triggers dismissal.
- **First invalid field focus** — none today; add subtle focus emphasis on the first empty field.

CloneRepositoryWindowController (AppKit):
- **Validation + button enable** — `updateCloneEnabled()` (CloneRepositoryWindowController.swift:153–157)
  toggles `isEnabled` instantly; fade via `animateAlpha`.
- **Destination confirmation** — `destinationField` updates directly (:118). Optional brief crossfade.
- **Success before dismiss** — `performClone()` dismisses immediately (:134). Add brief confirmation,
  keep the fixed 460×200 frame (no resize).

## Phase 3 — Settings

Directory: `Presentation/Settings/` (pure AppKit, NSSplitViewController + NSTableView sidebar; panes are
NSViewController subclasses of `SettingsPaneViewController`). No SwiftUI, no existing animation.

- **Pane crossfade** — `show(_:)` in SettingsRootViewController (SettingsWindowController.swift:99–120)
  hard-removes the old pane and adds the new one. Use `AppKitMotion.crossfade(out:in:)` between panes;
  preserve the NSLayoutConstraint setup. Do not animate the native sidebar selection (AppKit already
  animates source-list row highlight).
- **Git save/error banner** — GitSettingsPaneController toggles `bannerLabel.isHidden` (setup ~:75–90,
  sync ~:121–145). Replace with the Phase 0 `fadeBanner` helper + auto-dismiss timer.
- **Git validation hint** — red `validationLabel` toggles `isHidden` (~:41–51, :138–145). Fade via
  `fadeBanner` / `animateAlpha`.
- **Notifications conditional section** — `refreshHint()` toggles hint + grant/open-settings buttons by
  permission state (NotificationsSettingsPaneController ~:76–115). Fade the group; crossfade between
  grant and open-settings buttons.
- **Integrations custom form** — `rebuildContent()` tears down and rebuilds the whole pane
  (IntegrationsSettingsPaneController ~:19–104). Wrap the rebuild in a pane fade-out → rebuild →
  fade-in (simpler path), not per-view layout animation.
- **Appearance theme** — applied immediately (AppearanceSettingsViewModel.swift:12–16). Leave instant
  per platform convention; do not animate the window.
- Do not animate individual checkboxes, popups, or other native controls (doc line 259).

## Phase 4 — Repository Settings

Files: `Presentation/RepositorySettings/RepositorySettingsWindowController.swift` (AppKit,
NSWindowController + NSViewController with NSTabView), `RepositorySettingsViewModel.swift` (`@Observable`).
State synced via a `withObservationTracking` loop. No existing animation.

- **Loading → content crossfade** — Remote loading label (~:176–180, toggled by `isLoadingRemote` at
  :126) and LFS status label (~:257–260, text swapped at :132–135) change text directly. Crossfade
  loading text into loaded content via `AppKitMotion.crossfade`.
- **Banner fade + predictable removal** — `bannerLabel` toggles `isHidden` (setup :74–81, sync :138–148).
  Use the Phase 0 `fadeBanner` + auto-dismiss; messages are already cleared explicitly before each
  action (:309–323).
- **Completion feedback** — remote save (VM :66–79), branch rename (VM :83–96), LFS init (VM :106–117)
  each set `successMessage` + toggle a saving flag. Add a brief success symbol/pulse on the acted button
  in addition to the banner.
- **Tab content** — NSTabView already cross-fades natively; do not add a conflicting custom transition
  (doc line 273). Only ensure banner/overlay animations respect Z-order.
- **Open-in-terminal/editor** — fire-and-forget (VM :121–142). Keep immediate; add only a brief symbol
  confirmation via `setSymbolImage` (doc line 274).

## Phase 5 — Sheets and Destructive Actions

Cross-cutting (branch dialogs; reset / reorder / squash sheets; stash-and-switch; create/clone sheets).

- Animate inline validation and expandable advanced options (reuse `Motion.inlineStatus`).
- Use restrained warning emphasis when a destructive choice changes; never animate in a way that
  obscures the default or cancel action (doc line 290).
- Keep native macOS sheet presentation and dismissal unchanged.

## Implementation Order Step 8 — Profile Large Repositories and Diffs

Gate further motion expansion on profiling. Run after Priorities 3 and 4 land, before adding any motion
beyond this plan.

Targets to profile (highest risk for jank):
- Large repository status → changed-files list updates (`Presentation/Changes/Sidebar.swift` list
  animation already added in Priority 2).
- Large diffs and the diff state crossfade / image decode (Priority 3, `Presentation/Diff/`).
- Branch and history list row animations on large histories (Priority 2).
- Settings pane crossfade and Repository Settings banner timers under rapid switching.

Method:
1. Build the strict gate first: `./scripts/strict-ci.sh` (warnings-as-errors, complete concurrency).
2. Profile with Instruments — Time Profiler and Animation Hitches / Core Animation FPS — against a
   large real repository (thousands of changed files, multi-thousand-line diffs, deep history).
3. Capture before/after evidence per acceptance criteria: frequent actions not delayed; large lists and
   diffs stay responsive; no animation depends on Git or parsing on the main thread.
4. Confirm the image-diff decode (Priority 3) and any list-diffing run off the main thread; verify the
   `NSTableView.animatedReload` large-diff fallback engages and that SwiftUI list animations key on
   stable identity, not full rebuilds.
5. Record findings in this queue. Expand motion only where profiling shows headroom; otherwise prefer
   opacity-only or immediate transitions.

Per AGENTS.md: use Instruments or reproducible evidence before adding performance complexity. Do not add
motion that forces attributed-string rebuilds or scroll-position loss in diffs (doc line 175).

## Build Order and Verification

Order: Phase 0 → 1 → 2 → 3 → 4 → 5, then Step 8 profiling. Run `./scripts/strict-ci.sh` after each
phase.

Manual check each phase: toggle System Settings → Accessibility → Reduce Motion and confirm the
opacity-only or immediate fallback. Confirm keyboard focus, VoiceOver labels, native tab/sheet behavior,
and field focus remain correct.

## Acceptance Criteria

Inherits presentation-micro-interactions.md:316 — motion communicates a state change or action; Reduce
Motion respected; keyboard focus, VoiceOver, selection, and scroll position correct; frequent actions
not delayed; large lists and diffs responsive; no animation depends on Git or parsing on the main
thread; native tab and sheet presentation preserved; Senior Engineer review finds no blocker/major
accessibility, concurrency, or performance issue.
