import XCTest
@testable import QuickCookies

@MainActor
final class QuickLookOverlayStateTests: XCTestCase {
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
        var didFocus = false
        var didUnfocus = false
        var toastPayload: (String, String?)?
        let expectedWindow = NSWindow()

        let actions = PreviewWindowActions(
            closeOverlay: {
                didClose = true
            },
            focusWindowForEdit: {
                didFocus = true
            },
            unfocusWindowToFinder: {
                didUnfocus = true
            },
            showToast: { message, icon in
                toastPayload = (message, icon)
            },
            currentWindow: {
                expectedWindow
            }
        )

        actions.closeOverlay()
        actions.focusWindowForEdit()
        actions.unfocusWindowToFinder()
        actions.showToast("demo", "checkmark")

        XCTAssertTrue(didClose)
        XCTAssertTrue(didFocus)
        XCTAssertTrue(didUnfocus)
        XCTAssertEqual(toastPayload?.0, "demo")
        XCTAssertEqual(toastPayload?.1, "checkmark")
        XCTAssertTrue(actions.currentWindow() === expectedWindow)
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

    func test_previewOverlayKeyWindowPolicy_allowsOfficePreviewInteraction() {
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .office
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_keepsRegularPreviewNonActivating() {
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .markdown
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .image
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_allowsEditingForTextBackedFiles() {
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .edit,
                renderType: .code
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_focusesOfficeOnPresentation() {
        XCTAssertTrue(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: .office
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_keepsRegularPreviewNonActivatingOnPresentation() {
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: .markdown
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: .image
            )
        )
    }

    func test_previewOverlayKeyboardRoutingPolicy_forwardsFinderNavigationOnlyWhenFinderIsFrontmost() {
        XCTAssertTrue(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )

        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.quickcookies.app",
                keyCode: 125
            )
        )
    }

    func test_previewOverlayKeyboardRoutingPolicy_doesNotForwardWhileEditingOrWithoutFinderFollow() {
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: false,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
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
            0.34,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "pages", isExpanded: true),
            0.56,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_usesSpreadsheetWidthForExcelLikeOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "xlsx", isExpanded: false),
            0.72,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "numbers", isExpanded: true),
            0.82,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_usesPresentationWidthForSlideLikeOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "pptx", isExpanded: false),
            0.66,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .office, fileExtension: "key", isExpanded: true),
            0.78,
            accuracy: 0.0001
        )
    }

    func test_previewOverlaySizingPolicy_preservesDefaultWidthForNonOfficeContent() {
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .markdown, fileExtension: nil, isExpanded: false),
            0.38,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewOverlaySizingPolicy.widthRatio(for: .markdown, fileExtension: nil, isExpanded: true),
            0.68,
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

    func test_contentLoadingPresentationPolicy_keepsGenericLoadingForTextBackedPreviewTypes() {
        XCTAssertTrue(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .code))
        XCTAssertTrue(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .plainText))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .markdown))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: true, renderType: .unsupported))
        XCTAssertFalse(ContentLoadingPresentationPolicy.shouldShowGenericLoading(isLoading: false, renderType: .code))
    }

    func test_previewOverlayFinderFollowPolicy_followsFinderDrivenSourcesOnly() {
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .hotkey))
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .finderSync))
        XCTAssertTrue(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .menuBar))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .urlScheme))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: .service))
        XCTAssertFalse(PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: nil))
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

}
