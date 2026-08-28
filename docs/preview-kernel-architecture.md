# Preview Kernel Architecture

Date: 2026-06-09
Status: Active reference
Scope: Long-term maintenance

## Purpose

This document records the current preview kernel architecture after the Preview Kernel refactor.

It is meant to be a long-lived maintenance reference:

- plan documents explain how a refactor should be executed
- review documents capture discussion at a point in time
- this document records the architecture we expect future preview changes to preserve

If preview entry flow or ownership changes, update this file together with the code.

## Unified preview flow

All long-term preview entry points should converge into the same core path:

1. trigger creates a `PreviewLaunchRequest`
2. `AppDelegate` forwards the request to `PreviewCoordinator`
3. `PreviewCoordinator` asks `PreviewTargetResolver` to resolve the concrete target
4. `PreviewCoordinator` writes success or failure into `PreviewSession`
5. `QuickLookOverlay` observes `PreviewSessionState` and presents the window shell
6. `ContentView` renders directly from `PreviewSessionState` plus local rendering state

This path is the expected baseline for:

- global hotkey
- Services menu
- URL Scheme
- future direct-path preview entry points

## Layer responsibilities

### Trigger layer

Primary types:

- `PreviewLaunchRequest`
- `PreviewLaunchSource`
- `PreviewLaunchPathIntent`
- `PreviewPresentationIntent`

Responsibilities:

- describe where the preview request came from
- distinguish direct path from Finder-selection intent
- distinguish open from toggle behavior

Non-responsibilities:

- file type classification
- Finder resolution
- window presentation

### Resolution layer

Primary types:

- `PreviewTarget`
- `PreviewTargetResolver`
- `PreviewTargetError`

Responsibilities:

- resolve Finder selection when required
- normalize path and symlink handling
- classify render type
- infer display name and language
- produce structured failures for unsupported or invalid targets

Non-responsibilities:

- preview/edit mode transitions
- overlay animation or focus behavior

### Session layer

Primary types:

- `PreviewSession`
- `PreviewSessionState`
- `PreviewReadiness`
- `PreviewSessionMode`

Responsibilities:

- own the active preview target
- represent preview vs edit mode
- represent loading, ready, and failed readiness
- record runtime family selection

Non-responsibilities:

- resolving Finder state
- creating windows
- owning every local SwiftUI state used by rendering

Rule of thumb:

- business-meaningful preview state belongs here
- purely local rendering state belongs in the view or runtime that uses it

### Runtime layer

Primary types:

- `PreviewRuntime`
- `PreviewRuntimeKind`
- `PreviewRuntimeRegistry`

Responsibilities:

- provide shared runtime terminology
- centralize long-lived runtime reuse
- expose attach, detach, and reset style lifecycle semantics

Current note:

- `WebKitRuntime` is the first concrete participant in this contract
- registry naming is broader than WebKit on purpose, even though not every runtime family has a dedicated implementation yet

### Overlay shell layer

Primary type:

- `QuickLookOverlay`

Responsibilities:

- own preview window creation and visibility
- manage animation, focus, scoped Finder follow, and toast behavior
- observe `PreviewSessionState` and translate it into window-level behavior

Non-responsibilities:

- direct ownership of preview target resolution
- becoming the main place for trigger branching logic
- reintroducing scattered business-state mutations that belong in coordinator or session

Important maintenance rule:

- if a change needs Finder resolution, request classification, or readiness transitions, change coordinator, resolver, or session first
- do not push new orchestration back into `QuickLookOverlay`

### Content layer

Primary type:

- `ContentView`

Responsibilities:

- render preview and edit experiences
- consume session-derived target, render type, language, and mode
- keep heavy-preview gating aligned with session semantics

Ownership rule:

- business-meaningful preview state must come from `PreviewSessionState`
- local `@State` in `ContentView` should only hold rendering concerns such as loading UI, reload prompts, and save alerts
- do not reintroduce a second preview-state mirror or a parallel business error owner in the view layer
- file-type icons must go through `PreviewFileIconAssetRegistry`; do not hardcode SF Symbols or macOS system file icons inside preview content views

## Interaction Model

The default preview interaction model is:

```text
Finder-driven request:
  resolve current Finder selection once
  present QuickCookies as a non-key preview overlay
  keep Finder focused so selection highlight and Up/Down navigation stay native
  keep a scoped Finder-selection watcher while the overlay is visible
  use Finder key and mouse selection events as refresh acceleration

Direct-path request:
  open the concrete path directly
  allow QuickCookies to become key
  use internal Up/Down navigation when appropriate
  avoid Finder-selection polling entirely

All paths:
  do not start unconditional app-wide Finder-selection polling
```

Important consequences:

- Finder-driven sources such as `.hotkey`, `.finderSync`, and `.menuBar` keep Finder focused.
- Finder-driven sources keep a scoped Finder-selection watcher alive only while the overlay is visible.
- Direct-path sources such as `.service`, `.urlScheme`, and `.internalNavigation` may allow the overlay window to become key and do not start Finder-selection polling.
- Closing preview mode is intentionally owned by the global hotkey toggle or explicit window controls, not by adding `Esc` as another primary close shortcut.
- Plain `Up` and `Down` navigate through `PreviewNavigationContext` only when the current source is not Finder-driven.
- Finder-driven `Up`, `Down`, and mouse selection events trigger refresh bursts that accelerate updates; correctness still comes from the scoped watcher while visible.
- Internal navigation uses `.internalNavigation` and a direct path request.
- Internal navigation must not be treated as Finder selection follow-up.
- Editing mode keeps `Up` and `Down` for the editor instead of switching files.

The old model is now historical fallback context:

```text
All entry points are treated like Finder-follow
QuickCookies continuously polls Finder selection changes
Up/Down are posted back to Finder
```

Do not make unconditional polling or key forwarding the default again. Finder-follow behavior may evolve later, but it should stay scoped to Finder-driven sessions instead of becoming the app-wide preview lifecycle.

## Entry-point behavior

### Hotkey

- Source: `.hotkey`
- Path intent: `.finderSelection`
- Presentation: `.toggle`

Expected behavior:

- if overlay is already visible, hotkey closes it first
- otherwise the request resolves current Finder selection and opens a session
- the opened overlay keeps Finder focused so Finder selection highlight remains visible
- Finder-driven preview starts a scoped selection watcher while the overlay is visible
- Finder `Up`, `Down`, and mouse selection changes trigger refresh bursts while the overlay is visible

### Services menu

- Source: `.service`
- Path intent: usually `.direct(path:)`
- Presentation: `.open`

Expected behavior:

- when a concrete file path is already present in the pasteboard payload, Services should behave as a direct-path open
- it should not depend on a second Finder-selection resolution step
- it must not start Finder-selection polling after the direct path is known

### URL Scheme

- Source: `.urlScheme`
- Path intent: `.direct(path:)`
- Presentation: `.open`

Current supported format:

- `quickcookies://preview?path=/absolute/path/to/file`

Expected behavior:

- URL Scheme is always treated as a direct-path preview request
- it must not silently fall back to Finder-selection semantics
- it must not start Finder-selection polling after the direct path is known
- if accessibility permission is missing, onboarding is shown instead of attempting preview

### Internal navigation

- Source: `.internalNavigation`
- Path intent: `.direct(path:)`
- Presentation: `.open`

Expected behavior:

- plain `Up` opens the previous direct child file in the current directory
- plain `Down` opens the next direct child file in the current directory
- directories are excluded from the navigation order
- Finder selection is not changed or polled as part of internal navigation

## Finder Polling Policy

Continuous app-wide Finder selection polling is no longer the default preview path.

Current expectations:

- Finder-driven sources such as `.hotkey`, `.finderSync`, and `.menuBar` start a scoped 150ms selection watcher only while the overlay is visible.
- Direct-path sources such as `.service`, `.urlScheme`, and `.internalNavigation` must not start Finder-selection polling.
- Finder-driven sources may still describe Finder-selection intent at launch time.
- The scoped watcher accepts Finder, `nil`, and the current QuickCookies bundle identifier as allowed frontmost values because AppKit may briefly report the overlay app or an unknown frontmost process during transitions.
- Finder-driven sources refresh after relevant Finder foreground events: plain `Up`, plain `Down`, and `leftMouseUp`; these events accelerate refresh, but the watcher remains the correctness path.
- Retained key-forwarding code is fallback infrastructure, not primary product behavior.

## Window Geometry

The preview window stable frame is expected to match the visible HUD card bounds.

Current expectations:

- `PreviewOverlaySizingPolicy.stableContentSize(...)` calculates the stable visible-card size.
- Stable window sizing must not include a transparent outer frame.
- `ContentView(cardOuterPadding:)` may still keep a default padding for non-overlay callers, but the overlay passes `0` for stable presentation.
- Open and close animation source-rect expansion is separate from stable sizing and belongs to `PreviewOverlaySizingPolicy.animationSourceRect(...)`.

Manual verification is still required after geometry changes because automated tests cannot judge shadow, rounded corners, blur, animation feel, or macOS edge snapping behavior.

## Error handling baseline

Structured target failures should survive into session state so the overlay and content layer can present a visible error state.

This is especially important for:

- no Finder selection
- file not found
- directory not supported
- unsupported file type

If a new entry path is added, its failures should still end in a visible session error state rather than disappearing in trigger code.

## Manual regression focus

When preview-kernel-related code changes, manual verification should focus on:

1. Hotkey, Services, and URL Scheme converge to the same preview result for the same file.
2. Hotkey toggle still closes an already visible overlay instead of opening a second session.
3. Finder resolution failures still land in a visible error state.
4. Closing and reopening does not leak previous session mode, readiness, or content.
5. Markdown, code, image, PDF, and Office transitions do not flash stale content from the previous file.
6. URL Scheme direct-path open does not depend on current Finder selection.
7. Heavy previews still follow the principle of showing the shell first and loading content asynchronously.
8. Unsupported files and runtime load failures still preserve the resolved target and show the correct title/error state.
9. Finder-driven previews keep Finder focused; direct-path previews may focus QuickCookies.
10. Finder-driven `Up`, `Down`, and mouse selection events accelerate refresh while the scoped watcher keeps the preview in sync.
11. Direct-path plain `Up` and `Down` navigate inside QuickCookies.
12. Only Finder-driven presentations start scoped Finder-selection polling; direct-path presentations do not.

## Change checklist

Before modifying preview flow, ask:

1. Is this trigger logic, target resolution, session state, runtime lifecycle, overlay shell behavior, or content rendering?
2. Am I placing the change in the thinnest responsible layer?
3. Am I accidentally moving business orchestration back into `QuickLookOverlay` or recreating a second business-state owner outside `PreviewSession`?

If the answer to question 3 is yes, stop and redesign the change.
