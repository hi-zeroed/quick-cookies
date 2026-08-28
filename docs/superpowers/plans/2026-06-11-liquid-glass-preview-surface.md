# Liquid Glass Preview Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Liquid Glass-compatible surface layer to QuickCookies' preview chrome, toolbar, toast, and custom alert while preserving readable preview content and macOS 13+ compatibility.

**Architecture:** Introduce a small `QuickGlass` UI layer that separates policy decisions from SwiftUI rendering. Pure policy is covered by XCTest; SwiftUI modifiers use availability guards so macOS 26 can use Liquid Glass APIs when the build SDK supports them, while macOS 13-25 keep the current `NSVisualEffectView` fallback.

**Tech Stack:** Swift 5, SwiftUI, AppKit `NSVisualEffectView`, XCTest, Xcode project file source wiring.

---

## Scope

This plan implements the approved first phase:

- Preview window outer chrome
- Top toolbar surface
- Toast surface
- CustomAlert surface
- Reusable surface policy and modifier
- XCTest coverage for non-visual policy

This plan intentionally does not glassify code, Markdown, PDF, Office, image, or editor content backgrounds. Those surfaces must remain stable and readable.

## Files

- Create: `QuickCookies/UI/QuickGlass.swift`
  - Owns `QuickGlassSurface`, policy structs, and SwiftUI modifiers.
  - Provides `.quickGlass(...)` view extension.
  - Keeps macOS 26 API references guarded so the project still builds with deployment target macOS 13.
- Create: `QuickCookiesTests/QuickGlassTests.swift`
  - Tests surface policy and accessibility fallback decisions.
- Modify: `QuickCookies/UI/ContentView.swift`
  - Replaces preview outer and toolbar `VisualEffectView` backgrounds with semantic glass surfaces.
  - Leaves content area backgrounds unchanged.
- Modify: `QuickCookies/UI/ToastView.swift`
  - Uses transient glass surface for toast background.
- Modify: `QuickCookies/UI/CustomAlert.swift`
  - Uses transient glass surface for alert capsule background.
- Modify: `QuickCookies.xcodeproj/project.pbxproj`
  - Adds `QuickGlass.swift` to app sources.
  - Adds `QuickGlassTests.swift` to test sources.

## Compatibility Notes

- The current project uses `MACOSX_DEPLOYMENT_TARGET = 13.0`.
- All new code must compile on macOS 13 deployment target.
- If the local Xcode SDK does not expose macOS 26 `glassEffect` symbols, keep the public `QuickGlass` abstraction and fallback implementation compiling. In that case, the runtime modifier must report system glass as unavailable so macOS 26 still receives the visual-effect fallback instead of a transparent background.
- Do not add runtime settings that subscribe `ContentView` root to `Settings.shared`; the existing comment in `ContentView.swift` says global settings subscriptions can cause broad redraws.

## Task 1: Add QuickGlass Policy Tests

**Files:**
- Create: `QuickCookiesTests/QuickGlassTests.swift`
- Modify: `QuickCookies.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create the failing test file**

Create `QuickCookiesTests/QuickGlassTests.swift`:

```swift
import XCTest
@testable import QuickCookies

final class QuickGlassTests: XCTestCase {
    func test_windowSurfaceUsesHudFallbackWhenSystemGlassUnavailable() {
        let style = QuickGlassPresentationPolicy.style(
            for: .window,
            systemGlassAvailable: false,
            reduceTransparency: false,
            increasedContrast: false
        )

        XCTAssertEqual(style, .visualEffect(material: .hudWindow, blendingMode: .behindWindow))
    }

    func test_transientSurfaceUsesSolidBackgroundWhenTransparencyIsReduced() {
        let style = QuickGlassPresentationPolicy.style(
            for: .transient,
            systemGlassAvailable: true,
            reduceTransparency: true,
            increasedContrast: false
        )

        XCTAssertEqual(style, .solidBackground(opacity: 0.98))
    }

    func test_toolbarSurfaceUsesSystemGlassWhenAvailable() {
        let style = QuickGlassPresentationPolicy.style(
            for: .toolbar,
            systemGlassAvailable: true,
            reduceTransparency: false,
            increasedContrast: false
        )

        XCTAssertEqual(style, .systemGlass(kind: .regular))
    }

    func test_increasedContrastUsesStrongerBorder() {
        let normal = QuickGlassPresentationPolicy.borderOpacity(
            for: .toolbar,
            increasedContrast: false,
            colorScheme: .dark
        )
        let increased = QuickGlassPresentationPolicy.borderOpacity(
            for: .toolbar,
            increasedContrast: true,
            colorScheme: .dark
        )

        XCTAssertGreaterThan(increased, normal)
    }
}
```

- [ ] **Step 2: Add the test file to the Xcode project**

Edit `QuickCookies.xcodeproj/project.pbxproj` by following the existing `TSTREF...` and `TSTBLD...` pattern:

```pbxproj
TSTREF00000000000000001D /* QuickGlassTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = QuickGlassTests.swift; sourceTree = "<group>"; };
TSTBLD00000000000000001D /* QuickGlassTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = TSTREF00000000000000001D /* QuickGlassTests.swift */; };
```

Add `TSTREF00000000000000001D` to the `QuickCookiesTests` group children list after `FinderMenuIntegrationTests.swift`.

Add `TSTBLD00000000000000001D` to `TSTSRC000000000000000001 /* Sources */` files.

- [ ] **Step 3: Run the focused test and verify it fails**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-policy-red -only-testing:QuickCookiesTests/QuickGlassTests
```

Expected: FAIL because `QuickGlassPresentationPolicy` and related types do not exist yet.

## Task 2: Implement QuickGlass Policy And Fallback Modifier

**Files:**
- Create: `QuickCookies/UI/QuickGlass.swift`
- Modify: `QuickCookies.xcodeproj/project.pbxproj`
- Test: `QuickCookiesTests/QuickGlassTests.swift`

- [ ] **Step 1: Add `QuickGlass.swift`**

Create `QuickCookies/UI/QuickGlass.swift`:

```swift
import SwiftUI

enum QuickGlassSurface: Equatable {
    case window
    case toolbar
    case control
    case transient
}

enum QuickGlassKind: Equatable {
    case regular
}

enum QuickGlassPresentationStyle: Equatable {
    case systemGlass(kind: QuickGlassKind)
    case visualEffect(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode)
    case solidBackground(opacity: Double)
}

enum QuickGlassPresentationPolicy {
    static func style(
        for surface: QuickGlassSurface,
        systemGlassAvailable: Bool,
        reduceTransparency: Bool,
        increasedContrast: Bool
    ) -> QuickGlassPresentationStyle {
        if reduceTransparency || increasedContrast {
            return .solidBackground(opacity: reduceTransparency ? 0.98 : 0.94)
        }

        if systemGlassAvailable {
            return .systemGlass(kind: .regular)
        }

        switch surface {
        case .window, .toolbar:
            return .visualEffect(material: .hudWindow, blendingMode: .behindWindow)
        case .control, .transient:
            return .visualEffect(material: .hudWindow, blendingMode: .withinWindow)
        }
    }

    static func borderOpacity(
        for surface: QuickGlassSurface,
        increasedContrast: Bool,
        colorScheme: ColorScheme
    ) -> Double {
        if increasedContrast {
            return colorScheme == .dark ? 0.42 : 0.18
        }

        switch surface {
        case .window:
            return colorScheme == .dark ? 0.26 : 0.08
        case .toolbar:
            return colorScheme == .dark ? 0.20 : 0.07
        case .control:
            return colorScheme == .dark ? 0.18 : 0.06
        case .transient:
            return colorScheme == .dark ? 0.22 : 0.10
        }
    }
}

private struct QuickGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityContrast) private var accessibilityContrast
    @Environment(\.colorScheme) private var colorScheme

    let surface: QuickGlassSurface
    let shape: S

    func body(content: Content) -> some View {
        let increasedContrast = accessibilityContrast == .increased
        let style = QuickGlassPresentationPolicy.style(
            for: surface,
            systemGlassAvailable: Self.systemGlassAvailable,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast
        )

        return content
            .background(background(for: style))
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    borderColor(increasedContrast: increasedContrast),
                    lineWidth: increasedContrast ? 1 : 0.75
                )
            }
    }

    @ViewBuilder
    private func background(for style: QuickGlassPresentationStyle) -> some View {
        switch style {
        case .systemGlass:
            fallbackBackground()
        case let .visualEffect(material, blendingMode):
            fallbackBackground(material: material, blendingMode: blendingMode)
        case let .solidBackground(opacity):
            Color.appBackground.opacity(opacity)
        }
    }

    private func fallbackBackground(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) -> some View {
        VisualEffectView(material: material, blendingMode: blendingMode)
    }

    private func borderColor(increasedContrast: Bool) -> Color {
        let opacity = QuickGlassPresentationPolicy.borderOpacity(
            for: surface,
            increasedContrast: increasedContrast,
            colorScheme: colorScheme
        )
        return colorScheme == .dark ? Color.white.opacity(opacity) : Color.black.opacity(opacity)
    }

    private static var systemGlassAvailable: Bool {
        return false
    }
}

extension View {
    func quickGlass<S: Shape>(_ surface: QuickGlassSurface, in shape: S) -> some View {
        modifier(QuickGlassModifier(surface: surface, shape: shape))
    }

    func quickGlass(_ surface: QuickGlassSurface, cornerRadius: CGFloat) -> some View {
        quickGlass(surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
```

- [ ] **Step 2: Add the app source file to the Xcode project**

Edit `QuickCookies.xcodeproj/project.pbxproj` by following the existing `ContentView.swift` pattern:

```pbxproj
QGLASSREF000000000000001 /* QuickGlass.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = QuickGlass.swift; sourceTree = "<group>"; };
QGLASSBLD000000000000001 /* QuickGlass.swift in Sources */ = {isa = PBXBuildFile; fileRef = QGLASSREF000000000000001 /* QuickGlass.swift */; };
```

Add `QGLASSREF000000000000001` to the `UI` group children list near `ContentView.swift`.

Add `QGLASSBLD000000000000001` to the app target `SSS191919191919191919191 /* Sources */` files near other UI files.

- [ ] **Step 3: Run focused tests and verify policy passes**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-policy-green -only-testing:QuickCookiesTests/QuickGlassTests
```

Expected: PASS.

- [ ] **Step 4: Commit policy layer**

Run:

```bash
git add QuickCookies/UI/QuickGlass.swift QuickCookiesTests/QuickGlassTests.swift QuickCookies.xcodeproj/project.pbxproj
git commit -m "feat(ui): add liquid glass surface policy" -m "Introduce a semantic QuickGlass layer with accessibility-aware fallback policy and XCTest coverage."
```

## Task 3: Apply QuickGlass To Preview Window And Toolbar

**Files:**
- Modify: `QuickCookies/UI/ContentView.swift`
- Test: `QuickCookiesTests/QuickGlassTests.swift`

- [ ] **Step 1: Replace the preview root background**

In `ContentView.body`, replace:

```swift
.background(
    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
)
.clipShape(RoundedRectangle(cornerRadius: PreviewCardChromePolicy.cornerRadius, style: .continuous))
.overlay(cardChromeBorder)
```

with:

```swift
.quickGlass(.window, cornerRadius: PreviewCardChromePolicy.cornerRadius)
.overlay(cardChromeBorder)
```

Keep the existing `.padding(cardOuterPadding)` and `.background(Color.clear)`.

- [ ] **Step 2: Replace the toolbar background**

In `ContentView.toolbar`, replace:

```swift
.background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
```

with:

```swift
.quickGlass(.toolbar, in: Rectangle())
```

Do not move the toolbar out of the current `VStack`; the content area z-index behavior is already intentional.

- [ ] **Step 3: Build for testing**

Run:

```bash
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-content build-for-testing
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run focused policy tests again**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-content-tests -only-testing:QuickCookiesTests/QuickGlassTests
```

Expected: PASS.

- [ ] **Step 5: Commit preview chrome integration**

Run:

```bash
git add QuickCookies/UI/ContentView.swift
git commit -m "feat(ui): apply glass surfaces to preview chrome" -m "Use the QuickGlass abstraction for the preview window shell and toolbar while preserving content backgrounds."
```

## Task 4: Apply QuickGlass To Toast And CustomAlert

**Files:**
- Modify: `QuickCookies/UI/ToastView.swift`
- Modify: `QuickCookies/UI/CustomAlert.swift`

- [ ] **Step 1: Update Toast background**

In `ToastView.body`, replace the existing rounded rectangle background:

```swift
.background(
    RoundedRectangle(cornerRadius: 18)
        .fill(Color(white: 0.12).opacity(0.85)) // 统一深色高档半透明磨砂背景，适配深浅色模式
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
)
```

with:

```swift
.quickGlass(.transient, cornerRadius: 18)
.shadow(color: Color.black.opacity(0.20), radius: 8, x: 0, y: 4)
```

Keep the existing text, padding, and frame.

- [ ] **Step 2: Update CustomAlert background**

In `CustomAlertModifier.body`, replace:

```swift
.background(
    Capsule()
        .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.95) : Color.white.opacity(0.95))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 8, x: 0, y: 4)
)
.overlay(
    Capsule()
        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.5)
)
```

with:

```swift
.quickGlass(.transient, in: Capsule())
.shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 8, x: 0, y: 4)
```

Keep the transition, z-index, and padding unchanged.

- [ ] **Step 3: Build for testing**

Run:

```bash
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-transient build-for-testing
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit transient surfaces**

Run:

```bash
git add QuickCookies/UI/ToastView.swift QuickCookies/UI/CustomAlert.swift
git commit -m "feat(ui): use glass surfaces for transient feedback" -m "Apply QuickGlass transient styling to toast and custom alert surfaces without changing their presentation behavior."
```

## Task 5: Add SDK-Backed Liquid Glass Branch When Available

**Files:**
- Modify: `QuickCookies/UI/QuickGlass.swift`

- [ ] **Step 1: Check whether the active SDK exposes SwiftUI glass APIs**

Run:

```bash
xcrun swift -version
xcrun --show-sdk-path --sdk macosx
```

Then search SDK Swift interfaces:

```bash
SDK_PATH="$(xcrun --show-sdk-path --sdk macosx)"
rg -n "glassEffect|GlassEffectContainer" "$SDK_PATH/System/Library/Frameworks/SwiftUI.framework" || true
```

Expected:

- If symbols are found, continue to Step 2.
- If no symbols are found, skip Step 2 and record in the final implementation notes that this branch remains fallback-only until the project is built with a macOS 26 SDK.

- [ ] **Step 2: Add the guarded `glassEffect` call if SDK supports it**

In `QuickGlassModifier`, add the smallest compiling SDK-backed implementation and switch `systemGlassAvailable` to return true only on macOS 26 or newer. The intended shape is:

```swift
@ViewBuilder
private func background(for style: QuickGlassPresentationStyle) -> some View {
    switch style {
    case .systemGlass:
        systemGlassBackground()
    case let .visualEffect(material, blendingMode):
        fallbackBackground(material: material, blendingMode: blendingMode)
    case let .solidBackground(opacity):
        Color.appBackground.opacity(opacity)
    }
}

@ViewBuilder
private func systemGlassBackground() -> some View {
    if #available(macOS 26.0, *) {
        Color.clear
            .glassEffect(.regular, in: shape)
    } else {
        fallbackBackground()
    }
}

private static var systemGlassAvailable: Bool {
    if #available(macOS 26.0, *) {
        return true
    }
    return false
}
```

If the SDK signature differs, use the SDK's exact signature and keep the call inside the `#available(macOS 26.0, *)` branch. If the SDK supports Liquid Glass but the call requires a different shape type, keep the public `.quickGlass(...)` extensions unchanged and adapt only the private modifier internals. Do not duplicate Liquid Glass code in `ContentView`, `ToastView`, or `CustomAlert`.

- [ ] **Step 3: Build for testing**

Run:

```bash
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-sdk build-for-testing
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit SDK branch if implemented**

Only run this commit if Step 2 changed code:

```bash
git add QuickCookies/UI/QuickGlass.swift
git commit -m "feat(ui): enable liquid glass when available" -m "Use SwiftUI Liquid Glass behind availability guards while keeping the visual-effect fallback for older systems."
```

## Task 6: Final Verification

**Files:**
- Read: `docs/preview-manual-test-checklist.md`
- Verify: app target and tests

- [ ] **Step 1: Run project build-for-testing after project wiring changes**

Run:

```bash
xcodebuild -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-final-bft build-for-testing
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 2: Run the focused QuickGlass tests**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-final-focused -only-testing:QuickCookiesTests/QuickGlassTests
```

Expected: PASS.

- [ ] **Step 3: Run full test suite**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath buildTest-liquid-glass-final-full
```

Expected: PASS.

- [ ] **Step 4: Manual visual checks**

Use the app on the current machine and check:

- Hotkey opens preview overlay.
- Preview window edges remain transparent outside the rounded card.
- Toolbar is visible above Markdown and PDF content.
- Code and plain text content backgrounds remain readable and are not transparent.
- Toast appears and dismisses after `Constants.toastDuration`.
- CustomAlert still appears at the bottom and its buttons work.
- Dark mode and light mode both have visible borders.
- With Reduce Transparency enabled in System Settings, surfaces become solid enough to read.
- With Increase Contrast enabled, border contrast increases.

- [ ] **Step 5: Final commit if any verification fixes were needed**

If Step 4 required code changes, commit them:

```bash
git add QuickCookies/UI QuickCookiesTests QuickCookies.xcodeproj/project.pbxproj
git commit -m "fix(ui): refine liquid glass surface behavior" -m "Address visual verification issues found during Liquid Glass preview surface testing."
```

## Self-Review

- Spec coverage: The plan covers the approved first phase: preview shell, toolbar, Toast, CustomAlert, compatibility, accessibility fallback, and testing.
- Scope boundary: Settings and Onboarding are excluded from implementation and remain future phases.
- Placeholder scan: No task uses open-ended implementation placeholders; the only conditional branch is the SDK-backed `glassEffect` call, with explicit skip behavior if the local SDK lacks macOS 26 symbols.
- Type consistency: `QuickGlassSurface`, `QuickGlassPresentationStyle`, `QuickGlassKind`, and `QuickGlassPresentationPolicy` names are consistent across tests and implementation steps.
