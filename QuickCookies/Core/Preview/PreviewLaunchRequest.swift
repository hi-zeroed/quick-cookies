import Foundation
import AppKit

@MainActor
struct PreviewUIPresenter {
    let isPreviewVisibleProvider: () -> Bool
    let captureFinderSourceRectAction: () -> Void
    let closePreviewWithAnimationAction: () -> Void
    let closePreviewAction: () -> Void
    let presentPreviewAction: (PreviewSession) -> Void
    let setFinderSelectionRequestHandlerAction: (((PreviewLaunchRequest) -> Void)?) -> Void
    let showToastAction: (String, String?) -> Void
    let refreshPreviewAppearanceAction: () -> Void
    let refreshSettingsAppearanceAction: () -> Void
    let refreshSettingsTitleAction: () -> Void

    var isPreviewVisible: Bool {
        isPreviewVisibleProvider()
    }

    func captureFinderSourceRect() {
        captureFinderSourceRectAction()
    }

    func closePreviewWithAnimation() {
        closePreviewWithAnimationAction()
    }

    func closePreview() {
        closePreviewAction()
    }

    func present(session: PreviewSession) {
        presentPreviewAction(session)
    }

    func setFinderSelectionRequestHandler(_ handler: ((PreviewLaunchRequest) -> Void)?) {
        setFinderSelectionRequestHandlerAction(handler)
    }

    func showToast(message: String, icon: String?) {
        showToastAction(message, icon)
    }

    func refreshWindowAppearance() {
        refreshPreviewAppearanceAction()
        refreshSettingsAppearanceAction()
    }

    func refreshLocalizedTitles() {
        refreshSettingsTitleAction()
    }
}

extension Notification.Name {
    static let settingsHotkeyDidChange = Notification.Name("Settings.hotkeyDidChange")
    static let settingsThemeModeDidChange = Notification.Name("Settings.themeModeDidChange")
    static let settingsLanguageDidChange = Notification.Name("Settings.languageDidChange")
}

@MainActor
extension PreviewUIPresenter {
    static let live = PreviewUIPresenter(
        isPreviewVisibleProvider: {
            QuickLookOverlay.shared.isVisible
        },
        captureFinderSourceRectAction: {
            QuickLookOverlay.shared.captureFinderSourceRect()
        },
        closePreviewWithAnimationAction: {
            QuickLookOverlay.shared.closeWithAnimation()
        },
        closePreviewAction: {
            QuickLookOverlay.shared.close()
        },
        presentPreviewAction: { session in
            QuickLookOverlay.shared.present(session: session)
        },
        setFinderSelectionRequestHandlerAction: { handler in
            QuickLookOverlay.shared.onFinderSelectionRequest = handler
        },
        showToastAction: { message, icon in
            QuickLookOverlay.shared.showToast(message: message, icon: icon)
        },
        refreshPreviewAppearanceAction: {
            QuickLookOverlay.shared.updateAppearance()
        },
        refreshSettingsAppearanceAction: {
            SettingsWindowController.shared.updateAppearance()
        },
        refreshSettingsTitleAction: {
            SettingsWindowController.shared.updateTitle()
        }
    )
}

/// 预览入口的统一描述。
///
/// 约束：
/// - 入口只表达“来源、路径意图、展示意图”
/// - 不在这里做 Finder 解析、窗口展示、或文件类型判断
enum PreviewLaunchSource: Equatable {
    case hotkey
    case service
    case urlScheme
    case menuBar
    case finderSync
    case internalNavigation
}

enum PreviewLaunchPathIntent: Equatable {
    case finderSelection
    case direct(path: String)
}

enum PreviewPresentationIntent: Equatable {
    case open
    case toggle
}

struct PreviewLaunchRequest: Equatable {
    let source: PreviewLaunchSource
    let pathIntent: PreviewLaunchPathIntent
    let presentation: PreviewPresentationIntent

    static func openPath(
        _ path: String,
        source: PreviewLaunchSource
    ) -> PreviewLaunchRequest {
        PreviewLaunchRequest(
            source: source,
            pathIntent: .direct(path: path),
            presentation: .open
        )
    }

    static func toggleFromFinderHotkey() -> PreviewLaunchRequest {
        PreviewLaunchRequest(
            source: .hotkey,
            pathIntent: .finderSelection,
            presentation: .toggle
        )
    }

    static func refreshFinderSelection(
        source: PreviewLaunchSource = .finderSync
    ) -> PreviewLaunchRequest {
        PreviewLaunchRequest(
            source: source,
            pathIntent: .finderSelection,
            presentation: .open
        )
    }
}

enum PreviewTriggerAction: Equatable {
    case ignore
    case closeVisibleOverlay
    case send(PreviewLaunchRequest)
}

enum PreviewTriggerPolicy {
    static func actionForFinderToggle(
        isOverlayVisible: Bool,
        frontmostBundleIdentifier: String?
    ) -> PreviewTriggerAction {
        if isOverlayVisible {
            return .closeVisibleOverlay
        }

        guard frontmostBundleIdentifier == "com.apple.finder" else {
            return .ignore
        }

        return .send(.toggleFromFinderHotkey())
    }
}

final class FinderSelectionMonitor {
    private(set) var lastObservedSelectionPath: String?

    func setCurrentResolvedPath(_ path: String?) {
        lastObservedSelectionPath = path
    }

    func reset() {
        lastObservedSelectionPath = nil
    }

    func refreshIfFinderFrontmost<SelectionError: Error>(
        frontmostBundleIdentifier: String?,
        allowsUnknownFrontmost: Bool = false,
        additionalAllowedFrontmostBundleIdentifiers: Set<String> = [],
        runAsync: @escaping (@escaping () -> Void) -> Void,
        deliverOnMain: @escaping (@escaping () -> Void) -> Void,
        detectSelectionPath: @escaping () -> Result<String, SelectionError>,
        detectSourceRect: @escaping () -> CGRect,
        onRequest: @escaping (PreviewLaunchRequest) -> Void,
        onSourceRectUpdate: @escaping (CGRect) -> Void
    ) {
        let isAllowedFrontmost =
            frontmostBundleIdentifier == "com.apple.finder" ||
            (allowsUnknownFrontmost && frontmostBundleIdentifier == nil) ||
            frontmostBundleIdentifier.map(additionalAllowedFrontmostBundleIdentifiers.contains) == true

        guard isAllowedFrontmost else {
            return
        }

        let previousSelectionPath = lastObservedSelectionPath

        runAsync {
            let result = detectSelectionPath()

            deliverOnMain {
                let detectedSelectionPath: String?
                switch result {
                case .success(let path):
                    detectedSelectionPath = path
                case .failure:
                    detectedSelectionPath = nil
                }

                let decision = FinderSelectionRefresh.decide(
                    previousSelectionPath: previousSelectionPath,
                    detectedSelectionPath: detectedSelectionPath
                )

                guard case .request(let request) = decision else {
                    return
                }

                self.lastObservedSelectionPath = detectedSelectionPath.map {
                    FileUtils.resolveSymlink(at: $0)
                }
                onRequest(request)

                runAsync {
                    let sourceRect = detectSourceRect()
                    deliverOnMain {
                        onSourceRectUpdate(sourceRect)
                    }
                }
            }
        }
    }
}

protocol FinderSelectionPollingTimer: AnyObject {
    func invalidate()
}

extension Timer: FinderSelectionPollingTimer {}

final class FinderSelectionPollingController {
    typealias TimerFactory = (_ interval: TimeInterval, _ tick: @escaping () -> Void) -> FinderSelectionPollingTimer

    private let timerFactory: TimerFactory
    private let frontmostBundleIdentifier: () -> String?
    private let detectSelectionPath: () -> Result<String, any Error>
    private let detectSourceRect: () -> CGRect
    private let onRequest: (PreviewLaunchRequest) -> Void
    private let onSourceRectUpdate: (CGRect) -> Void
    private let runAsync: (@escaping () -> Void) -> Void
    private let deliverOnMain: (@escaping () -> Void) -> Void
    private let monitor = FinderSelectionMonitor()
    private var timer: FinderSelectionPollingTimer?

    var isRunning: Bool {
        timer != nil
    }

    init(
        timerFactory: @escaping TimerFactory,
        frontmostBundleIdentifier: @escaping () -> String?,
        detectSelectionPath: @escaping () -> Result<String, any Error>,
        detectSourceRect: @escaping () -> CGRect,
        onRequest: @escaping (PreviewLaunchRequest) -> Void,
        onSourceRectUpdate: @escaping (CGRect) -> Void,
        runAsync: @escaping (@escaping () -> Void) -> Void,
        deliverOnMain: @escaping (@escaping () -> Void) -> Void
    ) {
        self.timerFactory = timerFactory
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.detectSelectionPath = detectSelectionPath
        self.detectSourceRect = detectSourceRect
        self.onRequest = onRequest
        self.onSourceRectUpdate = onSourceRectUpdate
        self.runAsync = runAsync
        self.deliverOnMain = deliverOnMain
    }

    func syncCurrentResolvedPath(_ path: String?) {
        monitor.setCurrentResolvedPath(path)
    }

    func resetSelection() {
        monitor.reset()
    }

    func start(
        interval: TimeInterval = 0.15,
        allowsUnknownFrontmost: Bool = false,
        additionalAllowedFrontmostBundleIdentifiers: Set<String> = []
    ) {
        guard timer == nil else {
            return
        }

        timer = timerFactory(interval) { [weak self] in
            self?.refresh(
                allowsUnknownFrontmost: allowsUnknownFrontmost,
                additionalAllowedFrontmostBundleIdentifiers: additionalAllowedFrontmostBundleIdentifiers
            )
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh(
        allowsUnknownFrontmost: Bool = false,
        additionalAllowedFrontmostBundleIdentifiers: Set<String> = []
    ) {
        monitor.refreshIfFinderFrontmost(
            frontmostBundleIdentifier: frontmostBundleIdentifier(),
            allowsUnknownFrontmost: allowsUnknownFrontmost,
            additionalAllowedFrontmostBundleIdentifiers: additionalAllowedFrontmostBundleIdentifiers,
            runAsync: runAsync,
            deliverOnMain: deliverOnMain,
            detectSelectionPath: detectSelectionPath,
            detectSourceRect: detectSourceRect,
            onRequest: onRequest,
            onSourceRectUpdate: onSourceRectUpdate
        )
    }

    func refreshBurst(
        delays: [TimeInterval],
        allowsUnknownFrontmost: Bool = false,
        additionalAllowedFrontmostBundleIdentifiers: Set<String> = [],
        schedule: @escaping (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void
    ) {
        for delay in delays {
            schedule(delay) { [weak self] in
                self?.refresh(
                    allowsUnknownFrontmost: allowsUnknownFrontmost,
                    additionalAllowedFrontmostBundleIdentifiers: additionalAllowedFrontmostBundleIdentifiers
                )
            }
        }
    }
}

@MainActor
final class PreviewRequestController {
    var onRequest: ((PreviewLaunchRequest) -> Void)?

    init() {}

    func submit(_ request: PreviewLaunchRequest) {
        onRequest?(request)
    }

    func openPath(_ path: String, source: PreviewLaunchSource) {
        submit(.openPath(path, source: source))
    }

    func toggleFromFinder(
        isOverlayVisible: Bool,
        frontmostBundleIdentifier: String?,
        prepareSourceRect: () -> Void,
        closeOverlay: () -> Void
    ) {
        switch PreviewTriggerPolicy.actionForFinderToggle(
            isOverlayVisible: isOverlayVisible,
            frontmostBundleIdentifier: frontmostBundleIdentifier
        ) {
        case .ignore:
            return
        case .closeVisibleOverlay:
            closeOverlay()
        case .send(let request):
            prepareSourceRect()
            submit(request)
        }
    }
}
