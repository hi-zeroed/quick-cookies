# Preview Interaction Redesign Visual Baseline

Date: 2026-06-09
Status: Automated baseline unavailable; Phase 4 requires manual verification

## Purpose

This folder stores evidence and notes for preview window geometry visual verification.

The current HUD card UI is already accepted. Geometry changes can easily break shadow, rounded corners, blur, spacing, and animation feel, so automated logic tests are not enough.

## Current Evidence

Environment checks during the automated capture attempt:

- `osascript -e 'tell application "System Events" to UI elements enabled'` returned `false`.
- `defaults read com.quickcookies.app hasCompletedOnboarding` returned `1`.
- A running `QuickCookies` process was present.

Captured files:

- `window-107025.png`: captured from an existing `QuickCookies` window with bounds `500 x 500`; the result is a black image and is not usable as a preview baseline.
- `window-110288-after-url.png`: captured after opening `quickcookies://preview?path=<markdown-file>`; the result is the Onboarding window, not a preview window.

Observed reason:

- `AppDelegate.application(_:open:)` checks `AXIsProcessTrusted()`.
- When Accessibility permission is missing, URL Scheme preview requests are redirected to Onboarding.
- Therefore the automated URL Scheme path cannot produce preview-window baseline screenshots in the current environment.

## Manual Verification Still Required

Phase 4 has been implemented in code, but these states still need to be checked manually from a real preview window:

- Markdown or code preview stable state.
- Unsupported or error compact stable state.
- Image preview stable state.
- PDF preview stable state.
- Office preview stable state.
- Open animation.
- Hotkey-toggle or close-button close animation.
- Finder icon fly-back close animation.
- First-click drag behavior.
- Left and right edge snapping behavior.
- Top-edge system zoom behavior.

Each capture should note whether these are visually unchanged:

- shadow is complete and not clipped
- corner radius is consistent
- blur or material background is consistent
- toolbar height and content offset are consistent
- animation has no obvious flicker, clipping, or first-frame jump

## Phase 4 Verification

Phase 4 changed the stable window geometry so the AppKit window frame matches the visible card instead of including a transparent outer margin.

Verify manually that:

- left and right edge snapping use the visible card edge
- top-edge system zoom no longer leaves the visible card smaller by an invisible margin
- the HUD card still keeps its accepted shadow, rounded corners, blur, spacing, and animation feel
- open and close animations do not show clipping, flicker, or first-frame jumps

Relevant implementation points:

- stable sizing: `PreviewOverlaySizingPolicy.stableContentSize(...)`
- animation source expansion: `PreviewOverlaySizingPolicy.animationSourceRect(...)`
- overlay stable card padding: `ContentView(cardOuterPadding: 0)`
