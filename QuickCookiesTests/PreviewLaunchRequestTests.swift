import XCTest
@testable import QuickCookies

private final class PollingTimerSpy: FinderSelectionPollingTimer {
    private(set) var invalidateCallCount = 0
    private let tick: () -> Void

    init(tick: @escaping () -> Void = {}) {
        self.tick = tick
    }

    func invalidate() {
        invalidateCallCount += 1
    }

    func fire() {
        tick()
    }
}

final class PreviewLaunchRequestTests: XCTestCase {
    func test_directPathOpenRequest_preservesPathAndSource() {
        let request = PreviewLaunchRequest.openPath(
            "/tmp/demo.md",
            source: .service
        )

        XCTAssertEqual(request.source, .service)
        XCTAssertEqual(request.pathIntent, .direct(path: "/tmp/demo.md"))
        XCTAssertEqual(request.presentation, .open)
    }

    func test_internalNavigationOpenRequest_usesDirectPathWithoutFinderSelectionIntent() {
        let request = PreviewLaunchRequest.openPath(
            "/tmp/next.md",
            source: .internalNavigation
        )

        XCTAssertEqual(request.source, .internalNavigation)
        XCTAssertEqual(request.pathIntent, .direct(path: "/tmp/next.md"))
        XCTAssertEqual(request.presentation, .open)
    }

    func test_finderToggleRequest_usesFinderSelectionIntent() {
        let request = PreviewLaunchRequest.toggleFromFinderHotkey()

        XCTAssertEqual(request.source, .hotkey)
        XCTAssertEqual(request.pathIntent, .finderSelection)
        XCTAssertEqual(request.presentation, .toggle)
    }

    func test_openURLStyleFlow_buildsDirectPathRequest() {
        let request = PreviewLaunchRequest.openPath(
            "/tmp/from-url.md",
            source: .urlScheme
        )

        XCTAssertEqual(request.source, .urlScheme)
        XCTAssertEqual(request.presentation, .open)
    }

    func test_refreshFinderSelectionRequest_usesFinderSelectionOpenIntent() {
        let request = PreviewLaunchRequest.refreshFinderSelection()

        XCTAssertEqual(request.source, .finderSync)
        XCTAssertEqual(request.pathIntent, .finderSelection)
        XCTAssertEqual(request.presentation, .open)
    }

    func test_finderSelectionRefresh_noSelectionAfterExistingPath_treatsAsTransientNoChange() {
        let decision = FinderSelectionRefresh.decide(
            previousSelectionPath: "/tmp/demo.md",
            detectedSelectionPath: nil
        )

        XCTAssertEqual(decision, .noChange)
    }

    func test_finderSelectionRefresh_changedPath_requestsDirectOpenPath() {
        let decision = FinderSelectionRefresh.decide(
            previousSelectionPath: "/tmp/old.md",
            detectedSelectionPath: "/tmp/new.md"
        )

        XCTAssertEqual(
            decision,
            .request(.openPath("/tmp/new.md", source: .finderSync))
        )
    }

    func test_finderSelectionRefresh_samePath_returnsNoChange() {
        let decision = FinderSelectionRefresh.decide(
            previousSelectionPath: "/tmp/demo.md",
            detectedSelectionPath: "/tmp/demo.md"
        )

        XCTAssertEqual(decision, .noChange)
    }

    func test_triggerPolicy_whenOverlayVisible_prefersCloseAction() {
        let action = PreviewTriggerPolicy.actionForFinderToggle(
            isOverlayVisible: true,
            frontmostBundleIdentifier: "com.apple.finder"
        )

        XCTAssertEqual(action, .closeVisibleOverlay)
    }

    func test_triggerPolicy_whenFinderForeground_requestsToggleLaunch() {
        let action = PreviewTriggerPolicy.actionForFinderToggle(
            isOverlayVisible: false,
            frontmostBundleIdentifier: "com.apple.finder"
        )

        XCTAssertEqual(action, .send(.toggleFromFinderHotkey()))
    }

    func test_finderSelectionMonitor_ignoresPollingOutsideFinder() {
        let monitor = FinderSelectionMonitor()
        var capturedRequest: PreviewLaunchRequest?
        var didUpdateSourceRect = false

        monitor.refreshIfFinderFrontmost(
            frontmostBundleIdentifier: "com.apple.TextEdit",
            runAsync: { work in work() },
            deliverOnMain: { work in work() },
            detectSelectionPath: { () -> Result<String, NSError> in
                XCTFail("polling outside Finder should not probe selection")
                return .failure(NSError(domain: "test", code: 1))
            },
            detectSourceRect: {
                XCTFail("polling outside Finder should not probe source rect")
                return .zero
            },
            onRequest: { request in
                capturedRequest = request
            },
            onSourceRectUpdate: { _ in
                didUpdateSourceRect = true
            }
        )

        XCTAssertNil(capturedRequest)
        XCTAssertFalse(didUpdateSourceRect)
    }

    func test_finderSelectionMonitor_allowsEventDrivenRefreshWhenFrontmostAppIsUnknown() {
        let monitor = FinderSelectionMonitor()
        var capturedRequest: PreviewLaunchRequest?

        monitor.setCurrentResolvedPath("/tmp/old.md")
        monitor.refreshIfFinderFrontmost(
            frontmostBundleIdentifier: nil,
            allowsUnknownFrontmost: true,
            runAsync: { work in work() },
            deliverOnMain: { work in work() },
            detectSelectionPath: { () -> Result<String, NSError> in
                .success("/tmp/new.md")
            },
            detectSourceRect: {
                .zero
            },
            onRequest: { request in
                capturedRequest = request
            },
            onSourceRectUpdate: { _ in }
        )

        XCTAssertEqual(capturedRequest, .openPath("/tmp/new.md", source: .finderSync))
    }

    func test_finderSelectionMonitor_allowsEventDrivenRefreshForExplicitFrontmostFallback() {
        let monitor = FinderSelectionMonitor()
        var capturedRequest: PreviewLaunchRequest?

        monitor.setCurrentResolvedPath("/tmp/old.md")
        monitor.refreshIfFinderFrontmost(
            frontmostBundleIdentifier: "com.quickcookies.app",
            additionalAllowedFrontmostBundleIdentifiers: ["com.quickcookies.app"],
            runAsync: { work in work() },
            deliverOnMain: { work in work() },
            detectSelectionPath: { () -> Result<String, NSError> in
                .success("/tmp/new.md")
            },
            detectSourceRect: {
                .zero
            },
            onRequest: { request in
                capturedRequest = request
            },
            onSourceRectUpdate: { _ in }
        )

        XCTAssertEqual(capturedRequest, .openPath("/tmp/new.md", source: .finderSync))
    }

    func test_finderSelectionMonitor_dispatchesOpenRequestAndTracksResolvedPath() {
        let monitor = FinderSelectionMonitor()
        let sourceRect = CGRect(x: 10, y: 20, width: 30, height: 40)
        var capturedRequest: PreviewLaunchRequest?
        var capturedSourceRect: CGRect?

        monitor.setCurrentResolvedPath("/tmp/old.md")
        monitor.refreshIfFinderFrontmost(
            frontmostBundleIdentifier: "com.apple.finder",
            runAsync: { work in work() },
            deliverOnMain: { work in work() },
            detectSelectionPath: { () -> Result<String, NSError> in
                .success("/tmp/new.md")
            },
            detectSourceRect: {
                sourceRect
            },
            onRequest: { request in
                capturedRequest = request
            },
            onSourceRectUpdate: { rect in
                capturedSourceRect = rect
            }
        )

        XCTAssertEqual(
            capturedRequest,
            .openPath("/tmp/new.md", source: .finderSync)
        )
        XCTAssertEqual(capturedSourceRect, sourceRect)
        XCTAssertEqual(monitor.lastObservedSelectionPath, "/tmp/new.md")
    }

    func test_finderSelectionPollingController_startIsIdempotentAndStopInvalidatesTimer() {
        var createdTimers: [PollingTimerSpy] = []
        let controller = FinderSelectionPollingController(
            timerFactory: { _, _ in
                let timer = PollingTimerSpy()
                createdTimers.append(timer)
                return timer
            },
            frontmostBundleIdentifier: { "com.apple.finder" },
            detectSelectionPath: { Result<String, any Error>.failure(NSError(domain: "test", code: 1)) },
            detectSourceRect: { .zero },
            onRequest: { _ in },
            onSourceRectUpdate: { _ in },
            runAsync: { work in work() },
            deliverOnMain: { work in work() }
        )

        controller.start()
        controller.start()
        controller.stop()

        XCTAssertEqual(createdTimers.count, 1)
        XCTAssertEqual(createdTimers.first?.invalidateCallCount, 1)
        XCTAssertFalse(controller.isRunning)
    }

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

    func test_finderSelectionPollingController_refreshDispatchesRequestThroughMonitor() {
        let sourceRect = CGRect(x: 5, y: 6, width: 7, height: 8)
        var capturedRequest: PreviewLaunchRequest?
        var capturedSourceRect: CGRect?
        let controller = FinderSelectionPollingController(
            timerFactory: { _, _ in PollingTimerSpy() },
            frontmostBundleIdentifier: { "com.apple.finder" },
            detectSelectionPath: { Result<String, any Error>.success("/tmp/next.md") },
            detectSourceRect: { sourceRect },
            onRequest: { request in
                capturedRequest = request
            },
            onSourceRectUpdate: { rect in
                capturedSourceRect = rect
            },
            runAsync: { work in work() },
            deliverOnMain: { work in work() }
        )

        controller.syncCurrentResolvedPath("/tmp/old.md")
        controller.refresh()

        XCTAssertEqual(
            capturedRequest,
            .openPath("/tmp/next.md", source: .finderSync)
        )
        XCTAssertEqual(capturedSourceRect, sourceRect)
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

    func test_finderSelectionPollingController_refreshBurstSchedulesDelayedRefreshesAndCatchesLateSelectionChange() {
        var scheduledDelays: [TimeInterval] = []
        var scheduledWork: [() -> Void] = []
        var detectedPaths = ["/tmp/old.md", "/tmp/new.md"]
        var capturedRequest: PreviewLaunchRequest?

        let controller = FinderSelectionPollingController(
            timerFactory: { _, _ in PollingTimerSpy() },
            frontmostBundleIdentifier: { "com.apple.finder" },
            detectSelectionPath: {
                Result<String, any Error>.success(detectedPaths.removeFirst())
            },
            detectSourceRect: { .zero },
            onRequest: { request in
                capturedRequest = request
            },
            onSourceRectUpdate: { _ in },
            runAsync: { work in work() },
            deliverOnMain: { work in work() }
        )

        controller.syncCurrentResolvedPath("/tmp/old.md")
        controller.refreshBurst(
            delays: [0.05, 0.15],
            schedule: { delay, work in
                scheduledDelays.append(delay)
                scheduledWork.append(work)
            }
        )

        XCTAssertEqual(scheduledDelays, [0.05, 0.15])

        scheduledWork[0]()
        XCTAssertNil(capturedRequest)

        scheduledWork[1]()
        XCTAssertEqual(capturedRequest, .openPath("/tmp/new.md", source: .finderSync))
    }

    @MainActor
    func test_requestController_openPath_dispatchesDirectOpenRequest() {
        let controller = PreviewRequestController()
        var capturedRequest: PreviewLaunchRequest?

        controller.onRequest = { (request: PreviewLaunchRequest) in
            capturedRequest = request
        }

        controller.openPath("/tmp/demo.md", source: PreviewLaunchSource.menuBar)

        XCTAssertEqual(
            capturedRequest,
            .openPath("/tmp/demo.md", source: .menuBar)
        )
    }

    @MainActor
    func test_requestController_toggleFromFinder_preparesSourceRectBeforeDispatch() {
        let controller = PreviewRequestController()
        var capturedRequest: PreviewLaunchRequest?
        var didPrepareSourceRect = false

        controller.onRequest = { (request: PreviewLaunchRequest) in
            capturedRequest = request
            XCTAssertTrue(didPrepareSourceRect)
        }

        controller.toggleFromFinder(
            isOverlayVisible: false,
            frontmostBundleIdentifier: "com.apple.finder",
            prepareSourceRect: {
                didPrepareSourceRect = true
            },
            closeOverlay: {
                XCTFail("toggleFromFinder should not close overlay when it is hidden")
            }
        )

        XCTAssertTrue(didPrepareSourceRect)
        XCTAssertEqual(capturedRequest, .toggleFromFinderHotkey())
    }

    @MainActor
    func test_previewCommandRouter_dispatchesToggleThroughPresenterAndController() {
        let controller = PreviewRequestController()
        var capturedRequest: PreviewLaunchRequest?
        var didPrepareSourceRect = false
        var didCloseOverlay = false

        controller.onRequest = { request in
            capturedRequest = request
            XCTAssertTrue(didPrepareSourceRect)
        }

        let presenter = PreviewUIPresenter(
            isPreviewVisibleProvider: { false },
            captureFinderSourceRectAction: {
                didPrepareSourceRect = true
            },
            closePreviewWithAnimationAction: {
                didCloseOverlay = true
            },
            closePreviewAction: {},
            presentPreviewAction: { _ in },
            setFinderSelectionRequestHandlerAction: { _ in },
            showToastAction: { _, _ in },
            refreshPreviewAppearanceAction: {},
            refreshSettingsAppearanceAction: {},
            refreshSettingsTitleAction: {}
        )

        PreviewCommandRouter.triggerFinderToggle(
            requestController: controller,
            presenter: presenter,
            frontmostBundleIdentifierProvider: { "com.apple.finder" }
        )

        XCTAssertEqual(capturedRequest, .toggleFromFinderHotkey())
        XCTAssertTrue(didPrepareSourceRect)
        XCTAssertFalse(didCloseOverlay)
    }

    @MainActor
    func test_previewCommandRouter_closesVisiblePreviewWithoutDispatchingRequest() {
        let controller = PreviewRequestController()
        var capturedRequest: PreviewLaunchRequest?
        var didPrepareSourceRect = false
        var didCloseOverlay = false

        controller.onRequest = { request in
            capturedRequest = request
        }

        let presenter = PreviewUIPresenter(
            isPreviewVisibleProvider: { true },
            captureFinderSourceRectAction: {
                didPrepareSourceRect = true
            },
            closePreviewWithAnimationAction: {
                didCloseOverlay = true
            },
            closePreviewAction: {},
            presentPreviewAction: { _ in },
            setFinderSelectionRequestHandlerAction: { _ in },
            showToastAction: { _, _ in },
            refreshPreviewAppearanceAction: {},
            refreshSettingsAppearanceAction: {},
            refreshSettingsTitleAction: {}
        )

        PreviewCommandRouter.triggerFinderToggle(
            requestController: controller,
            presenter: presenter,
            frontmostBundleIdentifierProvider: { "com.apple.finder" }
        )

        XCTAssertNil(capturedRequest)
        XCTAssertFalse(didPrepareSourceRect)
        XCTAssertTrue(didCloseOverlay)
    }
}
