# Finder Selection Follow Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore reliable Finder up/down and mouse selection following while keeping the preview window non-key and avoiding polling for non-Finder preview sources.

**Architecture:** Treat Finder selection following as an overlay session state, not as a best-effort global event side effect. Finder-driven previews (`hotkey`, `finderSync`, `menuBar`) start the existing `FinderSelectionPollingController` only while the overlay window is visible; direct previews (`service`, `urlScheme`, `internalNavigation`) do not start it. The scoped watcher allows Finder, unknown frontmost app, and the current QuickCookies bundle as frontmost fallbacks because AppKit can temporarily report the non-key overlay app as frontmost after `orderFrontRegardless()`. Existing event burst refresh remains an acceleration path, but correctness no longer depends on `NSEvent.addGlobalMonitorForEvents`.

**Tech Stack:** Swift, AppKit `NSPanel`/`NSEvent`, existing `FinderSelectionPollingController`, XCTest.

---

### Task 1: Lock Finder-Driven Polling Policy

**Files:**
- Modify: `QuickCookiesTests/QuickLookOverlayStateTests.swift`
- Modify: `QuickCookies/UI/QuickLookOverlay.swift`

- [ ] **Step 1: Write the failing test**

Replace the current `test_previewOverlayFinderFollowPolicy_doesNotStartContinuousSelectionPollingByDefault` expectation with:

```swift
func test_previewOverlayFinderFollowPolicy_startsSelectionPollingForFinderDrivenSourcesOnly() {
    XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .hotkey))
    XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .finderSync))
    XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .menuBar))
    XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .urlScheme))
    XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .service))
    XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .internalNavigation))
    XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: nil))
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests
```

Expected: FAIL because `shouldStartSelectionPolling(for:)` currently returns `false` for Finder-driven sources.

- [ ] **Step 3: Implement minimal policy change**

Change `PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for:)` to:

```swift
static func shouldStartSelectionPolling(for source: PreviewLaunchSource?) -> Bool {
    shouldFollowFinderSelection(for: source)
}
```

- [ ] **Step 4: Update overlay comment**

Replace the stale comment above `finderSelectionPollingController.start()` with:

```swift
// Finder-driven previews keep a scoped selection watcher while visible.
// Direct-path previews avoid polling entirely.
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests
```

Expected: PASS.

### Task 2: Make Scoped Polling Tolerate Overlay Frontmost Fallback

**Files:**
- Modify: `QuickCookies/Core/Preview/PreviewLaunchRequest.swift`
- Modify: `QuickCookies/UI/QuickLookOverlay.swift`
- Test: `QuickCookiesTests/PreviewLaunchRequestTests.swift`

- [ ] **Step 1: Write failing request-layer tests**

Add tests that prove the default polling gate still ignores non-Finder apps, while an explicitly scoped fallback can refresh when frontmost is the QuickCookies app:

```swift
func test_finderSelectionPollingController_startKeepsDefaultFrontmostGate() {
    var createdTimer: PollingTimerSpy?
    var capturedRequest: PreviewLaunchRequest?
    let controller = FinderSelectionPollingController(
        timerFactory: { _, tick in
            let timer = PollingTimerSpy(tick: tick)
            createdTimer = timer
            return timer
        },
        frontmostBundleIdentifier: { "com.apple.TextEdit" },
        detectSelectionPath: { Result<String, any Error>.success("/tmp/next.md") },
        detectSourceRect: { .zero },
        onRequest: { request in
            capturedRequest = request
        },
        onSourceRectUpdate: { _ in },
        runAsync: { work in work() },
        deliverOnMain: { work in work() }
    )

    controller.syncCurrentResolvedPath("/tmp/old.md")
    controller.start()
    createdTimer?.fire()

    XCTAssertNil(capturedRequest)
}

func test_finderSelectionPollingController_startAllowsScopedFallbackFrontmostApp() {
    var createdTimer: PollingTimerSpy?
    var capturedRequest: PreviewLaunchRequest?
    let controller = FinderSelectionPollingController(
        timerFactory: { _, tick in
            let timer = PollingTimerSpy(tick: tick)
            createdTimer = timer
            return timer
        },
        frontmostBundleIdentifier: { "com.quickcookies.app" },
        detectSelectionPath: { Result<String, any Error>.success("/tmp/next.md") },
        detectSourceRect: { .zero },
        onRequest: { request in
            capturedRequest = request
        },
        onSourceRectUpdate: { _ in },
        runAsync: { work in work() },
        deliverOnMain: { work in work() }
    )

    controller.syncCurrentResolvedPath("/tmp/old.md")
    controller.start(
        additionalAllowedFrontmostBundleIdentifiers: ["com.quickcookies.app"]
    )
    createdTimer?.fire()

    XCTAssertEqual(
        capturedRequest,
        .openPath("/tmp/next.md", source: .finderSync)
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests
```

Expected: FAIL before implementation because `FinderSelectionPollingController.start(...)` cannot pass scoped frontmost fallbacks into its timer refresh.

- [ ] **Step 3: Thread fallback options through polling start**

Change `FinderSelectionPollingController.start(...)` to accept the same optional frontmost fallback arguments used by `refresh(...)`, and call `refresh(...)` with them from the timer tick.

- [ ] **Step 4: Pass current app fallback from Finder-driven overlay sessions**

In `QuickLookOverlay.showOverlay(session:)`, keep the `shouldStartSelectionPolling(for:)` gate, and call:

```swift
finderSelectionPollingController.start(
    allowsUnknownFrontmost: true,
    additionalAllowedFrontmostBundleIdentifiers: Set(
        [Bundle.main.bundleIdentifier].compactMap { $0 }
    )
)
```

- [ ] **Step 5: Run focused request tests**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests
```

Expected: PASS.

### Task 3: Verify No Regression In Overlay Policy

**Files:**
- Test: `QuickCookiesTests/QuickLookOverlayStateTests.swift`

- [ ] **Step 1: Run focused overlay tests**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests
```

Expected: PASS. Existing tests verify Finder-driven sources start selection polling and direct-path sources do not.

### Task 4: Full Verification

**Files:**
- Verify entire project.

- [ ] **Step 1: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: exit 0.

- [ ] **Step 2: Run full XCTest**

Run:

```bash
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath build/xctest-derived/finder-selection-follow-repair-final
```

Expected: `TEST SUCCEEDED`.

- [ ] **Step 3: Manual test checklist**

Ask the user to verify:

```text
1. Finder 中选中文件后热键打开预览。
2. 按上下键切换 Finder 文件，预览标题、状态栏、正文同步变化。
3. 鼠标点击 Finder 中另一个文件，预览同步变化。
4. 快速连续切换时标题和内容不交叉错配。
5. 预览窗口仍不抢 Finder 焦点。
6. 热键 toggle 仍能关闭预览。
```
