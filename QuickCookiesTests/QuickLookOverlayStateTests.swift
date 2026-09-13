import XCTest
import SwiftUI
@testable import QuickCookies

private final class StubFinderSelectionPathProvider: FinderSelectionPathProviding {
    var selectedPathCalls = 0
    var result: Result<String, FileDetector.DetectError>

    init(result: Result<String, FileDetector.DetectError>) {
        self.result = result
    }

    func selectedPath() -> Result<String, FileDetector.DetectError> {
        selectedPathCalls += 1
        return result
    }
}

@MainActor
final class QuickLookOverlayStateTests: XCTestCase {
    func test_quickLookOverlayPollingSelectionPathResult_usesInjectedFinderSelectionPathProvider() {
        let overlay = QuickLookOverlay.shared
        let originalProvider = overlay.finderSelectionPathProvider
        let stubProvider = StubFinderSelectionPathProvider(result: .success("/tmp/injected-from-overlay.md"))
        overlay.finderSelectionPathProvider = stubProvider
        defer {
            overlay.finderSelectionPathProvider = originalProvider
        }

        let result = overlay.finderSelectionPollingSelectionPathResult()

        XCTAssertEqual(try? result.get(), "/tmp/injected-from-overlay.md")
        XCTAssertEqual(stubProvider.selectedPathCalls, 1)
    }

    func test_appDelegateInstallFinderSelectionPathProviderOnOverlay_routesOverlayPollingThroughSharedProvider() {
        let overlay = QuickLookOverlay.shared
        let originalProvider = overlay.finderSelectionPathProvider
        let stubProvider = StubFinderSelectionPathProvider(result: .success("/tmp/injected-from-app-delegate.md"))
        let appDelegate = AppDelegate(finderSelectionPathProvider: stubProvider)
        defer {
            overlay.finderSelectionPathProvider = originalProvider
        }

        appDelegate.installFinderSelectionPathProvider(on: overlay)
        let result = overlay.finderSelectionPollingSelectionPathResult()

        XCTAssertEqual(try? result.get(), "/tmp/injected-from-app-delegate.md")
        XCTAssertEqual(stubProvider.selectedPathCalls, 1)
    }

    func test_appDelegateShared_isConfiguredAndAccessible() {
        let stubProvider = StubFinderSelectionPathProvider(result: .success("/tmp/test.md"))
        let appDelegate = AppDelegate(finderSelectionPathProvider: stubProvider)
        XCTAssertTrue(AppDelegate.shared === appDelegate)
    }

    func test_appDelegateShowOnboarding_createsWindowAndSupportsReopen() {
        let stubProvider = StubFinderSelectionPathProvider(result: .success("/tmp/test.md"))
        let appDelegate = AppDelegate(finderSelectionPathProvider: stubProvider)
        defer {
            appDelegate.currentOnboardingWindow?.close()
        }

        XCTAssertNil(appDelegate.currentOnboardingWindow)
        appDelegate.showOnboarding()
        let initialWindow = appDelegate.currentOnboardingWindow
        XCTAssertNotNil(initialWindow)

        // Calling showOnboarding with reopen: true recreates a fresh window instance
        appDelegate.showOnboarding(reopen: true)
        let reopenedWindow = appDelegate.currentOnboardingWindow
        XCTAssertNotNil(reopenedWindow)
        XCTAssertFalse(initialWindow === reopenedWindow)
    }

    func test_previewUIPresenter_forwardsInjectedUIActions() {
        var didCaptureSourceRect = false
        var didCloseWithAnimation = false
        var didCloseImmediately = false
        var presentedSession: PreviewSession?
        var finderSelectionHandler: ((PreviewLaunchRequest) -> Void)?
        var toastPayload: (String, String?)?
        var appearanceRefreshCount = 0
        var titleRefreshCount = 0
        let session = PreviewSession()

        let presenter = PreviewUIPresenter(
            isPreviewVisibleProvider: { true },
            captureFinderSourceRectAction: {
                didCaptureSourceRect = true
            },
            closePreviewWithAnimationAction: {
                didCloseWithAnimation = true
            },
            closePreviewAction: {
                didCloseImmediately = true
            },
            presentPreviewAction: { incomingSession in
                presentedSession = incomingSession
            },
            setFinderSelectionRequestHandlerAction: { handler in
                finderSelectionHandler = handler
            },
            showToastAction: { message, icon in
                toastPayload = (message, icon)
            },
            refreshPreviewAppearanceAction: {
                appearanceRefreshCount += 1
            },
            refreshSettingsAppearanceAction: {
                appearanceRefreshCount += 1
            },
            refreshSettingsTitleAction: {
                titleRefreshCount += 1
            }
        )

        XCTAssertTrue(presenter.isPreviewVisible)

        presenter.captureFinderSourceRect()
        presenter.closePreviewWithAnimation()
        presenter.closePreview()
        presenter.present(session: session)
        presenter.setFinderSelectionRequestHandler { _ in }
        presenter.showToast(message: "demo", icon: "checkmark")
        presenter.refreshWindowAppearance()
        presenter.refreshLocalizedTitles()

        XCTAssertTrue(didCaptureSourceRect)
        XCTAssertTrue(didCloseWithAnimation)
        XCTAssertTrue(didCloseImmediately)
        XCTAssertTrue(presentedSession === session)
        XCTAssertNotNil(finderSelectionHandler)
        XCTAssertEqual(toastPayload?.0, "demo")
        XCTAssertEqual(toastPayload?.1, "checkmark")
        XCTAssertEqual(appearanceRefreshCount, 2)
        XCTAssertEqual(titleRefreshCount, 1)
    }

    func test_quickLookPanel_usesInjectedKeyWindowProvider() {
        let panel = QuickLookPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.canBecomeKeyProvider = { false }
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)

        panel.canBecomeKeyProvider = { true }
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.canBecomeMain)
    }

    func test_previewWindowActions_performInjectedCallbacks() {
        var didClose = false
        var toastPayload: (String, String?)?
        var searchStateReceived: Bool?
        let expectedWindow = NSWindow()

        let actions = PreviewWindowActions(
            closeOverlay: {
                didClose = true
            },
            showToast: { message, icon in
                toastPayload = (message, icon)
            },
            currentWindow: {
                expectedWindow
            },
            onSearchStateChanged: { isSearching in
                searchStateReceived = isSearching
            }
        )

        actions.closeOverlay()
        actions.showToast("Saved", "checkmark.circle.fill")
        actions.onSearchStateChanged?(true)

        XCTAssertTrue(didClose)
        XCTAssertEqual(toastPayload?.0, "Saved")
        XCTAssertEqual(toastPayload?.1, "checkmark.circle.fill")
        XCTAssertEqual(searchStateReceived, true)
        XCTAssertIdentical(actions.currentWindow(), expectedWindow)
    }

    func test_previewReadinessGate_resetsHeavyPreviewToPendingWithFreshToken() {
        let state = PreviewReadinessGate.resetState(
            for: .office,
            tokenFactory: { UUID(uuidString: "11111111-1111-1111-1111-111111111111")! }
        )

        XCTAssertFalse(state.isReady)
        XCTAssertEqual(
            state.token,
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        )
    }

    func test_previewReadinessGate_keepsNonHeavyPreviewReadyImmediately() {
        let state = PreviewReadinessGate.resetState(
            for: .markdown,
            tokenFactory: { UUID(uuidString: "22222222-2222-2222-2222-222222222222")! }
        )

        XCTAssertTrue(state.isReady)
        XCTAssertEqual(
            state.token,
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        )
    }

    func test_previewReadinessGate_acceptsMatchingTokenOnlyOnce() {
        let initial = PreviewReadinessGate.resetState(
            for: .pdf,
            tokenFactory: { UUID(uuidString: "33333333-3333-3333-3333-333333333333")! }
        )

        let readyState = PreviewReadinessGate.acceptingReady(
            from: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            current: initial
        )
        let duplicateReadyState = PreviewReadinessGate.acceptingReady(
            from: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            current: readyState ?? initial
        )

        XCTAssertEqual(readyState?.token, initial.token)
        XCTAssertTrue(readyState?.isReady == true)
        XCTAssertNil(duplicateReadyState)
    }

    func test_previewReadinessGate_rejectsStaleToken() {
        let current = PreviewReadinessGate.resetState(
            for: .image,
            tokenFactory: { UUID(uuidString: "44444444-4444-4444-4444-444444444444")! }
        )

        let staleReadyState = PreviewReadinessGate.acceptingReady(
            from: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            current: current
        )

        XCTAssertNil(staleReadyState)
    }

    func test_previewPlaceholderPolicy_usesUnifiedLoadingCopyForGatedMediaPreviewTypes() {
        XCTAssertEqual(
            PreviewPlaceholderPolicy.subtitle(for: .image),
            "Loading content...".localized()
        )
        XCTAssertEqual(
            PreviewPlaceholderPolicy.subtitle(for: .pdf),
            "Loading content...".localized()
        )
    }

    func test_heavyPreviewVisibilityPolicy_keepsOfficePreviewVisibleImmediately() {
        XCTAssertFalse(HeavyPreviewVisibilityPolicy.shouldGateVisibility(for: .office))
    }

    func test_heavyPreviewVisibilityPolicy_keepsImagePreviewVisibleImmediately() {
        XCTAssertFalse(HeavyPreviewVisibilityPolicy.shouldGateVisibility(for: .image))
    }

    func test_heavyPreviewVisibilityPolicy_gatesPdfUntilReady() {
        XCTAssertTrue(HeavyPreviewVisibilityPolicy.shouldGateVisibility(for: .pdf))
    }

    func test_previewOverlayKeyWindowPolicy_keepsFinderDrivenPreviewNonKey() {
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .office,
                source: .hotkey
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .markdown,
                source: .finderSync
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .image,
                source: .menuBar
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_allowsDirectPathPreviewInteraction() {
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .markdown,
                source: .service
            )
        )
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .image,
                source: .urlScheme
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: nil,
                source: .service
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_blocksFinderDrivenPreviews() {
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .code,
                source: .hotkey
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_allowsFinderDrivenPreviewWhenSearchIsActive() {
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .code,
                source: .hotkey,
                isSearchActive: true
            )
        )
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .image,
                source: .hotkey,
                isSearchActive: true
            )
        )
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: .markdown,
                source: .hotkey,
                isSearchActive: true
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                renderType: nil,
                source: .hotkey,
                isSearchActive: true
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_keepsFinderDrivenPreviewInFinder() {
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                renderType: .office,
                source: .hotkey
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                renderType: .markdown,
                source: .finderSync
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_focusesDirectPathPreviewOnPresentation() {
        XCTAssertTrue(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                renderType: .markdown,
                source: .service
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                renderType: nil,
                source: .service
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_doesNotActivateAppForFinderDrivenPreview() {
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
                renderType: .markdown,
                source: .hotkey
            )
        )
        XCTAssertTrue(
            PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
                renderType: .image,
                source: .service
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
                renderType: nil,
                source: .service
            )
        )
    }

    func test_previewOverlayKeyboardRoutingPolicy_doesNotForwardFinderNavigationByDefault() {
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
    }

    func test_previewOverlayWindowChromePolicy_usesSystemShadowForBorderlessWindow() {
        XCTAssertTrue(PreviewOverlayWindowChromePolicy.usesSystemWindowShadow)
    }

    func test_previewCardChromePolicy_usesRoundedContentBorderWithSystemWindowShadow() {
        XCTAssertEqual(PreviewCardChromePolicy.cornerRadius, 20)
        XCTAssertLessThanOrEqual(PreviewCardChromePolicy.borderLineWidth, 0.75)
        XCTAssertLessThanOrEqual(PreviewCardChromePolicy.lightBorderOpacity, 0.09)
        XCTAssertEqual(PreviewCardChromePolicy.lightBorderSource, .systemSeparator)
        XCTAssertLessThanOrEqual(PreviewCardChromePolicy.darkBorderOpacity, 0.28)
        XCTAssertTrue(PreviewOverlayWindowChromePolicy.usesSystemWindowShadow)
    }

    func test_previewCardChromePolicy_usesLightSingleStrokeWithoutSwiftUIOuterShadow() {
        XCTAssertEqual(PreviewCardChromePolicy.ambientShadowRadius, 0)
        XCTAssertEqual(PreviewCardChromePolicy.contactShadowRadius, 0)
        XCTAssertEqual(PreviewCardChromePolicy.innerHighlightLineWidth, 0.5)
        XCTAssertGreaterThan(PreviewCardChromePolicy.lightInnerHighlightOpacity, 0)
        XCTAssertGreaterThan(PreviewCardChromePolicy.darkInnerHighlightOpacity, 0)
        XCTAssertTrue(PreviewOverlayWindowChromePolicy.usesSystemWindowShadow)
    }

    func test_previewOverlayOpenAnimationPolicy_usesSingleLayerSpringPhysics() {
        XCTAssertTrue(PreviewOverlayOpenAnimationPolicy.masksRoundedContentAfterOpening)
        XCTAssertTrue(PreviewOverlayOpenAnimationPolicy.usesSpringAnimation)
        XCTAssertFalse(PreviewOverlayOpenAnimationPolicy.animatesRealPreviewWindowFrame)
        XCTAssertEqual(PreviewOverlayOpenAnimationPolicy.startScale, 0.92, accuracy: 0.001)
        XCTAssertGreaterThan(PreviewOverlayOpenAnimationPolicy.springDamping, 0)
        XCTAssertGreaterThan(PreviewOverlayOpenAnimationPolicy.springStiffness, 0)
        XCTAssertGreaterThan(PreviewOverlayOpenAnimationPolicy.springMass, 0)
        XCTAssertLessThanOrEqual(PreviewOverlayOpenAnimationPolicy.fadeInDuration, 0.20)
    }

    func test_previewOverlayCloseAnimationPolicy_usesFluidTimingAndSynchronousWindowAlpha() {
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.duration, 0.13, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.endScale, 0.94, accuracy: 0.001)
        XCTAssertTrue(PreviewOverlayCloseAnimationPolicy.animatesWindowAlpha)
        XCTAssertGreaterThan(PreviewOverlayCloseAnimationPolicy.controlPoint1.x, 0)
        XCTAssertGreaterThan(PreviewOverlayCloseAnimationPolicy.controlPoint2.y, 0)
    }

    func test_previewOverlayKeyboardRoutingPolicy_requiresFrontmostFinderWhenForwardingEnabled() {
        XCTAssertTrue(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                finderNavigationForwardingEnabled: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                finderNavigationForwardingEnabled: true,
                frontmostBundleIdentifier: "com.quickcookies.app",
                keyCode: 125
            )
        )
    }

    func test_previewOverlayKeyboardRoutingPolicy_neverForwardsEscapeAsFinderNavigation() {
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                finderNavigationForwardingEnabled: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 53
            )
        )
    }

    func test_previewOverlayFinderNavigationRefreshPolicy_refreshesAfterFinderConsumesNavigation() {
        XCTAssertTrue(
            PreviewOverlayFinderNavigationRefreshPolicy.shouldRefreshAfterFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderNavigationRefreshPolicy.shouldRefreshAfterFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.quickcookies.app",
                keyCode: 125
            )
        )
    }

    func test_previewOverlayFinderNavigationRefreshPolicy_neverRefreshesForEscape() {
        XCTAssertFalse(
            PreviewOverlayFinderNavigationRefreshPolicy.shouldRefreshAfterFinderNavigation(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 53
            )
        )
    }

    func test_previewOverlayKeyboardRoutingPolicy_doesNotForwardWithoutFinderFollow() {
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                followsFinderSelection: false,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
    }

    func test_previewOverlayInternalNavigationKeyPolicy_mapsPlainUpDownWhilePreviewVisible() {
        XCTAssertEqual(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                followsFinderSelection: false,
                keyCode: 126,
                modifierFlags: []
            ),
            .previous
        )
        XCTAssertEqual(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: []
            ),
            .next
        )
    }

    func test_previewOverlayInternalNavigationKeyPolicy_ignoresModifiedHiddenOrNonNavigationKeys() {
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: [.command]
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: false,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: []
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                followsFinderSelection: false,
                keyCode: 36,
                modifierFlags: []
            )
        )
    }

    func test_previewOverlayInternalNavigationKeyPolicy_ignoresFinderDrivenPreviewNavigation() {
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                followsFinderSelection: true,
                keyCode: 125,
                modifierFlags: []
            )
        )
    }

    func test_previewOverlayInternalNavigationRequestPolicy_buildsDirectInternalRequests() {
        let context = PreviewNavigationContext(
            currentPath: "/tmp/current.md",
            orderedPaths: ["/tmp/previous.md", "/tmp/current.md", "/tmp/next.md"],
            currentIndex: 1
        )

        XCTAssertEqual(
            PreviewOverlayInternalNavigationRequestPolicy.request(
                direction: .previous,
                context: context
            ),
            .openPath("/tmp/previous.md", source: .internalNavigation)
        )
        XCTAssertEqual(
            PreviewOverlayInternalNavigationRequestPolicy.request(
                direction: .next,
                context: context
            ),
            .openPath("/tmp/next.md", source: .internalNavigation)
        )
    }

    func test_previewOverlayInternalNavigationRequestPolicy_returnsNilAtNavigationBoundaries() {
        let firstContext = PreviewNavigationContext(
            currentPath: "/tmp/first.md",
            orderedPaths: ["/tmp/first.md", "/tmp/second.md"],
            currentIndex: 0
        )
        let lastContext = PreviewNavigationContext(
            currentPath: "/tmp/second.md",
            orderedPaths: ["/tmp/first.md", "/tmp/second.md"],
            currentIndex: 1
        )

        XCTAssertNil(
            PreviewOverlayInternalNavigationRequestPolicy.request(
                direction: .previous,
                context: firstContext
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationRequestPolicy.request(
                direction: .next,
                context: lastContext
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationRequestPolicy.request(
                direction: .next,
                context: nil
            )
        )
    }

    func test_previewFileIconAssetRegistry_requiresUserProvidedAssets() {
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .markdown))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .code))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .plainText))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .image))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .pdf))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .office))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: .unsupported))
        XCTAssertNil(PreviewFileIconAssetRegistry.assetName(for: nil))
    }

    func test_previewOverlaySizingPolicy_usesDocumentWidthForWordLikeOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "docx", isExpanded: false),
            0.52,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "pages", isExpanded: true),
            0.96,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_usesSpreadsheetWidthForExcelLikeOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "xlsx", isExpanded: false),
            0.82,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "numbers", isExpanded: true),
            0.96,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_usesPresentationWidthForSlideLikeOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "pptx", isExpanded: false),
            0.78,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "key", isExpanded: true),
            0.96,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_preservesDefaultWidthForNonOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .markdown, fileExtension: nil, isExpanded: false),
            0.68,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .markdown, fileExtension: nil, isExpanded: true),
            0.96,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_keepsUnsupportedPresentationCompact() {
        XCTAssertTrue(
            PreviewOverlaySizingPolicy.usesCompactPresentation(
                renderType: .unsupported,
                errorMessage: nil
            )
        )
        XCTAssertTrue(
            PreviewOverlaySizingPolicy.usesCompactPresentation(
                renderType: .markdown,
                errorMessage: "Load failed"
            )
        )
        XCTAssertFalse(
            PreviewOverlaySizingPolicy.usesCompactPresentation(
                renderType: .markdown,
                errorMessage: nil
            )
        )
    }

    func test_previewOverlaySizingPolicy_usesVisibleCardSizeForCompactStableWindow() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1600, height: 1000)

        let size = PreviewOverlaySizingPolicy.stableContentSize(
            renderType: .unsupported,
            filePath: nil,
            isExpanded: false,
            errorMessage: nil,
            screenVisibleFrame: screenFrame
        )

        XCTAssertEqual(size.width, 450, accuracy: 0.0001)
        XCTAssertEqual(size.height, 320, accuracy: 0.0001)
    }

    func test_previewOverlaySizingPolicy_usesVisibleCardSizeForRegularStableWindow() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1600, height: 1000)

        let size = PreviewOverlaySizingPolicy.stableContentSize(
            renderType: .markdown,
            filePath: "/tmp/demo.md",
            isExpanded: false,
            errorMessage: nil,
            screenVisibleFrame: screenFrame
        )

        XCTAssertEqual(size.width, 1088, accuracy: 0.0001)
        XCTAssertEqual(size.height, 880, accuracy: 0.0001)
    }

    func test_previewOverlaySizingPolicy_usesVisibleCardSizeForFullScreenExpandedWindow() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1600, height: 1000)

        let size = PreviewOverlaySizingPolicy.stableContentSize(
            renderType: .markdown,
            filePath: "/tmp/demo.md",
            isExpanded: true,
            errorMessage: nil,
            screenVisibleFrame: screenFrame
        )

        XCTAssertEqual(size.width, 1536, accuracy: 0.0001)
        XCTAssertEqual(size.height, 960, accuracy: 0.0001)
    }

    func test_previewContentAreaChrome_keepsUnsupportedPresentationTransparent() {
        XCTAssertEqual(
            PreviewContentAreaChrome.backgroundStyle(for: .unsupported),
            .transparent
        )
        XCTAssertEqual(
            PreviewContentAreaChrome.borderStyle(for: .unsupported),
            .none
        )
    }

    func test_previewContentAreaChrome_keepsRegularTextPresentationCarded() {
        XCTAssertEqual(
            PreviewContentAreaChrome.backgroundStyle(for: .code),
            .appBackground
        )
        XCTAssertEqual(
            PreviewContentAreaChrome.borderStyle(for: .code),
            .appBorder
        )
    }

    func test_previewOverlaySizingPolicy_usesReadableRegularWidthOnMacBookAirClassScreens() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1470, height: 900)

        let size = PreviewOverlaySizingPolicy.stableContentSize(
            renderType: .code,
            filePath: "/tmp/demo.swift",
            isExpanded: false,
            errorMessage: nil,
            screenVisibleFrame: screenFrame
        )

        XCTAssertGreaterThanOrEqual(size.width, 700)
        XCTAssertEqual(size.height, 792, accuracy: 0.0001)
    }

    func test_previewOverlaySizingPolicy_keepsAnimationOutsetSeparateFromStableWindowSize() {
        let sourceRect = CGRect(x: 100, y: 200, width: 20, height: 30)

        let rect = PreviewOverlaySizingPolicy.animationSourceRect(
            sourceRect,
            outset: 40
        )

        XCTAssertEqual(rect.origin.x, 60, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.y, 160, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 100, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 110, accuracy: 0.0001)
    }

    func test_previewOverlayResizeAnimationPolicy_animatesExpandedToggleOnlyForSameTarget() {
        let target = PreviewTarget(
            originalPath: "/tmp/demo.md",
            resolvedPath: "/tmp/demo.md",
            renderType: .markdown,
            language: nil,
            displayName: "demo.md"
        )
        let previous = PreviewSessionState(
            target: target,
            source: .hotkey,
            runtimeKind: .web,
            readiness: .ready,
            isExpanded: false
        )
        let expanded = PreviewSessionState(
            target: target,
            source: .hotkey,
            runtimeKind: .web,
            readiness: .ready,
            isExpanded: true
        )
        let otherTarget = PreviewTarget(
            originalPath: "/tmp/other.md",
            resolvedPath: "/tmp/other.md",
            renderType: .markdown,
            language: nil,
            displayName: "other.md"
        )
        let fileSwitch = PreviewSessionState(
            target: otherTarget,
            source: .finderSync,
            runtimeKind: .web,
            readiness: .loading,
            isExpanded: false
        )

        XCTAssertTrue(
            PreviewOverlayResizeAnimationPolicy.shouldAnimateResize(
                previous: previous,
                current: expanded
            )
        )
        XCTAssertFalse(
            PreviewOverlayResizeAnimationPolicy.shouldAnimateResize(
                previous: previous,
                current: fileSwitch
            )
        )
    }

    func test_previewOverlayFrameAnimationPolicy_usesExplicitAnimatorForAnimatedResizeOnly() {
        XCTAssertEqual(
            PreviewOverlayFrameAnimationPolicy.plan(animated: true),
            .explicit(duration: 0.22)
        )
        XCTAssertEqual(
            PreviewOverlayFrameAnimationPolicy.plan(animated: false),
            .immediate
        )
    }

    func test_forwardedFinderNavigationKeyCode_allowsPlainUpAndDownOnly() {
        let upEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 126
        )!
        let downEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 125
        )!
        let modifiedEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 125
        )!

        XCTAssertEqual(QuickLookOverlay.forwardedFinderNavigationKeyCode(for: upEvent), 126)
        XCTAssertEqual(QuickLookOverlay.forwardedFinderNavigationKeyCode(for: downEvent), 125)
        XCTAssertNil(QuickLookOverlay.forwardedFinderNavigationKeyCode(for: modifiedEvent))
    }

    func test_finderSyncMonitoringPolicy_includesRootScopeByDefault() {
        let directories = FinderSyncMonitoringPolicy.monitoredDirectoryURLs(
            homeDirectoryURL: URL(fileURLWithPath: "/Users/demo", isDirectory: true)
        )

        XCTAssertEqual(directories, [URL(fileURLWithPath: "/", isDirectory: true)])
    }

    func test_previewOverlayTransitionGate_treatsClosingAsStillVisibleForToggle() {
        var gate = PreviewOverlayTransitionGate()

        XCTAssertTrue(gate.beginOpen())
        gate.markOpen()
        XCTAssertTrue(gate.isVisibleForToggle)

        XCTAssertTrue(gate.beginClose())
        XCTAssertTrue(gate.isVisibleForToggle)

        gate.finishClose()
        XCTAssertFalse(gate.isVisibleForToggle)
    }

    func test_previewOverlayTransitionGate_rejectsReentrantOpenWhileClosing() {
        var gate = PreviewOverlayTransitionGate()

        XCTAssertTrue(gate.beginOpen())
        gate.markOpen()
        XCTAssertTrue(gate.beginClose())
        XCTAssertFalse(gate.beginOpen())
    }

    func test_previewOverlayTransitionGate_canStartNewOpenCycleAfterReset() {
        var gate = PreviewOverlayTransitionGate()

        XCTAssertTrue(gate.beginOpen())
        gate.markOpen()
        gate.finishClose()

        XCTAssertTrue(gate.beginOpen())
    }

    func test_previewOverlayContentPolicy_skipsRootViewReplacementForSameSession() {
        let session = PreviewSession()

        XCTAssertFalse(
            PreviewOverlayContentPolicy.shouldReplaceRootView(
                existingSession: session,
                incomingSession: session
            )
        )
    }

    func test_previewOverlayContentPolicy_replacesRootViewForDifferentSessionInstance() {
        let existingSession = PreviewSession()
        let incomingSession = PreviewSession()

        XCTAssertTrue(
            PreviewOverlayContentPolicy.shouldReplaceRootView(
                existingSession: existingSession,
                incomingSession: incomingSession
            )
        )
    }

    func test_previewOverlayPresentationPlanner_replacesRootViewBeforeBindingIncomingSession() {
        let existingSession = PreviewSession()
        let incomingSession = PreviewSession()

        let plan = PreviewOverlayPresentationPlanner.plan(
            hasExistingWindow: true,
            existingSession: existingSession,
            incomingSession: incomingSession
        )

        XCTAssertFalse(plan.shouldCreateWindow)
        XCTAssertTrue(plan.shouldReplaceRootView)
    }

    func test_previewOverlayPresentationPlanner_createsNewWindowWithoutReplacingRootView() {
        let incomingSession = PreviewSession()

        let plan = PreviewOverlayPresentationPlanner.plan(
            hasExistingWindow: false,
            existingSession: nil,
            incomingSession: incomingSession
        )

        XCTAssertTrue(plan.shouldCreateWindow)
        XCTAssertFalse(plan.shouldReplaceRootView)
    }

    func test_contentLoadingPresentationPolicy_mountsHeavyPreviewWhileLoading() {
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .office))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .pdf))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .image))
    }

    func test_contentRenderCapabilityRegistry_limitsPDFExportToMarkdownPreview() {
        XCTAssertTrue(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: .markdown
            )
        )

        XCTAssertFalse(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: .code
            )
        )
        XCTAssertFalse(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: nil
            )
        )
    }

    func test_contentRenderCapabilityRegistry_usesTextLoaderForTextBackedTypesOnly() {
        XCTAssertTrue(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .markdown))
        XCTAssertTrue(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .code))
        XCTAssertTrue(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .plainText))

        XCTAssertFalse(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .office))
        XCTAssertFalse(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .image))
        XCTAssertFalse(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .pdf))
        XCTAssertFalse(ContentRenderCapabilityRegistry.usesTextContentLoader(for: .unsupported))
        XCTAssertFalse(ContentRenderCapabilityRegistry.usesTextContentLoader(for: nil))
    }

    func test_contentRenderCapabilityRegistry_supportsSearch_forTextAndSVGSourceModes() {
        XCTAssertTrue(ContentRenderCapabilityRegistry.supportsSearch(for: .code))
        XCTAssertTrue(ContentRenderCapabilityRegistry.supportsSearch(for: .plainText))
        XCTAssertTrue(ContentRenderCapabilityRegistry.supportsSearch(for: .markdown))

        // SVG 在源码模式下支持搜索，视觉模式下不支持
        XCTAssertTrue(ContentRenderCapabilityRegistry.supportsSearch(for: .image, path: "/tmp/icon.svg", isSVGSourceMode: true))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .image, path: "/tmp/icon.svg", isSVGSourceMode: false))

        // 普通图片不支持搜索
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .image, path: "/tmp/photo.png", isSVGSourceMode: true))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .image, path: "/tmp/photo.png", isSVGSourceMode: false))

        // 媒体与只读文档不支持搜索
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .pdf))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .office))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .audio))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .video))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .font))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: .unsupported))
        XCTAssertFalse(ContentRenderCapabilityRegistry.supportsSearch(for: nil))
    }

    func test_contentLoadingPresentationPolicy_keepsGenericLoadingForTextBackedPreviewTypes() {
        XCTAssertTrue(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .code))
        XCTAssertTrue(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .plainText))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .markdown))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .unsupported))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: false, renderType: .code))
    }

    func test_previewContentVisibilityPolicy_blocksTextBackedPreviewWhenLoadedPathDoesNotMatchActivePath() {
        XCTAssertFalse(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .markdown,
                activePath: "/tmp/new.md",
                loadedContentPath: "/tmp/old.md"
            )
        )
        XCTAssertFalse(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .code,
                activePath: "/tmp/new.swift",
                loadedContentPath: "/tmp/old.swift"
            )
        )
        XCTAssertFalse(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .plainText,
                activePath: "/tmp/new.txt",
                loadedContentPath: nil
            )
        )
    }

    func test_previewContentVisibilityPolicy_allowsTextBackedPreviewOnlyAfterMatchingPathLoaded() {
        XCTAssertTrue(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .markdown,
                activePath: "/tmp/current.md",
                loadedContentPath: "/tmp/current.md"
            )
        )
        XCTAssertTrue(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .code,
                activePath: "/tmp/current.swift",
                loadedContentPath: "/tmp/current.swift"
            )
        )
    }

    func test_previewContentVisibilityPolicy_doesNotGateNonTextBackedPreviewTypes() {
        XCTAssertTrue(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .image,
                activePath: "/tmp/new.png",
                loadedContentPath: "/tmp/old.txt"
            )
        )
        XCTAssertTrue(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: .pdf,
                activePath: "/tmp/new.pdf",
                loadedContentPath: nil
            )
        )
        XCTAssertFalse(
            PreviewContentVisibilityPolicy.canRenderLoadedContent(
                renderType: nil,
                activePath: "/tmp/new.pdf",
                loadedContentPath: nil
            )
        )
    }

    func test_previewOverlayFinderFollowPolicy_followsFinderDrivenSourcesOnly() {
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .hotkey))
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .finderSync))
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .menuBar))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .urlScheme))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .service))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .internalNavigation))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: nil))
    }

    func test_previewOverlayFinderFollowPolicy_startsSelectionPollingForFinderDrivenSourcesOnly() {
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .hotkey))
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .finderSync))
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .menuBar))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .urlScheme))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .service))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: .internalNavigation))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: nil))
    }

    func test_previewOverlayFinderSelectionEventRefreshPolicy_refreshesForFinderDrivenSelectionEventsOnly() {
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .keyDown,
                keyCode: 125
            )
        )
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .keyDown,
                keyCode: 53
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: false,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.quickcookies.app",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
    }

    func test_previewOverlayFinderSelectionEventRefreshPolicy_allowsFinderDrivenRefreshWhenFrontmostAppIsUnknown() {
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: nil,
                eventType: .keyDown,
                keyCode: 125
            )
        )
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: nil,
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
    }

    func test_previewOverlayFinderSelectionEventRefreshPolicy_allowsFinderDrivenRefreshForExplicitAppFallback() {
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.quickcookies.app",
                frontmostAppFallbackBundleIdentifier: "com.quickcookies.app",
                eventType: .keyDown,
                keyCode: 125
            )
        )
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.quickcookies.app",
                frontmostAppFallbackBundleIdentifier: "com.quickcookies.app",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.other.app",
                frontmostAppFallbackBundleIdentifier: "com.quickcookies.app",
                eventType: .keyDown,
                keyCode: 125
            )
        )
    }

    func test_codeViewTextColorPolicy_keepsInitialCodeTextVisibleBeforeHighlightingFinishes() {
        XCTAssertTrue(CodeViewTextColorPolicy.shouldApplyTextViewTextColor(language: "swift"))
        XCTAssertTrue(CodeViewTextColorPolicy.shouldApplyTextViewTextColor(language: "json"))
        XCTAssertTrue(CodeViewTextColorPolicy.shouldApplyTextViewTextColor(language: nil))
    }

    func test_codeViewAsyncRenderPolicy_acceptsOnlyMatchingIdentityAndVisibleText() {
        let identity = CodeViewRenderIdentity(
            filePath: "/tmp/current.swift",
            contentLength: 12,
            contentHash: 1234,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )

        XCTAssertTrue(
            CodeViewAsyncRenderPolicy.shouldApply(
                capturedIdentity: identity,
                currentIdentity: identity,
                capturedContent: "let value = 1",
                currentText: "let value = 1"
            )
        )
    }

    func test_codeViewRepresentableUpdatePolicy_skipsRenderSyncForSameIdentityHoverRefresh() {
        let identity = CodeViewRenderIdentity(
            filePath: "/tmp/current.swift",
            contentLength: 12,
            contentHash: 1234,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )

        XCTAssertTrue(
            CodeViewRepresentableUpdatePolicy.shouldSkipRenderSync(
                previousIdentity: identity,
                nextIdentity: identity
            )
        )
    }

    func test_codeViewRepresentableUpdatePolicy_rendersWhenIdentityChanges() {
        let previousIdentity = CodeViewRenderIdentity(
            filePath: "/tmp/current.swift",
            contentLength: 12,
            contentHash: 1234,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )
        let nextIdentity = CodeViewRenderIdentity(
            filePath: "/tmp/current.swift",
            contentLength: 13,
            contentHash: 5678,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )

        XCTAssertFalse(
            CodeViewRepresentableUpdatePolicy.shouldSkipRenderSync(
                previousIdentity: previousIdentity,
                nextIdentity: nextIdentity
            )
        )
    }

    func test_pdfPreviewUpdatePolicy_doesNotReloadDocumentForSameURLHoverRefresh() {
        let url = URL(fileURLWithPath: "/tmp/current.pdf")

        XCTAssertFalse(
            PDFPreviewUpdatePolicy.shouldReloadDocument(
                previousURL: url,
                nextURL: url
            )
        )
    }

    func test_pdfPreviewUpdatePolicy_reloadsDocumentWhenURLChanges() {
        XCTAssertTrue(
            PDFPreviewUpdatePolicy.shouldReloadDocument(
                previousURL: URL(fileURLWithPath: "/tmp/old.pdf"),
                nextURL: URL(fileURLWithPath: "/tmp/new.pdf")
            )
        )
    }

    func test_codeViewAsyncRenderPolicy_rejectsWhenFileIdentityMovedOn() {
        let staleIdentity = CodeViewRenderIdentity(
            filePath: "/tmp/old.swift",
            contentLength: 12,
            contentHash: 1234,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )
        let currentIdentity = CodeViewRenderIdentity(
            filePath: "/tmp/new.swift",
            contentLength: 12,
            contentHash: 1234,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )

        XCTAssertFalse(
            CodeViewAsyncRenderPolicy.shouldApply(
                capturedIdentity: staleIdentity,
                currentIdentity: currentIdentity,
                capturedContent: "let value = 1",
                currentText: "let value = 1"
            )
        )
    }

    func test_codeViewAsyncRenderPolicy_rejectsWhenVisibleTextChangedBeforeAsyncResultReturns() {
        let identity = CodeViewRenderIdentity(
            filePath: "/tmp/current.swift",
            contentLength: 12,
            contentHash: 1234,
            language: "swift",
            themeName: "atom-one-dark",
            fontName: "Menlo",
            fontSize: 13
        )

        XCTAssertFalse(
            CodeViewAsyncRenderPolicy.shouldApply(
                capturedIdentity: identity,
                currentIdentity: identity,
                capturedContent: "let value = 1",
                currentText: "let value = 2"
            )
        )
    }

    func test_codeViewHighlightFallbackPolicy_returnsVisiblePlainTextWhenHighlightingFails() {
        let content = "let value = 1"

        let attributed = CodeViewHighlightFallbackPolicy.attributedText(
            highlighted: nil,
            fallbackContent: content,
            fontName: "Menlo",
            fontSize: 13,
            isDark: true
        )

        XCTAssertEqual(attributed.string, content)
        XCTAssertEqual(attributed.length, content.count)

        let attributes = attributed.attributes(at: 0, effectiveRange: nil)
        XCTAssertNotNil(attributes[.font])
        XCTAssertNotNil(attributes[.foregroundColor])
    }

    func test_previewIncrementalContentLoadPolicy_acceptsOnlyCurrentLoadedPath() {
        let request = PreviewContentLoadRequest(id: UUID(), path: "/tmp/current.swift")

        XCTAssertTrue(
            PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
                request: request,
                activeRequest: request,
                activePath: "/tmp/current.swift",
                loadedContentPath: "/tmp/current.swift"
            )
        )
    }

    func test_previewIncrementalContentLoadPolicy_rejectsStaleChunkAfterPathChanges() {
        let staleRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/old.swift")
        let currentRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/new.swift")

        XCTAssertFalse(
            PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
                request: staleRequest,
                activeRequest: currentRequest,
                activePath: "/tmp/new.swift",
                loadedContentPath: "/tmp/new.swift"
            )
        )
    }

    func test_previewIncrementalContentLoadPolicy_rejectsWhenCurrentTextIsNotLoadedYet() {
        let request = PreviewContentLoadRequest(id: UUID(), path: "/tmp/current.swift")

        XCTAssertFalse(
            PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
                request: request,
                activeRequest: request,
                activePath: "/tmp/current.swift",
                loadedContentPath: nil
            )
        )
    }

    func test_previewIncrementalContentLoadPolicy_rejectsSamePathOldRequestAfterReload() {
        let staleRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/current.swift")
        let currentRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/current.swift")

        XCTAssertFalse(
            PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
                request: staleRequest,
                activeRequest: currentRequest,
                activePath: "/tmp/current.swift",
                loadedContentPath: "/tmp/current.swift"
            )
        )
    }

    func test_previewAsyncRequestCleanupPolicy_clearsLoadingForStillActiveRejectedRequest() {
        let request = PreviewContentLoadRequest(id: UUID(), path: "/tmp/current.swift")

        XCTAssertTrue(
            PreviewAsyncRequestCleanupPolicy.shouldClearLoadingForRejectedResult(
                request: request,
                activeRequest: request
            )
        )
    }

    func test_previewAsyncRequestCleanupPolicy_keepsNewRequestLoadingWhenOldResultIsRejected() {
        let staleRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/old.swift")
        let currentRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/new.swift")

        XCTAssertFalse(
            PreviewAsyncRequestCleanupPolicy.shouldClearLoadingForRejectedResult(
                request: staleRequest,
                activeRequest: currentRequest
            )
        )
    }

    func test_previewOverlayPresentationPolicy_ignoresTransientFinderSelectionFailureWhenOverlayVisible() {
        XCTAssertTrue(
            PreviewOverlayPresentationPolicy.shouldIgnoreResolutionFailure(
                currentlyVisible: true,
                request: .refreshFinderSelection(),
                error: .noFinderSelection
            )
        )
    }

    func test_previewOverlayPresentationPolicy_keepsNoSelectionFailureForInitialOpen() {
        XCTAssertFalse(
            PreviewOverlayPresentationPolicy.shouldIgnoreResolutionFailure(
                currentlyVisible: false,
                request: .toggleFromFinderHotkey(),
                error: .noFinderSelection
            )
        )
    }

    func test_forwardedFinderNavigationKeyCode_withMouseEvent_returnsNilWithoutCrashing() {
        guard let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        ) else {
            XCTFail("Failed to create mock mouse event")
            return
        }

        let keyCode = QuickLookOverlay.forwardedFinderNavigationKeyCode(for: mouseEvent)
        XCTAssertNil(keyCode, "鼠标事件不应触发 keyCode 读取或转发")
    }

    func test_forwardedFinderNavigationKeyCode_withArrowKeys_returnsKeyCode() {
        guard let downArrowEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 125
        ) else {
            XCTFail("Failed to create mock key event")
            return
        }

        let keyCode = QuickLookOverlay.forwardedFinderNavigationKeyCode(for: downArrowEvent)
        XCTAssertEqual(keyCode, 125)
    }

    func test_previewOverlayTransformMath_centerScaleTransform_keepsCenterInvariant() {
        let targetSize = CGSize(width: 960, height: 640)
        let scale = PreviewOverlayOpenAnimationPolicy.startScale // 0.92

        let transform = PreviewOverlayTransformMath.centerScaleTransform(scale: scale, targetSize: targetSize)

        let expectedDx = targetSize.width * (1.0 - scale) / 2.0 // 960 * 0.08 / 2 = 38.4
        let expectedDy = targetSize.height * (1.0 - scale) / 2.0 // 640 * 0.08 / 2 = 25.6

        XCTAssertEqual(transform.m41, expectedDx, accuracy: 0.001)
        XCTAssertEqual(transform.m42, expectedDy, accuracy: 0.001)
        XCTAssertEqual(transform.m11, scale, accuracy: 0.001)
        XCTAssertEqual(transform.m22, scale, accuracy: 0.001)

        // 验证中心点映射后保持严格不变
        let centerX = targetSize.width / 2.0
        let centerY = targetSize.height / 2.0
        let mappedCenterX = centerX * transform.m11 + transform.m41
        let mappedCenterY = centerY * transform.m22 + transform.m42

        XCTAssertEqual(mappedCenterX, centerX, accuracy: 0.001)
        XCTAssertEqual(mappedCenterY, centerY, accuracy: 0.001)
    }

    func test_previewOverlayOpenAnimationPolicy_nativeCenterSpringParametersAreStrictlyCalibrated() {
        XCTAssertEqual(PreviewOverlayOpenAnimationPolicy.startScale, 0.92, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayOpenAnimationPolicy.springDamping, 24.0, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayOpenAnimationPolicy.springStiffness, 300.0, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayOpenAnimationPolicy.springMass, 0.8, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayOpenAnimationPolicy.fadeInDuration, 0.14, accuracy: 0.001)
    }

    func test_previewOverlayCloseAnimationPolicy_nativeCenterFluidParametersAreStrictlyCalibrated() {
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.endScale, 0.94, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.duration, 0.13, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.controlPoint1.x, 0.35, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.controlPoint1.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.controlPoint2.x, 0.15, accuracy: 0.001)
        XCTAssertEqual(PreviewOverlayCloseAnimationPolicy.controlPoint2.y, 1.0, accuracy: 0.001)
    }

    func test_hotkeyManager_cleansUpStateOnUnregister() {
        let hotkeyManager = HotkeyManager.shared
        hotkeyManager.unregister()
        // 验证注销后幂等且不崩溃
        hotkeyManager.unregister()
    }

    // MARK: - Onboarding Tests

    func test_onboardingWindowPolicy_dimensionsAndConfiguration() {
        XCTAssertEqual(OnboardingWindowPolicy.contentSize.width, 540, accuracy: 0.001)
        XCTAssertEqual(OnboardingWindowPolicy.contentSize.height, 410, accuracy: 0.001)
        XCTAssertEqual(OnboardingWindowPolicy.cornerRadius, 28, accuracy: 0.001)
        XCTAssertEqual(OnboardingWindowPolicy.totalPages, 4)
    }

    func test_onboardingExitCoordinator_idempotency() {
        var coordinator = OnboardingExitCoordinator()
        XCTAssertFalse(coordinator.hasExited)

        var callCount = 0
        let firstResult = coordinator.requestExit {
            callCount += 1
        }
        XCTAssertTrue(firstResult)
        XCTAssertTrue(coordinator.hasExited)
        XCTAssertEqual(callCount, 1)

        let secondResult = coordinator.requestExit {
            callCount += 1
        }
        XCTAssertFalse(secondResult)
        XCTAssertTrue(coordinator.hasExited)
        XCTAssertEqual(callCount, 1)
    }

    func test_onboardingShowcaseTab_completeness() {
        XCTAssertEqual(ShowcaseTab.allCases.count, 4)
        for tab in ShowcaseTab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
            XCTAssertFalse(tab.icon.isEmpty)
            XCTAssertFalse(tab.description.isEmpty)
        }
    }

    func test_onboarding_localizationCoverage() {
        let onboardingKeys = [
            "Skip Guide",
            "Instant Card Preview for Finder",
            "Instant preview code, markdown, archives and documents without opening heavy apps.",
            "Zero-Accessibility Risk",
            "Interactive Hotkey Playground",
            "Press twice anywhere in Finder to trigger instant card preview.",
            "Double-press Command (Recommended)",
            "Double-press Option",
            "Try pressing twice on your keyboard now:",
            "Triggered! Perfect muscle memory!",
            "Waiting for double-press...",
            "Superpower Showcase",
            "Explore what QuickCookies can preview for you in Finder:",
            "Code & Config",
            "Markdown Docs",
            "Archive & Folders",
            "App Relay",
            "Syntax highlighting for 60+ languages with line numbers & streaming highlight.",
            "GitHub-style typography with rounded tables, transparent background & local images.",
            "0-extract structure inspection, format size bar & collapsible directory tree.",
            "One-click handoff to VS Code, Cursor, Xcode or your favorite editors.",
            "Open in External Editor",
            "Ready & Personalize",
            "Personalized Settings",
            "Zero-Permission Mode Ready",
            "QuickCookies core features run without any accessibility permissions.",
            "Theme Mode",
            "Interface Language",
            "Finder Extension",
            "Attempted",
            "Enable",
            "Full Disk Access",
            "Authorized",
            "Grant Access",
            "Back",
            "Next",
            "Start Exploring QuickCookies",
            // Singline-inspired modern keys & Native HIG refactor
            "Welcome to QuickCookies",
            "Instant card preview for your Finder files",
            "Fast, lightweight file previews for Finder",
            "Let's go",
            "Get Started",
            "Takes about a minute",
            "Takes about a minute · No extra permissions needed",
            "How do you want to summon?",
            "How would you like to open previews?",
            "Choose the hotkey you press in Finder.",
            "Choose the shortcut to press in Finder.",
            "Double Command",
            "Double Option",
            "Instant Search",
            "Double Command is recommended for natural macOS muscle memory.",
            "Double Command is recommended for natural macOS interaction.",
            "What can QuickCookies do?",
            "What QuickCookies previews",
            "Instant preview without opening heavy apps.",
            "Preview files instantly without opening heavy editors.",
            "You're all set",
            "QuickCookies is standing by in Finder.",
            "QuickCookies is ready to preview files in Finder.",
            "Pure architecture",
            "Privacy & Security",
            "Zero",
            "Accessibility privileges needed. Safe, private & instant.",
            "Zero Accessibility privileges required. Safe, private, and lightweight.",
            "No Special Permissions Required",
            "Start at login",
            "Open at Login",
            "Ready when you open your Mac.",
            "Available in the background right after you log in.",
            "View settings >",
            "More Settings...",
            "Fonts, theme and shortcuts.",
            "Customize fonts, themes, and shortcuts.",
            "Start Exploring",
            "Start Using QuickCookies",
            "Continue",
            "Recommended",
            "Classic",
            "60+ Languages",
            "GitHub Typography",
            "0-Extract X-Ray",
            "Instant Inspection",
            "GitHub-style typography with rounded tables & images.",
            "Feature",
            "Status",
            "Close Preview (Esc)",
            "Dismiss Window",
            "Copy full path to clipboard",
            "Copy full physical path to clipboard",
            "Architecture & Capabilities",
            "Fast Syntax Highlighting",
            "Seamless Editor Handoff"
        ]

        for key in onboardingKeys {
            let enTranslation = Localization.translate(key, lang: .en)
            let zhTranslation = Localization.translate(key, lang: .zhHans)

            XCTAssertFalse(enTranslation.isEmpty, "English translation should not be empty for key: \(key)")
            XCTAssertFalse(zhTranslation.isEmpty, "Chinese translation should not be empty for key: \(key)")
            XCTAssertNotEqual(zhTranslation, key, "Chinese translation should not return fallback English key for: \(key)")
        }
    }

    func test_onboardingView_canRenderAllPagesWithoutCrashing() {
        for page in 0..<OnboardingWindowPolicy.totalPages {
            let view = OnboardingView(initialPage: page)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(origin: .zero, size: OnboardingWindowPolicy.contentSize)
            XCTAssertEqual(hosting.frame.size.width, 540, accuracy: 0.001)
            XCTAssertEqual(hosting.frame.size.height, 410, accuracy: 0.001)
        }
    }

    func test_onboardingView_renderAndSaveSnapshots() {
        let size = OnboardingWindowPolicy.contentSize
        let targetDir = "/Users/jiangwei/.gemini/antigravity/brain/2d112d4e-b4ed-46df-9a55-9b4b3ea47f81/scratch"
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        
        for page in 0..<OnboardingWindowPolicy.totalPages {
            let view = OnboardingView(initialPage: page)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(origin: .zero, size: size)
            window.contentView = hosting
            hosting.layoutSubtreeIfNeeded()
            
            guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { continue }
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            let pngData = bitmap.representation(using: .png, properties: [:])
            let fileURL = URL(fileURLWithPath: "\(targetDir)/onboarding_page_\(page).png")
            try? pngData?.write(to: fileURL)
        }
    }
}
