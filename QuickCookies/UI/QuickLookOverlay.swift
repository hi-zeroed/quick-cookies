import SwiftUI
import AppKit
import Combine

/// 自定义 NSPanel 子类，允许 borderless 无标题栏窗口接收键盘焦点和快捷键事件
class QuickLookPanel: NSPanel {
    var canBecomeKeyProvider: () -> Bool = { true }

    override var canBecomeKey: Bool {
        return canBecomeKeyProvider()
    }
    
    override var canBecomeMain: Bool {
        return canBecomeKeyProvider()
    }
}

/// 自定义 NSPanel，专用于 Toast 提示，不抢占焦点，且确保在后台也能正常展示
class ToastPanel: NSPanel {
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

private final class PollingBridgeTimer: NSObject, FinderSelectionPollingTimer {
    private var timer: Timer?

    init(interval: TimeInterval, tick: @escaping () -> Void) {
        super.init()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            tick()
        }
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

private enum PreviewOverlayPhase: Equatable {
    case idle
    case opening
    case open
    case closing
}

struct PreviewOverlayTransitionGate {
    fileprivate private(set) var phase: PreviewOverlayPhase = .idle

    mutating func beginOpen() -> Bool {
        guard phase == .idle else { return false }
        phase = .opening
        return true
    }

    mutating func markOpen() {
        if phase == .opening {
            phase = .open
        }
    }

    mutating func beginClose() -> Bool {
        switch phase {
        case .opening, .open:
            phase = .closing
            return true
        case .idle, .closing:
            return false
        }
    }

    mutating func finishClose() {
        phase = .idle
    }

    var isVisibleForToggle: Bool {
        phase != .idle
    }
}

enum PreviewOverlayContentPolicy {
    static func shouldReplaceRootView(
        existingSession: PreviewSession?,
        incomingSession: PreviewSession
    ) -> Bool {
        existingSession !== incomingSession
    }
}

struct PreviewOverlayPresentationPlan: Equatable {
    let shouldCreateWindow: Bool
    let shouldReplaceRootView: Bool
}

enum PreviewOverlayPresentationPlanner {
    static func plan(
        hasExistingWindow: Bool,
        existingSession: PreviewSession?,
        incomingSession: PreviewSession
    ) -> PreviewOverlayPresentationPlan {
        PreviewOverlayPresentationPlan(
            shouldCreateWindow: !hasExistingWindow,
            shouldReplaceRootView: hasExistingWindow && PreviewOverlayContentPolicy.shouldReplaceRootView(
                existingSession: existingSession,
                incomingSession: incomingSession
            )
        )
    }
}

enum PreviewOverlayFinderFollowPolicy {
    static func shouldFollowFinderSelection(for source: PreviewLaunchSource?) -> Bool {
        switch source {
        case .hotkey, .finderSync, .menuBar:
            return true
        case .service, .urlScheme, .internalNavigation, .none:
            return false
        }
    }

    static func shouldStartSelectionPolling(for source: PreviewLaunchSource?) -> Bool {
        shouldFollowFinderSelection(for: source)
    }
}

enum PreviewOverlayFinderInteractionPolicy {
    static func isFinderDriven(_ source: PreviewLaunchSource?) -> Bool {
        PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(for: source)
    }
}

enum PreviewOverlayWindowChromePolicy {
    static let usesSystemWindowShadow = false
}

enum PreviewOverlayPresentationPolicy {
    static func shouldIgnoreResolutionFailure(
        currentlyVisible: Bool,
        request: PreviewLaunchRequest,
        error: PreviewTargetError
    ) -> Bool {
        guard currentlyVisible else {
            return false
        }

        guard request == .refreshFinderSelection() else {
            return false
        }

        return error == .noFinderSelection
    }
}

enum PreviewOverlayKeyWindowPolicy {
    static func canBecomeKey(
        mode: PreviewSessionMode?,
        renderType: FileRenderType?,
        source: PreviewLaunchSource?
    ) -> Bool {
        guard renderType != nil else {
            return false
        }

        if mode == .edit {
            return true
        }

        return !PreviewOverlayFinderInteractionPolicy.isFinderDriven(source)
    }
}

enum PreviewOverlayFocusActivationPolicy {
    static func shouldFocusOnPresentation(
        mode: PreviewSessionMode?,
        renderType: FileRenderType?,
        source: PreviewLaunchSource?
    ) -> Bool {
        mode == .preview &&
        renderType != nil &&
        !PreviewOverlayFinderInteractionPolicy.isFinderDriven(source)
    }

    static func shouldActivateAppOnPresentation(
        mode: PreviewSessionMode?,
        renderType: FileRenderType?,
        source: PreviewLaunchSource?
    ) -> Bool {
        shouldFocusOnPresentation(mode: mode, renderType: renderType, source: source)
    }
}

enum PreviewOverlayKeyboardRoutingPolicy {
    private static func isFinderNavigationKey(_ keyCode: UInt16?) -> Bool {
        keyCode == 125 || keyCode == 126
    }

    static func shouldForwardFinderNavigation(
        isVisible: Bool,
        isEditing: Bool,
        followsFinderSelection: Bool,
        finderNavigationForwardingEnabled: Bool = false,
        frontmostBundleIdentifier: String?,
        keyCode: UInt16?
    ) -> Bool {
        isVisible &&
        !isEditing &&
        followsFinderSelection &&
        finderNavigationForwardingEnabled &&
        frontmostBundleIdentifier == "com.apple.finder" &&
        isFinderNavigationKey(keyCode)
    }
}

enum PreviewOverlayFinderNavigationRefreshPolicy {
    private static func isFinderNavigationKey(_ keyCode: UInt16?) -> Bool {
        keyCode == 125 || keyCode == 126
    }

    static func shouldRefreshAfterFinderNavigation(
        isVisible: Bool,
        isEditing: Bool,
        followsFinderSelection: Bool,
        frontmostBundleIdentifier: String?,
        keyCode: UInt16?
    ) -> Bool {
        isVisible &&
        !isEditing &&
        followsFinderSelection &&
        frontmostBundleIdentifier == "com.apple.finder" &&
        isFinderNavigationKey(keyCode)
    }
}

enum PreviewOverlayFinderSelectionEventRefreshPolicy {
    private static func isFinderNavigationKey(_ keyCode: UInt16?) -> Bool {
        keyCode == 125 || keyCode == 126
    }

    static func shouldRefreshAfterFinderSelectionEvent(
        isVisible: Bool,
        isEditing: Bool,
        followsFinderSelection: Bool,
        frontmostBundleIdentifier: String?,
        frontmostAppFallbackBundleIdentifier: String? = nil,
        eventType: NSEvent.EventType,
        keyCode: UInt16?
    ) -> Bool {
        guard isVisible,
              !isEditing,
              followsFinderSelection,
              frontmostBundleIdentifier == nil ||
              frontmostBundleIdentifier == "com.apple.finder" ||
              frontmostBundleIdentifier == frontmostAppFallbackBundleIdentifier else {
            return false
        }

        switch eventType {
        case .keyDown:
            return isFinderNavigationKey(keyCode)
        case .leftMouseUp:
            return true
        default:
            return false
        }
    }
}

enum PreviewOverlayInternalNavigationDirection: Equatable {
    case previous
    case next
}

enum PreviewOverlayInternalNavigationKeyPolicy {
    static func direction(
        isVisible: Bool,
        isEditing: Bool,
        followsFinderSelection: Bool,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> PreviewOverlayInternalNavigationDirection? {
        guard isVisible,
              !isEditing,
              !followsFinderSelection,
              modifierFlags.intersection([.command, .option, .control]).isEmpty else {
            return nil
        }

        switch keyCode {
        case 126:
            return .previous
        case 125:
            return .next
        default:
            return nil
        }
    }
}

enum PreviewOverlayResizeAnimationPolicy {
    static func shouldAnimateResize(
        previous: PreviewSessionState?,
        current: PreviewSessionState
    ) -> Bool {
        guard let previous else {
            return false
        }
        guard previous.target?.resolvedPath == current.target?.resolvedPath,
              previous.displayRenderType == current.displayRenderType else {
            return false
        }

        return previous.isExpanded != current.isExpanded
    }
}

enum PreviewOverlayFrameAnimationPlan: Equatable {
    case immediate
    case explicit(duration: TimeInterval)
}

enum PreviewOverlayFrameAnimationPolicy {
    static func plan(animated: Bool) -> PreviewOverlayFrameAnimationPlan {
        animated ? .explicit(duration: 0.22) : .immediate
    }
}

enum PreviewOverlayInternalNavigationRequestPolicy {
    static func request(
        direction: PreviewOverlayInternalNavigationDirection,
        context: PreviewNavigationContext?
    ) -> PreviewLaunchRequest? {
        let path: String?
        switch direction {
        case .previous:
            path = context?.previousPath
        case .next:
            path = context?.nextPath
        }

        guard let path else {
            return nil
        }

        return .openPath(path, source: .internalNavigation)
    }
}

enum PreviewOverlaySizingPolicy {
    static let compactContentSize = CGSize(width: 450, height: 320)

    static func usesCompactPresentation(
        renderType: FileRenderType?,
        errorMessage: String?
    ) -> Bool {
        renderType == .unsupported || errorMessage != nil
    }

    static func contentWidth(
        renderType: FileRenderType?,
        filePath: String?,
        isExpanded: Bool,
        screenVisibleFrame: NSRect
    ) -> CGFloat {
        let fileExtension = filePath.map { URL(fileURLWithPath: $0).pathExtension.lowercased() }
        let widthRatio = widthRatio(
            for: renderType,
            fileExtension: fileExtension,
            isExpanded: isExpanded
        )
        return screenVisibleFrame.width * widthRatio
    }

    static func widthRatio(
        for renderType: FileRenderType?,
        fileExtension: String?,
        isExpanded: Bool
    ) -> CGFloat {
        guard renderType == .office else {
            return isExpanded ? 0.68 : 0.38
        }

        switch fileExtension {
        case "doc", "docx", "rtf", "rtfd", "pages":
            return isExpanded ? 0.56 : 0.34
        case "xls", "xlsx", "numbers", "csv":
            return isExpanded ? 0.82 : 0.72
        case "ppt", "pptx", "key":
            return isExpanded ? 0.78 : 0.66
        default:
            return isExpanded ? 0.56 : 0.36
        }
    }

    static func stableContentSize(
        renderType: FileRenderType?,
        filePath: String?,
        isExpanded: Bool,
        errorMessage: String?,
        screenVisibleFrame: NSRect
    ) -> CGSize {
        if usesCompactPresentation(renderType: renderType, errorMessage: errorMessage) {
            return compactContentSize
        }

        return CGSize(
            width: contentWidth(
                renderType: renderType,
                filePath: filePath,
                isExpanded: isExpanded,
                screenVisibleFrame: screenVisibleFrame
            ),
            height: screenVisibleFrame.height * 0.88
        )
    }

    static func animationSourceRect(
        _ sourceRect: CGRect,
        outset: CGFloat
    ) -> CGRect {
        sourceRect.insetBy(dx: -outset, dy: -outset)
    }
}

class QuickLookOverlay: NSObject, NSWindowDelegate {
    static let shared = QuickLookOverlay()

    private let stableCardOuterPadding: CGFloat = 0
    private let animationOutset: CGFloat = 40
    private let finderSelectionRefreshBurstDelays: [TimeInterval] = [0.05, 0.12, 0.24]
    var finderSelectionPathProvider: any FinderSelectionPathProviding = AppleScriptFinderSelectionPathProvider()
    var onFinderSelectionRequest: ((PreviewLaunchRequest) -> Void)?
    private var previewWindow: NSWindow?
    var currentWindow: NSWindow? { previewWindow }
    private var sourceRectBackup: CGRect?
    private var activeToastPanel: NSPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var activeSession: PreviewSession?
    private var activeSessionState: PreviewSessionState?
    private var activeSessionCancellable: AnyCancellable?
    private var navigationContext: PreviewNavigationContext?
    private var navigationContextPath: String?
    private var transitionGate = PreviewOverlayTransitionGate()
    private let loadState = PreviewLoadState()
    private lazy var windowActions = PreviewWindowActions(
        closeOverlay: { [weak self] in
            self?.closeWithAnimation()
        },
        focusWindowForEdit: { [weak self] in
            self?.focusWindowForEdit()
        },
        focusWindowForPreview: { [weak self] in
            self?.focusWindowForPreview()
        },
        unfocusWindowToFinder: { [weak self] in
            self?.unfocusWindowToFinder()
        },
        showToast: { [weak self] message, icon in
            self?.showToast(message: message, icon: icon)
        },
        currentWindow: { [weak self] in
            self?.currentWindow
        }
    )
    private lazy var finderSelectionPollingController = FinderSelectionPollingController(
        timerFactory: { interval, tick in
            PollingBridgeTimer(interval: interval, tick: tick)
        },
        frontmostBundleIdentifier: {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        },
        detectSelectionPath: { [weak self] in
            self?.finderSelectionPollingSelectionPathResult()
                ?? AppleScriptFinderSelectionPathProvider().selectedPath().mapError { $0 as any Error }
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

    func finderSelectionPollingSelectionPathResult() -> Result<String, any Error> {
        finderSelectionPathProvider.selectedPath().mapError { $0 as any Error }
    }

    var canBecomeKeyDynamic: Bool {
        PreviewOverlayKeyWindowPolicy.canBecomeKey(
            mode: activeSessionState?.mode,
            renderType: activeSessionState?.displayRenderType,
            source: activeSessionState?.source
        )
    }

    private var isEditingDynamic: Bool {
        activeSessionState?.mode == .edit
    }
    
    func focusWindowForEdit() {
        guard let window = previewWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func focusWindowForPreview() {
        guard let window = previewWindow else { return }
        guard !PreviewOverlayFinderInteractionPolicy.isFinderDriven(activeSessionState?.source) else {
            window.orderFrontRegardless()
            unfocusWindowToFinder()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func focusWindowForInteractivePreviewIfNeeded() {
        guard PreviewOverlayFocusActivationPolicy.shouldFocusOnPresentation(
            mode: activeSessionState?.mode,
            renderType: activeSessionState?.displayRenderType,
            source: activeSessionState?.source
        ), let window = previewWindow else {
            return
        }

        if PreviewOverlayFocusActivationPolicy.shouldActivateAppOnPresentation(
            mode: activeSessionState?.mode,
            renderType: activeSessionState?.displayRenderType,
            source: activeSessionState?.source
        ) {
            NSApp.activate(ignoringOtherApps: true)
        }
        window.makeKeyAndOrderFront(nil)
    }
    
    func unfocusWindowToFinder() {
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            finderApp.activate(options: [.activateIgnoringOtherApps])
        }
    }

    /// 动态刷新已打开窗口的外观模式，并更新首帧的 layer 背景底色
    func updateAppearance() {
        guard let window = previewWindow else { return }
        
        switch Settings.shared.themeMode {
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        case .system:
            window.appearance = nil
        }
        
        if let layer = window.contentView?.layer {
            layer.backgroundColor = NSColor.clear.cgColor
        }
    }

    private override init() {
        super.init()
    }

    private func dispatchFinderSelectionRequest(_ request: PreviewLaunchRequest) {
        guard PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(
            for: activeSessionState?.source
        ) else {
            return
        }

        Task { @MainActor in
            onFinderSelectionRequest?(request)
        }
    }

    private func dispatchPreviewLaunchRequest(_ request: PreviewLaunchRequest) {
        Task { @MainActor in
            onFinderSelectionRequest?(request)
        }
    }

    private func refreshNavigationContext(for path: String?) {
        guard navigationContextPath != path else {
            return
        }

        navigationContextPath = path
        guard let path else {
            navigationContext = nil
            return
        }

        navigationContext = PreviewNavigationContextBuilder.build(currentPath: path)
    }

    private func handleInternalNavigationIfNeeded(for event: NSEvent) -> Bool {
        let followsFinderSelection = PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(
            for: activeSessionState?.source
        )
        guard let direction = PreviewOverlayInternalNavigationKeyPolicy.direction(
            isVisible: isVisible,
            isEditing: isEditingDynamic,
            followsFinderSelection: followsFinderSelection,
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) else {
            return false
        }

        guard let request = PreviewOverlayInternalNavigationRequestPolicy.request(
            direction: direction,
            context: navigationContext
        ) else {
            return false
        }

        dispatchPreviewLaunchRequest(request)
        return true
    }

    private func refreshAfterFinderSelectionEventIfNeeded(
        for event: NSEvent,
        frontmostAppFallbackBundleIdentifier: String? = nil
    ) -> Bool {
        let keyCode = Self.forwardedFinderNavigationKeyCode(for: event)
        let followsFinderSelection = PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(
            for: activeSessionState?.source
        )
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        guard PreviewOverlayFinderSelectionEventRefreshPolicy.shouldRefreshAfterFinderSelectionEvent(
            isVisible: isVisible,
            isEditing: isEditingDynamic,
            followsFinderSelection: followsFinderSelection,
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            frontmostAppFallbackBundleIdentifier: frontmostAppFallbackBundleIdentifier,
            eventType: event.type,
            keyCode: keyCode
        ) else {
            return false
        }

        finderSelectionPollingController.refreshBurst(
            delays: finderSelectionRefreshBurstDelays,
            allowsUnknownFrontmost: true,
            additionalAllowedFrontmostBundleIdentifiers: Set(
                [frontmostAppFallbackBundleIdentifier].compactMap { $0 }
            ),
            schedule: { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
        )
        return true
    }

    private func refreshAfterFinderNavigationIfNeeded(for event: NSEvent) -> Bool {
        refreshAfterFinderSelectionEventIfNeeded(for: event)
    }

    private func forwardFinderNavigationIfNeeded(for event: NSEvent) -> Bool {
        let keyCode = Self.forwardedFinderNavigationKeyCode(for: event)
        let followsFinderSelection = PreviewOverlayFinderFollowPolicy.shouldFollowFinderSelection(
                for: activeSessionState?.source
        )
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        guard PreviewOverlayKeyboardRoutingPolicy.shouldForwardFinderNavigation(
            isVisible: isVisible,
            isEditing: isEditingDynamic,
            followsFinderSelection: followsFinderSelection,
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            keyCode: keyCode
        ), let keyCode else {
            return false
        }

        sendKeyToFinder(keyCode: keyCode)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.dispatchFinderSelectionRequest(.refreshFinderSelection())
        }
        return true
    }
    
    @MainActor
    private func handleStateChange() {
        refreshNavigationContext(for: currentFilePath)
        resizeWindowIfNeeded(animated: false)
    }

    @MainActor
    private func handleStateChange(previousState: PreviewSessionState?) {
        refreshNavigationContext(for: currentFilePath)
        let shouldAnimateResize = PreviewOverlayResizeAnimationPolicy.shouldAnimateResize(
            previous: previousState,
            current: activeSessionState ?? .initial
        )
        resizeWindowIfNeeded(animated: shouldAnimateResize)
    }

    @MainActor
    private func resizeWindowIfNeeded(animated: Bool) {
        guard let window = previewWindow else {
            return
        }

        let newFrame = targetWindowFrame(for: window)
        let currentFrame = window.frame

        if abs(currentFrame.width - newFrame.width) < 1.0 && abs(currentFrame.height - newFrame.height) < 1.0 {
            return
        }

        switch PreviewOverlayFrameAnimationPolicy.plan(animated: animated) {
        case .immediate:
            window.setFrame(newFrame, display: true, animate: false)
        case .explicit(let duration):
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        }
    }

    private func targetWindowFrame(for window: NSWindow) -> NSRect {
        let screenVisibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let contentRect = targetContentRect(for: screenVisibleFrame)
        let frameRect = window.frameRect(forContentRect: contentRect)

        return NSRect(
            x: screenVisibleFrame.midX - frameRect.width / 2,
            y: screenVisibleFrame.midY - frameRect.height / 2,
            width: frameRect.width,
            height: frameRect.height
        )
    }

    private func targetContentRect(for screenVisibleFrame: NSRect) -> NSRect {
        let size = PreviewOverlaySizingPolicy.stableContentSize(
            renderType: currentRenderType,
            filePath: currentFilePath,
            isExpanded: isExpanded,
            errorMessage: currentErrorMessage,
            screenVisibleFrame: screenVisibleFrame
        )

        return NSRect(origin: .zero, size: size)
    }

    private var currentRenderType: FileRenderType? {
        activeSessionState?.displayRenderType
    }

    private var currentFilePath: String? {
        activeSessionState?.target?.resolvedPath
    }

    private var currentErrorMessage: String? {
        activeSessionState?.errorMessage
    }

    private var isExpanded: Bool {
        activeSessionState?.isExpanded == true
    }

    @MainActor
    private func bindActiveSession(_ session: PreviewSession) {
        activeSession = session
        activeSessionState = session.state
        activeSessionCancellable = nil
        refreshNavigationContext(for: session.state.target?.resolvedPath)

        activeSessionCancellable = session.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                let previousState = self.activeSessionState
                self.activeSessionState = newState
                self.handleStateChange(previousState: previousState)
                self.updateWindowTitle()
            }
    }

    private func updateWindowTitle() {
        guard let window = previewWindow else { return }

        if let displayName = activeSessionState?.target?.displayName {
            window.title = "Quick Cookies - \(displayName)"
        } else if let path = currentFilePath {
            window.title = "Quick Cookies - \(URL(fileURLWithPath: path).lastPathComponent)"
        } else {
            window.title = "QuickCookies"
        }
    }

    /// 显示窗口级 Toast 提示。
    func showToast(message: String, icon: String? = nil) {
        let block = { [weak self] in
            guard let self = self else { return }
            
            // 1. 如果有正在显示的 Toast，先关闭并清理
            if let oldPanel = self.activeToastPanel {
                oldPanel.close()
                self.activeToastPanel = nil
            }
            
            // 2. 创建 Toast 专用的 Panel
            let panel = ToastPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 50),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver  // 顶级屏保层级，确保显示在最前且合适
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isReleasedWhenClosed = false
            
            let toastView = NSHostingView(
                rootView: ToastView(message: message, icon: icon)
                    .frame(width: 320, height: 50, alignment: .center)
            )
            toastView.wantsLayer = true // 必须启用 Layer 渲染
            panel.contentView = toastView
            
            // 3. 计算屏幕顶部中心位置
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - 160
                let y = screenFrame.maxY - 80
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                panel.center()
            }
            
            // 4. 保存强引用，防止被 ARC 提前释放
            self.activeToastPanel = panel
            
            // 5. 即使在后台也强制在前台渲染，且绝对不抢占焦点
            panel.orderFrontRegardless()
            
            // 6. 3秒后自动关闭
            let currentPanel = panel
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if self.activeToastPanel === currentPanel {
                    currentPanel.close()
                    self.activeToastPanel = nil
                }
            }
        }
        
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    func captureFinderSourceRect() {
        sourceRectBackup = Self.getSourceRect()
    }

    @MainActor
    func present(session: PreviewSession) {
        guard transitionGate.phase != .closing else {
            return
        }

        let previousSession = activeSession
        let plan = PreviewOverlayPresentationPlanner.plan(
            hasExistingWindow: previewWindow != nil,
            existingSession: previousSession,
            incomingSession: session
        )

        if plan.shouldCreateWindow {
            close()
        }

        bindActiveSession(session)
        finderSelectionPollingController.syncCurrentResolvedPath(session.state.target?.resolvedPath)
        sourceRectBackup = Self.getSourceRect()

        if plan.shouldCreateWindow {
            showOverlay(session: session)
        } else if plan.shouldReplaceRootView,
                  let hostingView = previewWindow?.contentView as? NSHostingView<ContentView> {
            hostingView.rootView = ContentView(
                session: session,
                loadState: loadState,
                windowActions: windowActions,
                cardOuterPadding: stableCardOuterPadding
            )
        }

        resizeWindowIfNeeded(animated: false)
        updateWindowTitle()
        focusWindowForInteractivePreviewIfNeeded()
    }

    /// 创建预览面板并执行动画，不带任何黑色背景遮罩 - 极速响应版
    @MainActor
    private func showOverlay(session: PreviewSession) {
        guard transitionGate.beginOpen() else {
            return
        }

        let target = session.state.target
        let filePath = target?.resolvedPath

        // 2. 瞬间在主线程实例化窗口并展现 (borderless 极简自研控制按钮模式)
        let previewPanel = QuickLookPanel(
            contentRect: .zero,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        let targetRect = targetWindowFrame(for: previewPanel)
        previewPanel.setFrame(targetRect, display: false)
        
        previewPanel.isMovableByWindowBackground = true
        if let displayName = target?.displayName {
            previewPanel.title = "Quick Cookies - \(displayName)"
        } else if let path = filePath {
            previewPanel.title = "Quick Cookies - \(URL(fileURLWithPath: path).lastPathComponent)"
        } else {
            previewPanel.title = "QuickCookies"
        }
        previewPanel.level = .modalPanel
        previewPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        previewPanel.isFloatingPanel = true
        previewPanel.hidesOnDeactivate = false
        
        // 融于底色的一体化毛玻璃/纯色配置
        previewPanel.backgroundColor = .clear
        previewPanel.isOpaque = false
        previewPanel.hasShadow = PreviewOverlayWindowChromePolicy.usesSystemWindowShadow
        previewPanel.isReleasedWhenClosed = false
        previewPanel.delegate = self
        previewPanel.canBecomeKeyProvider = { [weak self] in
            self?.canBecomeKeyDynamic ?? false
        }

        // SwiftUI 内容视图，传入会话与文本加载状态
        let contentView = ContentView(
            session: session,
            loadState: loadState,
            windowActions: windowActions,
            cardOuterPadding: stableCardOuterPadding
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: targetRect.size)
        previewPanel.contentView = hostingView
        previewPanel.contentView?.wantsLayer = true
        previewPanel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        
        hostingView.wantsLayer = true
        if let layer = hostingView.layer {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)
            // 外层只负责透明圆角裁切，具体玻璃/描边/阴影仍由 SwiftUI 卡片绘制。
            layer.backgroundColor = NSColor.clear.cgColor
            layer.cornerRadius = 20
            layer.masksToBounds = true
        }

        // 先以透明状态挂载，随后由 presentation focus policy 决定是否成为 key window。
        previewPanel.alphaValue = 0.0
        previewPanel.orderFrontRegardless()
        self.previewWindow = previewPanel
        self.updateAppearance()

        // 1. 注册本地键盘事件监视器（当编辑模式下窗口成为 Key 窗口时，在此拦截按键）
        self.localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self else { return event }

            if self.handleInternalNavigationIfNeeded(for: event) {
                return nil
            }

            if self.refreshAfterFinderNavigationIfNeeded(for: event) {
                return nil
            }

            if self.forwardFinderNavigationIfNeeded(for: event) {
                return nil
            }
            return event
        }

        // 2. 注册全局事件监视器，用于在 Finder 前台时按选择事件加速刷新。
        self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            if self.refreshAfterFinderSelectionEventIfNeeded(
                for: event,
                frontmostAppFallbackBundleIdentifier: Bundle.main.bundleIdentifier
            ) {
                return
            } else if event.type == .keyDown, self.forwardFinderNavigationIfNeeded(for: event) {
                return
            }
        }

        // Finder-driven previews keep a scoped selection watcher while visible.
        // Direct-path previews avoid polling entirely.
        if PreviewOverlayFinderFollowPolicy.shouldStartSelectionPolling(for: session.state.source) {
            finderSelectionPollingController.start(
                allowsUnknownFrontmost: true,
                additionalAllowedFrontmostBundleIdentifiers: Set(
                    [Bundle.main.bundleIdentifier].compactMap { $0 }
                )
            )
        }

        // 3. 0ms 瞬间起跳：优先使用轮询预取的文件图标物理位置，若无缓存再降级到鼠标位置，保证零局限与零阻塞
        let initialSourceRect = self.sourceRectBackup ?? self.getMouseOrCenterSourceRect(targetRect: targetRect)
        self.performQuickLookAnimation(
            previewPanel: previewPanel,
            sourceRect: initialSourceRect,
            targetRect: targetRect
        )
        self.transitionGate.markOpen()

        // 4. 后台执行图标实际坐标的获取，用于关闭时精准飞回
        DispatchQueue.global(qos: .userInteractive).async {
            let realSourceRect = Self.getSourceRect()
            Task { @MainActor in
                QuickLookOverlay.shared.sourceRectBackup = realSourceRect
            }
        }
    }

    /// 获取当前鼠标位置构建的起跳起始矩形，用于 0ms 秒开无阻塞动画起点
    private func getMouseOrCenterSourceRect(targetRect: CGRect) -> CGRect {
        let mouseLoc = NSEvent.mouseLocation
        return CGRect(
            x: mouseLoc.x - 5,
            y: mouseLoc.y - 5,
            width: 10,
            height: 10
        )
    }

    /// 模拟 macOS 原生 Space (Quick Look) 的满帧 GPU 仿射变换弹簧动画 (CASpringAnimation)
    private func performQuickLookAnimation(previewPanel: NSPanel, sourceRect: CGRect, targetRect: CGRect) {
        guard let contentView = previewPanel.contentView, let layer = contentView.layer else { return }
        
        // 动画开始前先将系统红绿灯控制按钮隐藏，防止其在动画播放前突兀亮在既定位置
        previewPanel.standardWindowButton(.closeButton)?.alphaValue = 0.0
        previewPanel.standardWindowButton(.miniaturizeButton)?.alphaValue = 0.0
        previewPanel.standardWindowButton(.zoomButton)?.alphaValue = 0.0
        
        // 再次校准 anchorPoint & position，以防挂载后被 AppKit 布局重置
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)

        // 扩展 sourceRect 加上 padding 缓冲，保持仿射变换中心与起跳大小 100% 精确匹配
        let paddedSourceRect = PreviewOverlaySizingPolicy.animationSourceRect(
            sourceRect,
            outset: animationOutset
        )
        
        let scaleX = paddedSourceRect.width / targetRect.width
        let scaleY = paddedSourceRect.height / targetRect.height
        
        let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
        let sourceCenter = CGPoint(x: paddedSourceRect.midX, y: paddedSourceRect.midY)
        let translationX = sourceCenter.x - targetCenter.x
        let translationY = sourceCenter.y - targetCenter.y
        
        // 拼接初始的变换矩阵 (先 Scale 后 Translation)
        let initialTransform = CATransform3DConcat(
            CATransform3DMakeScale(scaleX, scaleY, 1.0),
            CATransform3DMakeTranslation(translationX, translationY, 0)
        )
        
        // ==========================================
        // 【核心修复】：利用原子化 CATransaction 事务保护
        //    先 add(group) 动画使呈现图层首帧即刻被动画（透明+极小）接管，
        //    并在同一个事务中将窗口透明度恢复为 1.0 呈现，由于 commit 前系统绝不重绘，
        //    因此彻底屏蔽了起跑瞬间的大卡车闪烁；同时 Model 真实值始终保持最终态，
        //    在动画播完自动移除时能够完美无缝贴合在最终态上，杜绝消失并闪现
        // ==========================================
        CATransaction.begin()
        
        // 使用物理公式驱动的 CASpringAnimation 弹簧动画 (开启过冲回弹，释放极致的原生“空气/膨胀果冻感”)
        let springTransform = CASpringAnimation(keyPath: "transform")
        springTransform.damping = 15
        springTransform.stiffness = 240
        springTransform.mass = 0.4
        springTransform.fromValue = NSValue(caTransform3D: initialTransform)
        springTransform.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        springTransform.duration = 0.38 // 0.38s 稍微拉长，呈现更饱满流畅的膨胀弹性
        
        // 透明度淡入动画
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 0.0
        fadeAnim.toValue = 1.0
        fadeAnim.duration = 0.16
        
        let group = CAAnimationGroup()
        group.animations = [springTransform, fadeAnim]
        group.duration = 0.38
        group.isRemovedOnCompletion = true // 动画播完自动从层级移除
        group.fillMode = .removed           // 移除后直接采用 Model 图层的最终态（即 1.0 和 identity），实现无缝对齐
        
        // A. 先添加动画，使其呈现图层首帧直接开始渐入与物理膨胀
        layer.add(group, forKey: "quickLookShow")
        
        // B. 此时将窗口透明度置为 1.0 呈现，由于处在同一 CA 事务中，在此 commit 前屏幕绝不重绘，因此绝不瞬闪大卡片
        previewPanel.alphaValue = 1.0
        
        CATransaction.commit()
        // ==========================================
        
        // 动画中后期渐显系统红绿灯按钮，达成呼吸感
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.12
                previewPanel.standardWindowButton(.closeButton)?.animator().alphaValue = 1.0
                previewPanel.standardWindowButton(.miniaturizeButton)?.animator().alphaValue = 1.0
                previewPanel.standardWindowButton(.zoomButton)?.animator().alphaValue = 1.0
            }, completionHandler: nil)
        }
    }

    /// 高精度获取 Finder 中当前选中项的视觉物理坐标 (AXUIElement API)
    private static func getSourceRect() -> CGRect {
        // 1. 获取 Finder 的 PID
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            return getDefaultSourceRect()
        }
        let pid = finderApp.processIdentifier
        
        // 2. 创建 Finder 应用 of AXUIElement
        let appElement = AXUIElementCreateApplication(pid)
        
        // 3. 寻找选中的 UI 元素：优先从键盘聚焦 focusedElement 获取，其次通过主窗口选中项列表 AXSelectedChildren 深度兜底遍历
        var selectedElement: AXUIElement?
        
        var focusedElementRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
           let element = focusedElementRef as! AXUIElement? {
            // 校验 role 避免把 window 当作选中项
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String {
                if role == "AXCell" || role == "AXRow" || role == "AXStaticText" || role == "AXImage" || role == "AXTextField" {
                    selectedElement = element
                }
            }
        }
        
        if selectedElement == nil {
            if let found = getSelectedElementFromWindows(appElement: appElement) {
                selectedElement = found
            }
        }
        
        guard let element = selectedElement else {
            return getDefaultSourceRect()
        }
        
        // 4. 从选中元素中读取其 Position 和 Size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        guard posResult == .success, sizeResult == .success,
              let positionVal = positionRef, let sizeVal = sizeRef else {
            return getDefaultSourceRect()
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(positionVal as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        
        // 5. 坐标系转换 (Accessibility 使用左上角为原点，NSScreen/AppKit 窗口使用左下角为原点)
        if let screenHeight = NSScreen.main?.frame.height {
            return CGRect(
                x: point.x,
                y: screenHeight - (point.y + size.height), // 转换 Y 轴
                width: size.width,
                height: size.height
            )
        }
        
        return CGRect(origin: point, size: size)
    }

    /// 安全读取 AXUIElement 的 Bool 属性，解决 Swift 中 CFBoolean 桥接为 Bool 时的不稳定问题
    private static func getBoolAttribute(_ element: AXUIElement, attribute: String) -> Bool {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success else {
            return false
        }
        if let number = valueRef as? NSNumber {
            return number.boolValue
        }
        if CFGetTypeID(valueRef!) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((valueRef as! CFBoolean))
        }
        return false
    }

    /// 从 Finder 的活动窗口检索当前被选中的 Cell 或 Row 元素
    private static func getSelectedElementFromWindows(appElement: AXUIElement) -> AXUIElement? {
        // 1. 优先使用 Finder 应用级别的 AXMainWindow 属性获取当前活跃的主窗口，避免无脑遍历所有窗口
        var mainWindowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &mainWindowRef) == .success,
           let mainWindow = mainWindowRef as! AXUIElement? {
            if let found = deepFindSelected(in: mainWindow) {
                return found
            }
        }

        // 2. 如果直接获取主窗口失败，获取所有窗口列表
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], !windows.isEmpty else {
            return nil
        }
        
        // 3. 优先在 Main (主窗口) 状态的窗口中搜寻，确保精确定位前台操作的窗口
        for window in windows {
            if getBoolAttribute(window, attribute: kAXMainAttribute) {
                if let found = deepFindSelected(in: window) {
                    return found
                }
            }
        }
        
        // 4. 其次在 Focused (聚焦) 状态的窗口中搜寻
        for window in windows {
            if getBoolAttribute(window, attribute: kAXFocusedAttribute) {
                if let found = deepFindSelected(in: window) {
                    return found
                }
            }
        }
        
        // 5. 最后的兜底：如果前台没有处于 Main 或 Focused 状态的窗口（可能是桌面操作），遍历剩下的窗口
        for window in windows {
            let isMain = getBoolAttribute(window, attribute: kAXMainAttribute)
            let isFocused = getBoolAttribute(window, attribute: kAXFocusedAttribute)
            
            // 获取窗口的 Title
            var titleRef: CFTypeRef?
            _ = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success
            let title = titleRef as? String ?? ""
            
            // 排除明确不是主窗口且不是聚焦窗口的普通有标题 Finder 窗口，防止其残留的 AXSelectedChildren 状态污染
            if !title.isEmpty && !isMain && !isFocused {
                continue
            }
            
            if let found = deepFindSelected(in: window) {
                return found
            }
        }
        return nil
    }
    
    /// 限制 10 层深度递归检索指定节点下的 AXSelectedChildren 或 AXSelectedRows 属性
    private static func deepFindSelected(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if depth > 10 { return nil }
        
        // 1. 剪枝过滤：若是绝对不包含子文件项的叶子节点，立刻返回 nil 终止向下检索，剪掉 95%+ 无用 IPC，杜绝系统熔断
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            let leafRoles: Set<String> = [
                "AXButton", "AXScrollBar",
                "AXValueIndicator", "AXCheckBox", "AXRadioButton",
                "AXPopUpButton", "AXProgressIndicator", "AXIncrementor",
                "AXSlider", "AXHelpTag"
            ]
            if leafRoles.contains(role) {
                return nil
            }
        }
        
        // 2. 检查当前节点是否存在选中子项
        var selectedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXSelectedChildren" as CFString, &selectedRef) == .success,
           let selected = selectedRef as? [AXUIElement], !selected.isEmpty {
            return selected.first
        }
        
        var selectedRowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXSelectedRows" as CFString, &selectedRowsRef) == .success,
           let selectedRows = selectedRowsRef as? [AXUIElement], !selectedRows.isEmpty {
            return selectedRows.first
        }
        
        // 3. 继续向下递归子节点
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = deepFindSelected(in: child, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }

    /// 默认源位置（屏幕中心）
    private static func getDefaultSourceRect() -> CGRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        return CGRect(
            x: screenFrame.midX - 50,
            y: screenFrame.midY - 50,
            width: 100,
            height: 100
        )
    }

    /// 关闭窗口
    func close() {
        if Thread.isMainThread {
            self.performClose()
        } else {
            DispatchQueue.main.async {
                self.performClose()
            }
        }
    }

    static func forwardedFinderNavigationKeyCode(for event: NSEvent) -> UInt16? {
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
            return nil
        }

        switch event.keyCode {
        case 125, 126:
            return event.keyCode
        default:
            return nil
        }
    }

    private func performClose() {
        // 1. 注销本地/全局键盘监视器并销毁定时器
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        finderSelectionPollingController.stop()

        // 2. 关闭并清理窗口引用
        if let window = previewWindow {
            previewWindow = nil
            window.delegate = nil
            window.contentView = nil
            window.close()
        }
        activeSession = nil
        activeSessionState = nil
        activeSessionCancellable = nil
        navigationContext = nil
        navigationContextPath = nil
        finderSelectionPollingController.resetSelection()
        transitionGate.finishClose()
        
        // 3. 激活并归还焦点给 Finder
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            finderApp.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private func sendKeyToFinder(keyCode: UInt16) {
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            return
        }
        let pid = finderApp.processIdentifier
        
        let source = CGEventSource(stateID: .combinedSessionState)
        
        if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDownEvent.postToPid(pid)
        }
        if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUpEvent.postToPid(pid)
        }
    }

    /// 关闭窗口并附带平滑缩小到图标位置的 GPU 变换动画
    func closeWithAnimation() {
        guard let window = previewWindow, let contentView = window.contentView else {
            close()
            return
        }

        guard transitionGate.beginClose() else {
            return
        }

        guard let layer = contentView.layer else {
            previewWindow = nil
            window.delegate = nil
            window.contentView = nil
            window.close()
            loadState.reset()
            navigationContext = nil
            navigationContextPath = nil
            transitionGate.finishClose()
            return
        }

        // 关闭时立刻隐藏系统红绿灯按钮，使其随着窗口收缩缩回原位而完美消失
        window.standardWindowButton(.closeButton)?.alphaValue = 0.0
        window.standardWindowButton(.miniaturizeButton)?.alphaValue = 0.0
        window.standardWindowButton(.zoomButton)?.alphaValue = 0.0

        // 立即注销键盘事件监视器并销毁定时器，防止动画期间误触发
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        finderSelectionPollingController.stop()

        // 立即激活并归还焦点给 Finder，使视觉缩小动画播放的同时焦点已经回到 Finder
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            finderApp.activate(options: [.activateIgnoringOtherApps])
        }

        // 立即解绑业务会话，避免动画期间继续消费旧 session；
        // 但保留 previewWindow 到 completion，防止 toggle 在 closing 期间误判为已关闭而重开。
        activeSession = nil
        activeSessionState = nil
        activeSessionCancellable = nil
        navigationContext = nil
        navigationContextPath = nil
        finderSelectionPollingController.resetSelection()

        let targetRect = window.frame
        let sourceRect = sourceRectBackup ?? Self.getDefaultSourceRect()
        
        // 同样在关闭时也要将 sourceRect 进行 padding 扩展以精准反向对齐
        let paddedSourceRect = PreviewOverlaySizingPolicy.animationSourceRect(
            sourceRect,
            outset: animationOutset
        )
        
        let scaleX = paddedSourceRect.width / targetRect.width
        let scaleY = paddedSourceRect.height / targetRect.height
        
        let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
        let sourceCenter = CGPoint(x: paddedSourceRect.midX, y: paddedSourceRect.midY)
        let translationX = sourceCenter.x - targetCenter.x
        let translationY = sourceCenter.y - targetCenter.y
        
        let finalTransform = CATransform3DConcat(
            CATransform3DMakeScale(scaleX, scaleY, 1.0),
            CATransform3DMakeTranslation(translationX, translationY, 0)
        )
        
        // 保证锚点为 (0.5, 0.5) 并且 position 居中，以进行高精度逆向收缩
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)

        // 使用非常平稳的缩放与淡出动画 (适当拉长到 0.20s/0.16s 提升过渡顺滑度)
        let shrinkAnim = CABasicAnimation(keyPath: "transform")
        shrinkAnim.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
        shrinkAnim.toValue = NSValue(caTransform3D: finalTransform)
        shrinkAnim.duration = 0.20
        shrinkAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0
        fadeAnim.toValue = 0.0
        fadeAnim.duration = 0.16
        fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        let group = CAAnimationGroup()
        group.animations = [shrinkAnim, fadeAnim]
        group.duration = 0.20
        group.isRemovedOnCompletion = true
        group.fillMode = .removed
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.previewWindow = nil
            window.delegate = nil
            window.orderOut(nil)
            window.contentView = nil
            window.close()
            self.activeSessionState = nil
            self.activeSessionCancellable = nil
            self.loadState.reset()
            self.transitionGate.finishClose()
        }

        // 先把 model layer 原子化地推进到最终关闭态，再由显式动画接管过渡，
        // 避免动画结束瞬间回跳到未缩放的大窗口状态而产生最后一闪。
        CATransaction.setDisableActions(true)
        layer.transform = finalTransform
        layer.opacity = 0.0

        layer.add(group, forKey: "quickLookClose")
        CATransaction.commit()
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 用户点击红点按钮或按 Cmd+W 时，采用优雅的收缩动画关闭
        closeWithAnimation()
        return false
    }

    /// 窗口是否可见
    var isVisible: Bool {
        return transitionGate.isVisibleForToggle
    }
    
}
