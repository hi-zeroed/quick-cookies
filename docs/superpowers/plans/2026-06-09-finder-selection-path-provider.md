# Finder Selection Path Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变当前用户体验的前提下，把 Finder 当前选中文件路径的发现能力从 `FileDetector` 静态调用收口成独立、可替换、可测试的 provider 边界。

**Architecture:** 先在 `FileDetector.swift` 内引入 `FinderSelectionPathProviding` 和 `AppleScriptFinderSelectionPathProvider`，保留 `FileDetector.getSelectedFilePath()` 作为兼容外壳。然后分三步迁移调用点：`PreviewTargetResolver`、`FinderMenuIntegration`、`QuickLookOverlay`/polling closure，最后补 provider 层测试与维护文档。整个过程不改 Finder-driven scoped watcher、AX source rect、窗口焦点或 UI。

**Tech Stack:** Swift, Foundation, AppKit `NSAppleScript`, existing preview coordinator / overlay flow, XCTest, `xcodebuild`

---

## File Structure

### Existing files to modify

- Modify: `QuickCookies/Core/FileDetector.swift`
- Modify: `QuickCookies/Core/Preview/PreviewTargetResolver.swift`
- Modify: `QuickCookies/Core/FinderMenuIntegration.swift`
- Modify: `QuickCookies/UI/QuickLookOverlay.swift`
- Modify: `QuickCookies/App/AppDelegate.swift`
- Modify: `QuickCookiesTests/PreviewTargetTests.swift`
- Modify: `QuickCookiesTests/PreviewCoordinatorTests.swift`
- Modify: `QuickCookies.xcodeproj/project.pbxproj`
- Modify: `docs/xctest-feasibility.md`

### New files to create

- Create: `QuickCookiesTests/FinderSelectionPathProviderTests.swift`
- Create: `QuickCookiesTests/FinderMenuIntegrationTests.swift`

### Validation commands

- `./scripts/run-focused-xctest.sh QuickCookiesTests/FinderSelectionPathProviderTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/FinderMenuIntegrationTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewTargetTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewCoordinatorTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests`
- `./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests`
- `xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath build/xctest-derived/finder-selection-path-provider`
- `git diff --check`

## Task 1: Introduce `FinderSelectionPathProviding` And Provider-Level Tests

**Files:**
- Modify: `QuickCookies/Core/FileDetector.swift`
- Create: `QuickCookiesTests/FinderSelectionPathProviderTests.swift`
- Modify: `QuickCookies.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the failing provider test file and wire it into the test target**

Create `QuickCookiesTests/FinderSelectionPathProviderTests.swift` with:

```swift
import AppKit
import XCTest
@testable import QuickCookies

final class FinderSelectionPathProviderTests: XCTestCase {
    func test_selectedPath_returnsFinderNotRunningWhenFinderIsUnavailable() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { false },
            selectionScriptFactory: {
                XCTFail("selectionScriptFactory should not run when Finder is unavailable")
                return nil
            },
            executeScript: { _ in
                XCTFail("executeScript should not run when Finder is unavailable")
                return .failure(.scriptingBridgeError("unexpected"))
            }
        )

        XCTAssertEqual(
            provider.selectedPath(),
            .failure(.finderNotRunning)
        )
    }

    func test_selectedPath_returnsScriptInitializationFailureWhenScriptFactoryReturnsNil() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { nil },
            executeScript: { _ in
                XCTFail("executeScript should not run when script creation fails")
                return .failure(.scriptingBridgeError("unexpected"))
            }
        )

        XCTAssertEqual(
            provider.selectedPath(),
            .failure(.scriptingBridgeError("无法初始化 AppleScript 脚本"))
        )
    }

    func test_selectedPath_returnsExecutionFailureFromInjectedExecutor() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { NSAppleScript(source: "return \"/tmp/demo.md\"") },
            executeScript: { _ in
                .failure(.scriptingBridgeError("AppleScript boom"))
            }
        )

        XCTAssertEqual(
            provider.selectedPath(),
            .failure(.scriptingBridgeError("AppleScript boom"))
        )
    }

    func test_selectedPath_returnsNoSelectionWhenExecutorReportsEmptySelection() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { NSAppleScript(source: "return \"\"") },
            executeScript: { _ in
                .failure(.noFileSelected)
            }
        )

        XCTAssertEqual(
            provider.selectedPath(),
            .failure(.noFileSelected)
        )
    }

    func test_selectedPath_returnsResolvedPathWhenExecutorSucceeds() {
        let provider = AppleScriptFinderSelectionPathProvider(
            isFinderRunning: { true },
            selectionScriptFactory: { NSAppleScript(source: "return \"/tmp/demo.md\"") },
            executeScript: { _ in
                .success("/tmp/demo.md")
            }
        )

        XCTAssertEqual(
            provider.selectedPath(),
            .success("/tmp/demo.md")
        )
    }
}
```

Add the new test file to `QuickCookies.xcodeproj/project.pbxproj`:

```text
1. Add a new `PBXFileReference` for `FinderSelectionPathProviderTests.swift` under the `QuickCookiesTests` group.
2. Add a new `PBXBuildFile` entry for `FinderSelectionPathProviderTests.swift in Sources`.
3. Append that build file to `TSTSRC000000000000000001 /* Sources */`.
```

- [ ] **Step 2: Run the focused provider tests and confirm they fail**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/FinderSelectionPathProviderTests
```

Expected:

```text
FAIL because `AppleScriptFinderSelectionPathProvider` and `FileDetector.DetectError: Equatable` do not exist yet.
```

- [ ] **Step 3: Implement the provider abstraction inside `FileDetector.swift`**

Update `QuickCookies/Core/FileDetector.swift` so it contains:

```swift
import Foundation
import AppKit

protocol FinderSelectionPathProviding {
    func selectedPath() -> Result<String, FileDetector.DetectError>
}

struct AppleScriptFinderSelectionPathProvider: FinderSelectionPathProviding {
    let isFinderRunning: () -> Bool
    let selectionScriptFactory: () -> NSAppleScript?
    let executeScript: (NSAppleScript) -> Result<String, FileDetector.DetectError>

    init(
        isFinderRunning: @escaping () -> Bool = FileDetector.isFinderRunningLive,
        selectionScriptFactory: @escaping () -> NSAppleScript? = { FileDetector.finderSelectionScript },
        executeScript: @escaping (NSAppleScript) -> Result<String, FileDetector.DetectError> = FileDetector.executeSelectionScript
    ) {
        self.isFinderRunning = isFinderRunning
        self.selectionScriptFactory = selectionScriptFactory
        self.executeScript = executeScript
    }

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        guard isFinderRunning() else {
            return .failure(.finderNotRunning)
        }

        guard let script = selectionScriptFactory() else {
            return .failure(.scriptingBridgeError("无法初始化 AppleScript 脚本"))
        }

        return executeScript(script)
    }
}

enum FileDetector {
    enum DetectError: Error, LocalizedError, Equatable {
        case finderNotRunning
        case noFileSelected
        case scriptingBridgeError(String)

        var errorDescription: String? {
            switch self {
            case .finderNotRunning:
                return "请先打开 Finder"
            case .noFileSelected:
                return "未检测到选中文件 (Finder selection为空)"
            case .scriptingBridgeError(let message):
                return "调试诊断: \\(message)"
            }
        }
    }

    static var liveFinderSelectionPathProvider: any FinderSelectionPathProviding {
        AppleScriptFinderSelectionPathProvider()
    }

    static func getSelectedFilePath() -> Result<String, DetectError> {
        liveFinderSelectionPathProvider.selectedPath()
    }

    static func executeSelectionScript(_ script: NSAppleScript) -> Result<String, DetectError> {
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error = error {
            let errorMsg = error["NSAppleScriptErrorMessage"] as? String ?? "未知 AppleScript 错误"
            return .failure(.scriptingBridgeError(errorMsg))
        }

        let path = descriptor.stringValue ?? ""
        if path.isEmpty {
            return .failure(.noFileSelected)
        }

        return .success(path)
    }

    static func isFinderRunningLive() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier == "com.apple.finder"
        }
    }

    private static let finderSelectionScript: NSAppleScript? = {
        let scriptText = """
        tell application "Finder"
            set theSelection to selection
            if theSelection is not {} then
                try
                    return POSIX path of (item 1 of theSelection as alias)
                on error
                    return ""
                end try
            else
                if (count of Finder windows) > 0 then
                    try
                        return POSIX path of (target of window 1 as alias)
                    on error
                        return ""
                    end try
                end if
            end if
        end tell
        """
        return NSAppleScript(source: scriptText)
    }()
}
```

- [ ] **Step 4: Re-run the focused provider tests**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/FinderSelectionPathProviderTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 5: Commit the provider abstraction**

Run:

```bash
git add QuickCookies/Core/FileDetector.swift QuickCookiesTests/FinderSelectionPathProviderTests.swift QuickCookies.xcodeproj/project.pbxproj
git commit -m "refactor(finder): extract selection path provider" -m "Introduce a Finder selection path provider abstraction, keep FileDetector as a compatibility shell, and add provider-level XCTest coverage."
```

## Task 2: Migrate `PreviewTargetResolver` To Provider Injection

**Files:**
- Modify: `QuickCookies/Core/Preview/PreviewTargetResolver.swift`
- Modify: `QuickCookiesTests/PreviewTargetTests.swift`
- Modify: `QuickCookiesTests/PreviewCoordinatorTests.swift`

- [ ] **Step 1: Update the resolver-related tests to the new provider API**

In both `QuickCookiesTests/PreviewTargetTests.swift` and `QuickCookiesTests/PreviewCoordinatorTests.swift`, add a local stub and replace the old closure-based initializer:

```swift
private struct StubFinderSelectionPathProvider: FinderSelectionPathProviding {
    let result: Result<String, FileDetector.DetectError>

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        result
    }
}
```

Replace examples like:

```swift
let resolver = PreviewTargetResolver(
    finderSelectionProvider: { nil }
)
```

with:

```swift
let resolver = PreviewTargetResolver(
    finderSelectionPathProvider: StubFinderSelectionPathProvider(
        result: .failure(.noFileSelected)
    )
)
```

Replace success cases like:

```swift
PreviewTargetResolver(finderSelectionProvider: { fileURL.path })
```

with:

```swift
PreviewTargetResolver(
    finderSelectionPathProvider: StubFinderSelectionPathProvider(
        result: .success(fileURL.path)
    )
)
```

- [ ] **Step 2: Run the focused resolver/coordinator suites and confirm they fail**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewTargetTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewCoordinatorTests
```

Expected:

```text
FAIL because `PreviewTargetResolver` still expects the old `finderSelectionProvider: () -> String?` initializer.
```

- [ ] **Step 3: Change `PreviewTargetResolver` to depend on the provider**

Update `QuickCookies/Core/Preview/PreviewTargetResolver.swift` to:

```swift
import Foundation

struct PreviewTargetResolver {
    let finderSelectionPathProvider: any FinderSelectionPathProviding

    init(
        finderSelectionPathProvider: any FinderSelectionPathProviding = AppleScriptFinderSelectionPathProvider()
    ) {
        self.finderSelectionPathProvider = finderSelectionPathProvider
    }

    func resolve(request: PreviewLaunchRequest) throws -> PreviewTarget {
        let originalPath: String

        switch request.pathIntent {
        case .direct(let path):
            originalPath = path
        case .finderSelection:
            switch finderSelectionPathProvider.selectedPath() {
            case .success(let selectedPath):
                originalPath = selectedPath
            case .failure:
                throw PreviewTargetError.noFinderSelection
            }
        }

        let resolvedPath = FileUtils.resolveSymlink(at: originalPath)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) else {
            throw PreviewTargetError.fileNotFound
        }

        if isDirectory.boolValue {
            return PreviewTarget(
                originalPath: originalPath,
                resolvedPath: resolvedPath,
                renderType: .unsupported,
                language: nil,
                displayName: URL(fileURLWithPath: resolvedPath).lastPathComponent
            )
        }

        let renderType = FileTypeClassifier.classify(path: resolvedPath)
        return PreviewTarget(
            originalPath: originalPath,
            resolvedPath: resolvedPath,
            renderType: renderType,
            language: FileTypeClassifier.getLanguageName(path: resolvedPath),
            displayName: URL(fileURLWithPath: resolvedPath).lastPathComponent
        )
    }
}
```

- [ ] **Step 4: Re-run the focused resolver/coordinator suites**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewTargetTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewCoordinatorTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 5: Commit the resolver migration**

Run:

```bash
git add QuickCookies/Core/Preview/PreviewTargetResolver.swift QuickCookiesTests/PreviewTargetTests.swift QuickCookiesTests/PreviewCoordinatorTests.swift
git commit -m "refactor(preview): inject finder selection provider" -m "Move PreviewTargetResolver off FileDetector static calls and update resolver/coordinator tests to use a stub provider."
```

## Task 3: Migrate `FinderMenuIntegration` And `AppDelegate`

**Files:**
- Modify: `QuickCookies/Core/FinderMenuIntegration.swift`
- Modify: `QuickCookies/App/AppDelegate.swift`
- Create: `QuickCookiesTests/FinderMenuIntegrationTests.swift`
- Modify: `QuickCookies.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add failing menu integration tests and wire them into the test target**

Create `QuickCookiesTests/FinderMenuIntegrationTests.swift` with:

```swift
import XCTest
@testable import QuickCookies

private struct StubFinderSelectionPathProvider: FinderSelectionPathProviding {
    let result: Result<String, FileDetector.DetectError>

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        result
    }
}

final class FinderMenuIntegrationTests: XCTestCase {
    func test_resolveOpenSelectedFileRequest_returnsMenuBarOpenRequestWhenProviderSucceeds() {
        let integration = FinderMenuIntegration(
            openSelectedFile: {},
            showSettings: {},
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .success("/tmp/demo.md")
            )
        )

        XCTAssertEqual(
            integration.resolveOpenSelectedFileRequest(),
            .request(.openPath("/tmp/demo.md", source: .menuBar))
        )
    }

    func test_resolveOpenSelectedFileRequest_returnsLocalizedFailureWhenProviderFails() {
        let error = FileDetector.DetectError.finderNotRunning
        let integration = FinderMenuIntegration(
            openSelectedFile: {},
            showSettings: {},
            finderSelectionPathProvider: StubFinderSelectionPathProvider(
                result: .failure(error)
            )
        )

        guard case let .failure(message, icon) = integration.resolveOpenSelectedFileRequest() else {
            return XCTFail("Expected failure outcome")
        }

        XCTAssertEqual(message, (error.errorDescription ?? "未知错误").localized())
        XCTAssertEqual(icon, "xmark.circle")
    }
}
```

Add the new test file to `QuickCookies.xcodeproj/project.pbxproj` using the same three edits as Task 1:

```text
1. New `PBXFileReference` under the `QuickCookiesTests` group.
2. New `PBXBuildFile` for `FinderMenuIntegrationTests.swift in Sources`.
3. Append the build file to `TSTSRC000000000000000001 /* Sources */`.
```

- [ ] **Step 2: Run the focused menu integration suite and confirm it fails**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/FinderMenuIntegrationTests
```

Expected:

```text
FAIL because `FinderMenuIntegration` still exposes only the static resolver and has no injectable provider.
```

- [ ] **Step 3: Convert `FinderMenuIntegration` to instance-based provider injection**

Update `QuickCookies/Core/FinderMenuIntegration.swift` to:

```swift
import Foundation
import AppKit
import SwiftUI

struct FinderMenuIntegration {
    enum OpenSelectedFileOutcome: Equatable {
        case request(PreviewLaunchRequest)
        case failure(message: String, icon: String?)
    }

    let openSelectedFile: () -> Void
    let showSettings: () -> Void
    let finderSelectionPathProvider: any FinderSelectionPathProviding

    init(
        openSelectedFile: @escaping () -> Void,
        showSettings: @escaping () -> Void,
        finderSelectionPathProvider: any FinderSelectionPathProviding = AppleScriptFinderSelectionPathProvider()
    ) {
        self.openSelectedFile = openSelectedFile
        self.showSettings = showSettings
        self.finderSelectionPathProvider = finderSelectionPathProvider
    }

    func resolveOpenSelectedFileRequest() -> OpenSelectedFileOutcome {
        switch finderSelectionPathProvider.selectedPath() {
        case .success(let path):
            return .request(.openPath(path, source: .menuBar))
        case .failure(let error):
            let message = (error.errorDescription ?? "未知错误").localized()
            return .failure(message: message, icon: "xmark.circle")
        }
    }

    @ViewBuilder
    func menuBarMenu() -> some View {
        Button(action: openSelectedFile) {
            Label("Open Selected File".localized(), image: "MenuOpen")
        }
        .help("Double-press Option or click here to open the selected Finder file".localized())

        Divider()

        Button(action: showSettings) {
            Label("Settings".localized(), image: "MenuSettings")
        }

        Divider()

        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("Quit".localized(), image: "MenuQuit")
        }
    }
}
```

- [ ] **Step 4: Inject the shared live provider from `AppDelegate`**

Update `QuickCookies/App/AppDelegate.swift` so the app owns one shared provider and uses the instance method:

```swift
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let finderSelectionPathProvider: any FinderSelectionPathProviding = AppleScriptFinderSelectionPathProvider()
    private var onboardingWindow: NSWindow?
    private var didSetupNormalFlow = false
    private var notificationObservers: [NSObjectProtocol] = []
    private let previewSession = PreviewSession()
    private let previewPresenter = PreviewUIPresenter.live
    private let previewRequestController = PreviewRequestController()
    private lazy var previewCoordinator = PreviewCoordinator(
        session: previewSession,
        resolver: PreviewTargetResolver(
            finderSelectionPathProvider: finderSelectionPathProvider
        )
    )
    lazy var finderMenuIntegration = FinderMenuIntegration(
        openSelectedFile: { [weak self] in
            self?.openSelectedFileFromMenuBar()
        },
        showSettings: {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show()
            }
        },
        finderSelectionPathProvider: finderSelectionPathProvider
    )

    @MainActor
    private func openSelectedFileFromMenuBar() {
        switch finderMenuIntegration.resolveOpenSelectedFileRequest() {
        case .request(let request):
            previewRequestController.submit(request)
        case .failure(let message, let icon):
            previewPresenter.showToast(message: message, icon: icon)
        }
    }
}
```

- [ ] **Step 5: Re-run the focused menu integration suite**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/FinderMenuIntegrationTests
```

Expected:

```text
TEST SUCCEEDED
```

- [ ] **Step 6: Commit the menu/app migration**

Run:

```bash
git add QuickCookies/Core/FinderMenuIntegration.swift QuickCookies/App/AppDelegate.swift QuickCookiesTests/FinderMenuIntegrationTests.swift QuickCookies.xcodeproj/project.pbxproj
git commit -m "refactor(app): share finder selection provider" -m "Inject the live finder selection provider into menu bar flows and replace the static menu integration resolver with an instance-based API."
```

## Task 4: Migrate Overlay Polling Source, Update Docs, And Verify End-To-End

**Files:**
- Modify: `QuickCookies/UI/QuickLookOverlay.swift`
- Modify: `docs/xctest-feasibility.md`
- Test: `QuickCookiesTests/PreviewLaunchRequestTests.swift`
- Test: `QuickCookiesTests/QuickLookOverlayStateTests.swift`

- [ ] **Step 1: Re-run the existing overlay/request suites as a baseline**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests
./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests
```

Expected:

```text
TEST SUCCEEDED before wiring changes, confirming current Finder-follow behavior is stable.
```

- [ ] **Step 2: Route `QuickLookOverlay` selection polling through the provider**

Update `QuickCookies/UI/QuickLookOverlay.swift` so it owns an injectable provider and stops referencing `FileDetector` directly:

```swift
class QuickLookOverlay: NSObject, NSWindowDelegate {
    static let shared = QuickLookOverlay()

    var finderSelectionPathProvider: any FinderSelectionPathProviding = AppleScriptFinderSelectionPathProvider()

    private lazy var finderSelectionPollingController = FinderSelectionPollingController(
        timerFactory: { interval, tick in
            PollingBridgeTimer(interval: interval, tick: tick)
        },
        frontmostBundleIdentifier: {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        detectSelectionPath: { [weak self] in
            let provider = self?.finderSelectionPathProvider ?? AppleScriptFinderSelectionPathProvider()
            return provider.selectedPath().mapError { $0 as any Error }
        },
        detectSourceRect: {
            Self.getSourceRect()
        },
        onRequest: { [weak self] request in
            self?.dispatchFinderSelectionRequest(request)
        },
        onSourceRectUpdate: { [weak self] rect in
            self?.sourceRectBackup = rect
        },
        runAsync: { work in
            DispatchQueue.global(qos: .userInteractive).async(execute: work)
        },
        deliverOnMain: { work in
            DispatchQueue.main.async(execute: work)
        }
    )
}
```

In `QuickCookies/App/AppDelegate.swift`, add provider injection during normal setup:

```swift
private func setupNormalFlow() {
    guard !didSetupNormalFlow else { return }
    didSetupNormalFlow = true

    QuickLookOverlay.shared.finderSelectionPathProvider = finderSelectionPathProvider
    NSApp.setActivationPolicy(.accessory)
    ...
}
```

- [ ] **Step 3: Update the XCTest feasibility note**

Replace the current `docs/xctest-feasibility.md` section about `FileDetector` not being directly suitable for stable tests with wording like:

```markdown
### 5.1 `FileDetector`

`FileDetector` 作为直接系统集成入口仍然不适合做依赖真实 Finder 状态的集成单测。

但在引入 `FinderSelectionPathProviding` 与 `AppleScriptFinderSelectionPathProvider` 之后，
Finder 路径发现的错误分支已经可以通过注入 `isFinderRunning`、`selectionScriptFactory`
和 `executeScript` 做稳定单元测试。

结论：

- 不测真实 Finder / AppleScript 环境
- 测 provider 层纯逻辑和调用方注入行为
```

- [ ] **Step 4: Re-run all focused suites touched by this refactor**

Run:

```bash
./scripts/run-focused-xctest.sh QuickCookiesTests/FinderSelectionPathProviderTests
./scripts/run-focused-xctest.sh QuickCookiesTests/FinderMenuIntegrationTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewTargetTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewCoordinatorTests
./scripts/run-focused-xctest.sh QuickCookiesTests/PreviewLaunchRequestTests
./scripts/run-focused-xctest.sh QuickCookiesTests/QuickLookOverlayStateTests
```

Expected:

```text
All focused suites pass, and there is no regression in Finder-driven scoped polling or direct-path behavior.
```

- [ ] **Step 5: Run the full verification set**

Run:

```bash
git diff --check
xcodebuild test -project QuickCookies.xcodeproj -scheme QuickCookies -destination 'platform=macOS' -derivedDataPath build/xctest-derived/finder-selection-path-provider
```

Expected:

```text
No whitespace errors.
TEST SUCCEEDED
```

- [ ] **Step 6: Commit the overlay/doc verification pass**

Run:

```bash
git add QuickCookies/UI/QuickLookOverlay.swift docs/xctest-feasibility.md
git commit -m "test(finder): cover injected path discovery" -m "Route overlay polling through the injected finder selection provider and document the new FileDetector testability boundary."
```
