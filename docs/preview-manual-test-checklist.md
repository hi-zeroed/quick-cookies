# Preview Manual Test Checklist

Date: 2026-06-09
Status: Active checklist
Scope: Preview Kernel regression focus

## Purpose

This checklist is for manual verification after changes to preview entry flow, session state, overlay behavior, or runtime reuse.

It is intentionally focused on system-coupled paths that automated tests do not fully replace:

- global hotkey
- Finder selection
- Services menu
- URL Scheme wake-up
- focus handoff
- internal Up/Down navigation
- window geometry and visual baseline
- WebKit-backed preview reuse

## Core scenarios

### 1. Hotkey open and toggle

- In Finder, select a supported text or Markdown file.
- Trigger the configured hotkey.
- Confirm the preview opens for the selected file.
- Trigger the hotkey again while the overlay is visible.
- Confirm the overlay closes instead of opening a second preview session.

Focus on:

- toggle behavior still works
- selected file is correct
- no stale content from a previous file
- Finder remains focused and keeps the blue selection highlight
- triggering the hotkey again closes the preview
- Finder-driven preview keeps its scoped watcher while visible, without pulling direct-path flows into Finder polling

### 1.1 Finder selection event refresh

- In Finder, select the middle file in a folder with several previewable files.
- Trigger the configured hotkey.
- Press `Down` in Finder.
- Confirm Finder selection moves to the next file and QuickCookies refreshes to that file.
- Press `Up` in Finder.
- Confirm Finder selection moves back and QuickCookies refreshes again.
- Mouse-click another file in the same Finder window.
- Confirm QuickCookies refreshes to the clicked file.

Focus on:

- Finder owns the selection and keyboard focus
- toolbar title, render type, and content all match the Finder-selected file
- no stale previous content appears during quick switching
- refresh stays correct whether the update comes from the event burst or the scoped watcher
- `Esc` is not part of the expected close path; use the global hotkey toggle to close

### 2. Services direct-path open

- In Finder, invoke the QuickCookies Services item on a supported file.
- Confirm the preview opens for that exact file.
- Repeat with a different supported file type if possible.

Focus on:

- Services behaves like a direct-path open
- it does not start Finder-selection polling after the path has already been handed over
- the preview window may focus QuickCookies because the path is already explicit
- Up/Down navigation after opening still uses QuickCookies internal navigation

### 3. URL Scheme direct-path open

- Run a URL such as:
  - `quickcookies://preview?path=/absolute/path/to/file`
- Confirm QuickCookies opens the file referenced by the URL.
- Repeat while Finder is focused on a different file.

Focus on:

- URL Scheme must open the direct path from the query
- URL Scheme must not silently fall back to current Finder selection
- if Accessibility permission is missing, Onboarding may appear instead of a preview; do not treat that as a visual preview baseline

### 4. Finder resolution failure

- Trigger the hotkey with no suitable Finder file selected.
- Trigger the hotkey with a directory selected.
- Trigger the hotkey with an unsupported file type if available.

Focus on:

- app still presents a visible error state
- no silent failure
- no stale previous preview remains on screen

### 5. Session reset between files

- Open file A.
- Close the overlay.
- Open file B of a different type.

Focus on:

- previous file content does not flash
- previous error state does not persist
- edit and preview mode does not leak across sessions

### 6. Edit to preview round-trip

- Open a supported editable text file.
- Enter edit mode.
- Return to preview mode.
- Trigger the global hotkey after returning to preview mode.

Focus on:

- editing can focus QuickCookies when needed
- the global hotkey still closes the preview after the edit-to-preview round-trip
- preview content still matches the current file
- first-drag behavior still does not require an extra activation click

### 7. Cross-type transitions

- Open files across several types:
  - Markdown
  - code or plain text
  - image
  - PDF
  - Office document

Focus on:

- renderer switches cleanly
- no stale WebKit content flashes during transitions
- heavy previews do not reuse the wrong content from the previous target

### 8. Heavy preview loading behavior

- Open a large or heavy file such as image, PDF, or Office document.

Focus on:

- shell appears first
- content loads asynchronously
- app does not feel blocked before the window appears

### 9. External file change handling

- Open a text file.
- Modify it externally.

Focus on:

- current session remains bound to the correct file
- reload handling, prompt, or refresh behavior still makes sense
- no mix-up with a previously opened file

### 10. Direct-path internal file navigation

- Put at least three supported files in one directory.
- Open the middle file through Services or URL Scheme.
- Press `Down`.
- Confirm QuickCookies opens the next file in the same directory.
- Press `Up`.
- Confirm QuickCookies returns to the previous file.
- Enter edit mode for an editable text file.
- Press `Up` and `Down`.
- Confirm the editor receives those keys instead of switching files.

Focus on:

- navigation uses direct file paths, not Finder selection polling
- direct-path navigation does not get pulled back into Finder selection follow
- directories are skipped
- toolbar title, render type, content, and error state all belong to the newly opened file
- Finder selection does not need to change

### 11. Window focus and drag behavior

- Open Markdown or code preview from Finder using the global hotkey.
- Confirm Finder remains focused and keeps the blue selection highlight.
- Without clicking inside the window first, drag the visible HUD card if the current presentation allows it.
- Open the same file through Services or URL Scheme.
- Confirm QuickCookies can become interactive for the direct-path presentation.
- Drag the visible HUD card.

Focus on:

- Finder-driven and direct-path presentations use the expected focus model
- the first drag attempt does not require an avoidable extra activation click
- `Esc` is not a required close shortcut; close through the global hotkey toggle or explicit window control
- Office, image, and PDF previews still open normally

### 12. Window geometry visual regression

- Open and inspect stable-state previews for:
  - Markdown or code
  - unsupported or error compact state
  - image
  - PDF
  - Office
- Inspect or record:
  - open animation
  - close animation
  - Finder icon fly-back, if available
  - left and right edge snapping
  - top-edge system zoom behavior

Focus on:

- shadow is complete and not clipped
- corner radius is consistent
- blur or material background is consistent
- toolbar height and content offset are consistent
- animation has no obvious flicker, clipping, or first-frame jump
- AppKit window bounds match the visible card
- dragging to left or right screen edges snaps by the visible card, not an invisible outer margin
- dragging to the top edge no longer leaves the visible card smaller than the system-expanded window

## Notes for testers

- Prefer testing at least one path through hotkey, Services, and URL Scheme.
- Prefer testing one direct-path flow and one Finder-selection flow in the same pass.
- Do not approve window-geometry changes if the visible HUD card loses its accepted shadow, rounded corners, blur, spacing, or animation feel.
- If a failure appears, record:
  - trigger type
  - selected file type
  - whether a previous preview had been opened before
  - whether the failure looked like wrong target, stale content, wrong mode, or missing error state
