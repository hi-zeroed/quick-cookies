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
        var didFocusPreview = false
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
            focusWindowForPreview: {
                didFocusPreview = true
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
        actions.focusWindowForPreview()
        actions.unfocusWindowToFinder()
        actions.showToast("demo", "checkmark")

        XCTAssertTrue(didClose)
        XCTAssertTrue(didFocus)
        XCTAssertTrue(didFocusPreview)
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

    func test_previewOverlayKeyWindowPolicy_keepsFinderDrivenPreviewNonKey() {
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .office,
                source: .hotkey
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .markdown,
                source: .finderSync
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .image,
                source: .menuBar
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_allowsDirectPathPreviewInteraction() {
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .markdown,
                source: .service
            )
        )
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: .image,
                source: .urlScheme
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .preview,
                renderType: nil,
                source: .service
            )
        )
    }

    func test_previewOverlayKeyWindowPolicy_allowsEditingForTextBackedFiles() {
        XCTAssertTrue(
            PreviewOverlayKeyWindowPolicy.canBecomeKey(
                mode: .edit,
                renderType: .code,
                source: .hotkey
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_keepsFinderDrivenPreviewInFinder() {
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: .office,
                source: .hotkey
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: .markdown,
                source: .finderSync
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_focusesDirectPathPreviewOnPresentation() {
        XCTAssertTrue(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: .markdown,
                source: .service
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
                mode: .preview,
                renderType: nil,
                source: .service
            )
        )
    }

    func test_previewOverlayFocusActivationPolicy_doesNotActivateAppForFinderDrivenPreview() {
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
                mode: .preview,
                renderType: .markdown,
                source: .hotkey
            )
        )
        XCTAssertTrue(
            PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
                mode: .preview,
                renderType: .image,
                source: .service
            )
        )
        XCTAssertFalse(
            PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
                mode: .preview,
                renderType: nil,
                source: .service
            )
        )
    }

    func test_previewOverlayKeyboardRoutingPolicy_doesNotForwardFinderNavigationByDefault() {
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
    }

    func test_previewOverlayWindowChromePolicy_disablesSystemShadowForRoundedCardWindow() {
        XCTAssertFalse(PreviewOverlayWindowChromePolicy.usesSystemWindowShadow)
    }

    func test_previewOverlayKeyboardRoutingPolicy_forwardsFinderNavigationOnlyWhenExplicitlyEnabled() {
        XCTAssertTrue(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: true,
                finderNavigationForwardingEnabled: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
        XCTAssertFalse(
            PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
                isVisible: true,
                isEditing: false,
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
                isEditing: false,
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
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 125
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderNavigationRefreshPolicy.shouldRefreshAfterFinderNavigation(
                isVisible: true,
                isEditing: false,
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
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                keyCode: 53
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

    func test_previewOverlayInternalNavigationKeyPolicy_mapsPlainUpDownWhilePreviewVisible() {
        XCTAssertEqual(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: false,
                keyCode: 126,
                modifierFlags: []
            ),
            .previous
        )
        XCTAssertEqual(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: []
            ),
            .next
        )
    }

    func test_previewOverlayInternalNavigationKeyPolicy_ignoresEditingModifiedHiddenOrNonNavigationKeys() {
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                isEditing: true,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: []
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: [.command]
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: false,
                isEditing: false,
                followsFinderSelection: false,
                keyCode: 125,
                modifierFlags: []
            )
        )
        XCTAssertNil(
            PreviewOverlayInternalNavigationKeyPolicy.direction(
                isVisible: true,
                isEditing: false,
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
                isEditing: false,
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

        XCTAssertEqual(size.width, 608, accuracy: 0.0001)
        XCTAssertEqual(size.height, 880, accuracy: 0.0001)
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
            mode: .preview,
            readiness: .ready,
            isExpanded: false
        )
        let expanded = PreviewSessionState(
            target: target,
            source: .hotkey,
            runtimeKind: .web,
            mode: .preview,
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
            mode: .preview,
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

    func test_contentRenderCapabilityRegistry_allowsEditingForTextBackedTypesOnly() {
        XCTAssertTrue(ContentRenderCapabilityRegistry.allowsEditing(for: .markdown))
        XCTAssertTrue(ContentRenderCapabilityRegistry.allowsEditing(for: .code))
        XCTAssertTrue(ContentRenderCapabilityRegistry.allowsEditing(for: .plainText))

        XCTAssertFalse(ContentRenderCapabilityRegistry.allowsEditing(for: .office))
        XCTAssertFalse(ContentRenderCapabilityRegistry.allowsEditing(for: .image))
        XCTAssertFalse(ContentRenderCapabilityRegistry.allowsEditing(for: .pdf))
        XCTAssertFalse(ContentRenderCapabilityRegistry.allowsEditing(for: .unsupported))
        XCTAssertFalse(ContentRenderCapabilityRegistry.allowsEditing(for: nil))
    }

    func test_contentRenderCapabilityRegistry_limitsPDFExportToMarkdownPreview() {
        XCTAssertTrue(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: .markdown,
                mode: .preview
            )
        )

        XCTAssertFalse(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: .markdown,
                mode: .edit
            )
        )
        XCTAssertFalse(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: .code,
                mode: .preview
            )
        )
        XCTAssertFalse(
            ContentRenderCapabilityRegistry.allowsPDFExport(
                for: nil,
                mode: .preview
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

    func test_contentEditingPolicy_allowsTextBackedTypesOnly() {
        XCTAssertTrue(ContentEditingPolicy.allowsEditing(for: .markdown))
        XCTAssertTrue(ContentEditingPolicy.allowsEditing(for: .code))
        XCTAssertTrue(ContentEditingPolicy.allowsEditing(for: .plainText))

        XCTAssertFalse(ContentEditingPolicy.allowsEditing(for: .office))
        XCTAssertFalse(ContentEditingPolicy.allowsEditing(for: .unsupported))
        XCTAssertFalse(ContentEditingPolicy.allowsEditing(for: nil))
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
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .keyDown,
                keyCode: 125
            )
        )
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .keyDown,
                keyCode: 53
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                isEditing: true,
                followsFinderSelection: true,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                isEditing: false,
                followsFinderSelection: false,
                frontmostBundleIdentifier: "com.apple.finder",
                eventType: .leftMouseUp,
                keyCode: nil
            )
        )
        XCTAssertFalse(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                isEditing: false,
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
                isEditing: false,
                followsFinderSelection: true,
                frontmostBundleIdentifier: nil,
                eventType: .keyDown,
                keyCode: 125
            )
        )
        XCTAssertTrue(
            PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
                isVisible: true,
                isEditing: false,
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
                isEditing: false,
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
                isEditing: false,
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
                isEditing: false,
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

    func test_previewEditPreparationPolicy_acceptsOnlyCurrentLoadedRequest() {
        let request = PreviewContentLoadRequest(id: UUID(), path: "/tmp/current.swift")

        XCTAssertTrue(
            PreviewEditPreparationPolicy.shouldApplyRemainingText(
                request: request,
                activeRequest: request,
                activePath: "/tmp/current.swift",
                loadedContentPath: "/tmp/current.swift"
            )
        )
    }

    func test_previewEditPreparationPolicy_rejectsStaleRemainingTextAfterPathChanges() {
        let staleRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/old.swift")
        let currentRequest = PreviewContentLoadRequest(id: UUID(), path: "/tmp/new.swift")

        XCTAssertFalse(
            PreviewEditPreparationPolicy.shouldApplyRemainingText(
                request: staleRequest,
                activeRequest: currentRequest,
                activePath: "/tmp/new.swift",
                loadedContentPath: "/tmp/new.swift"
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

}
