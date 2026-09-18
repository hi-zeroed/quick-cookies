import AppKit
import SwiftUI

@MainActor
enum PreviewCommandRouter {
    static func triggerFinderToggle(
        requestController: PreviewRequestController,
        presenter: PreviewUIPresenter,
        frontmostBundleIdentifierProvider: () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
    ) {
        requestController.toggleFromFinder(
            isOverlayVisible: presenter.isPreviewVisible,
            frontmostBundleIdentifier: frontmostBundleIdentifierProvider(),
            prepareSourceRect: {
                presenter.captureFinderSourceRect()
            },
            closeOverlay: {
                presenter.closePreviewWithAnimation()
            }
        )
    }

    static func registerPreviewHotkey(
        requestController: PreviewRequestController,
        presenter: PreviewUIPresenter
    ) {
        HotkeyManager.shared.registerWithSettings {
            AppRelayMenuTarget.shared.cancelActiveMenu()
            triggerFinderToggle(
                requestController: requestController,
                presenter: presenter
            )
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    private let finderSelectionPathProvider: any FinderSelectionPathProviding
    private var onboardingWindow: NSWindow?
    var currentOnboardingWindow: NSWindow? { onboardingWindow }
    private var didSetupNormalFlow = false
    private var notificationObservers: [NSObjectProtocol] = []
    private let previewSession = PreviewSession()
    private let previewPresenter = PreviewUIPresenter.live
    private let previewRequestController = PreviewRequestController()
    // 所有长期保留的预览入口都应汇聚到 coordinator，而不是在各入口直接拼 overlay 业务逻辑。
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
        inspectClipboard: { [weak self] in
            self?.inspectClipboard()
        },
        openShareCard: { [weak self] in
            self?.openShareCardDirectly()
        },
        showSettings: {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show()
            }
        },
        finderSelectionPathProvider: finderSelectionPathProvider
    )

    override init() {
        self.finderSelectionPathProvider = AppleScriptFinderSelectionPathProvider()
        super.init()
        AppDelegate.shared = self
    }

    init(finderSelectionPathProvider: any FinderSelectionPathProviding) {
        self.finderSelectionPathProvider = finderSelectionPathProvider
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 强制初始化 Settings 单例以加载用户偏好语言或根据系统自适应首选语言
        _ = Settings.shared

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        if !hasCompletedOnboarding {
            // 新手向导未完成，展示 Onboarding
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        } else {
            // 正常工作流
            setupNormalFlow()
        }
    }
    
    private func setupNormalFlow() {
        guard !didSetupNormalFlow else { return }
        didSetupNormalFlow = true

        installFinderSelectionPathProvider(on: QuickLookOverlay.shared)
        // 设置为后台 Agent，不显示 Dock 图标与顶部菜单栏，仅显示独立窗口
        NSApp.setActivationPolicy(.accessory)
        previewRequestController.onRequest = { [weak self] request in
            self?.handlePreviewRequest(request)
        }
        previewPresenter.setFinderSelectionRequestHandler { [previewRequestController] request in
            previewRequestController.submit(request)
        }
        installSettingsObservers()

        // 注册当前设置下的全局预览热键；默认是双击 Command，也允许用户改成普通组合键。
        PreviewCommandRouter.registerPreviewHotkey(
            requestController: previewRequestController,
            presenter: previewPresenter
        )

        // 注册剪贴板透视全局快捷键（默认 ⌃⌥V）
        HotkeyManager.shared.registerClipboardWithSettings { [weak self] in
            self?.inspectClipboard()
        }

        // 注册直接分享卡片全局快捷键（默认 ⌃⌥C）
        HotkeyManager.shared.registerShareCardWithSettings { [weak self] in
            self?.openShareCardDirectly()
        }

        // 注册 Services 菜单项
        NSApp.servicesProvider = QuickCookiesServiceProvider(
            requestController: previewRequestController,
            showToastHandler: { [weak self] message, icon in
                self?.previewPresenter.showToast(message: message, icon: icon)
            }
        )

        // 在正常工作流稳定后以低优先级预热共享 WebKit 运行时，
        // 直接装入 Markdown 可复用 shell，让首次 Markdown 打开也尽量命中
        // shell reuse，而不是只命中空白 runtime 后仍走一次 full navigation。
        //
        // 当前演进结论：
        // - 对于菜单栏常驻应用，优先保证“常驻后再打开”的热路径稳定秒开
        // - 启动后立刻第一次打开仍可能落到 cold path，这是当前刻意接受的
        //   边界场景 tradeoff
        //
        // 后续如果要继续打首轮冷启动，不要先回头抠 Markdown 分块或热路径；
        // 应优先沿着下面几条方向演进：
        // 1. 更早触发 shared WebKit prewarm
        // 2. 让 shell prewarm 与用户即将触发预览的信号更贴近
        // 3. 继续压缩 shell=nav / first navigation 的平台成本
        Task { @MainActor in
            let isDarkAppearance = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            PreviewRuntimeRegistry.shared.scheduleMarkdownPreviewShellWarmIfNeeded(
                isDarkAppearance: isDarkAppearance,
                bodyFontName: Settings.shared.editorFont,
                bodyFontSize: Settings.shared.fontSize
            )
        }

    }

    func installFinderSelectionPathProvider(on overlay: QuickLookOverlay) {
        overlay.finderSelectionPathProvider = finderSelectionPathProvider
    }
    
    func showOnboarding(reopen: Bool = false) {
        // 如果是重新打开或者旧窗口已关闭/不可见，确保重置并重新创建
        if reopen, let existingWindow = onboardingWindow {
            existingWindow.close()
            onboardingWindow = nil
        } else if let existingWindow = onboardingWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: OnboardingWindowPolicy.contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        // NOTE: 必须设为 false，否则 close() 会触发 AppKit 额外向 ARC 已管理的对象发送多一次 release，
        // 造成引用计数下溢 → EXC_BAD_ACCESS 野指针崩溃
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        
        // 隐藏标准红绿灯，呈现纯粹悬浮水晶大圆角卡片美学
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        // 监听窗口直接关闭（如点击左上角红叉），避免滞留不可用的窗口实例
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            MainActor.assumeIsolated {
                if self?.onboardingWindow === window {
                    self?.onboardingWindow = nil
                }
                self?.setupNormalFlow()
            }
        }
        
        let onboardingView = OnboardingView(onFinished: { [weak self, weak window] in
            // 写入完成新手引导标识
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            // 【死锁修复 - 四阶段分离策略】
            // 问题根源：ConfettiView/authTimer 等 Timer 仍在主线程 RunLoop 排队，
            // window.close() 触发 NSHostingView 开始 CATransaction 提交，
            // 同时 NSApp.setActivationPolicy(.accessory) 需要向事件队列派发，
            // 两者在同一 RunLoop tick 内争抢主线程 → 循环等待死锁。
            //
            // Phase 1: 立即将窗口移出屏幕（不触发 windowWillClose，不销毁视图树）
            //          SwiftUI 动画帧可以安全提交，避免渲染中断
            window?.orderOut(nil)
            
            // Phase 2: 下一个 RunLoop tick：释放 AppDelegate 的强引用
            //          此时窗口引用计数降低，但窗口对象尚未销毁（window 仍有局部引用）
            DispatchQueue.main.async {
                self?.onboardingWindow = nil
                
                // Phase 3: 再下一个 tick：调用 close() 完成窗口销毁
                //          此时 SwiftUI 视图树的 Timer/Combine 订阅均已因视图消失而休眠，
                //          CATransaction 队列已清空，close 不会再触发渲染竞争
                DispatchQueue.main.async {
                    window?.close()
                    
                    // Phase 4: 最后一个 tick：切换激活策略并启动正常工作流
                    //          window.close() 的 NSNotification 处理完毕后再切换，
                    //          确保 AppKit 内部状态机已完全离开 regular 模式
                    DispatchQueue.main.async {
                        self?.setupNormalFlow()
                    }
                }
            }
        })
        
        let hostingView = NSHostingView(rootView: onboardingView)
        window.contentView = hostingView
        
        self.onboardingWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 处理 URL Scheme 唤起事件（来自 Finder Sync 扩展）。
    ///
    /// 当前约定：
    /// - `quickcookies://preview?path=/absolute/path`
    /// - URL Scheme 始终视为 direct-path open
    /// - 不允许静默回退到 Finder-selection 语义
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, let action = URLSchemeRouter.parse(url: url) else { return }

        switch action {
        case .openShareCard(let path):
            if let path = path {
                previewRequestController.openShareCard(path, source: .urlScheme)
            } else {
                openShareCardDirectly()
            }
        case .inspectClipboard:
            inspectClipboard()
        case .openFile(let path, let line):
            previewRequestController.openPath(path, source: .urlScheme, targetLine: line)
        case .triggerFinderSelection:
            openSelectedFileFromMenuBar()
        }
    }

    @MainActor
    func inspectClipboard() {
        let sniffResult = ClipboardContentSniffer.sniff()
        if case .empty = sniffResult {
            previewPresenter.showToast(message: "Clipboard is empty".localized(), icon: "doc.on.clipboard")
            return
        }
        do {
            if case .fileURL(let path, let targetLine) = sniffResult {
                previewRequestController.openPath(path, source: .urlScheme, targetLine: targetLine)
                return
            }
            if let (filePath, _) = try ClipboardContentSniffer.materialize(result: sniffResult) {
                previewRequestController.openPath(filePath, source: .urlScheme)
            }
        } catch {
            previewPresenter.showToast(message: "Failed to read clipboard".localized(), icon: "exclamationmark.triangle")
        }
    }

    @MainActor
    func openShareCardDirectly() {
        // 1. 若当前预览浮层已经可见，直接原地切换为 Card Studio
        if previewPresenter.isPreviewVisible {
            NotificationCenter.default.post(name: .previewPresentShareCardDirectly, object: nil)
            return
        }

        // 2. 如果剪贴板有内容，优先嗅探剪贴板并直达 Card Studio
        let sniffResult = ClipboardContentSniffer.sniff()
        if case .empty = sniffResult {
            // 剪贴板为空，尝试透视 Finder 选中文件
            switch finderMenuIntegration.resolveOpenSelectedFileRequest() {
            case .request(let request):
                let cardRequest = PreviewLaunchRequest(
                    source: request.source,
                    pathIntent: request.pathIntent,
                    presentation: .shareCard
                )
                previewRequestController.submit(cardRequest)
            case .failure(let message, let icon):
                previewPresenter.showToast(message: message, icon: icon)
            }
            return
        }

        do {
            if let (filePath, _) = try ClipboardContentSniffer.materialize(result: sniffResult) {
                previewRequestController.openShareCard(filePath, source: .urlScheme)
            }
        } catch {
            previewPresenter.showToast(message: "Failed to read clipboard".localized(), icon: "exclamationmark.triangle")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
        HotkeyManager.shared.unregisterClipboardHotkey()
        HotkeyManager.shared.unregisterShareCardHotkey()
        ClipboardContentSniffer.purgeCacheDirectory()
        notificationObservers.forEach(NotificationCenter.default.removeObserver)
        notificationObservers.removeAll()
        previewRequestController.onRequest = nil
        previewPresenter.setFinderSelectionRequestHandler(nil)
        previewPresenter.closePreview()
    }

    @MainActor
    private func handlePreviewRequest(_ request: PreviewLaunchRequest) {
        // 统一入口：
        // hotkey / Services / URL Scheme 都先进入 request -> coordinator -> session，
        // overlay 只负责展示会话结果，不再承担入口分流或业务状态拼装。
        do {
            try previewCoordinator.handle(request)
        } catch let previewError as PreviewTargetError {
            if PreviewOverlayPresentationPolicy.shouldIgnoreResolutionFailure(
                currentlyVisible: previewPresenter.isPreviewVisible,
                request: request,
                error: previewError
            ) {
                return
            }
        } catch {
            // 错误态已经写回 session，这里继续展示 overlay 让用户看到结果
        }

        previewPresenter.present(session: previewSession)
    }

    @MainActor
    private func openSelectedFileFromMenuBar() {
        switch finderMenuIntegration.resolveOpenSelectedFileRequest() {
        case .request(let request):
            previewRequestController.submit(request)
        case .failure(let message, let icon):
            previewPresenter.showToast(message: message, icon: icon)
        }
    }

    private func installSettingsObservers() {
        let hotkeyObserver = NotificationCenter.default.addObserver(
            forName: .settingsHotkeyDidChange,
            object: Settings.shared,
            queue: .main
        ) { [previewRequestController, previewPresenter] _ in
            Task { @MainActor in
                PreviewCommandRouter.registerPreviewHotkey(
                    requestController: previewRequestController,
                    presenter: previewPresenter
                )
            }
        }

        let clipboardHotkeyObserver = NotificationCenter.default.addObserver(
            forName: .settingsClipboardHotkeyDidChange,
            object: Settings.shared,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                HotkeyManager.shared.registerClipboardWithSettings { [weak self] in
                    self?.inspectClipboard()
                }
            }
        }

        let shareCardHotkeyObserver = NotificationCenter.default.addObserver(
            forName: .settingsShareCardHotkeyDidChange,
            object: Settings.shared,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                HotkeyManager.shared.registerShareCardWithSettings { [weak self] in
                    self?.openShareCardDirectly()
                }
            }
        }

        let themeObserver = NotificationCenter.default.addObserver(
            forName: .settingsThemeModeDidChange,
            object: Settings.shared,
            queue: .main
        ) { [previewPresenter] _ in
            Task { @MainActor in
                previewPresenter.refreshWindowAppearance()
            }
        }

        let languageObserver = NotificationCenter.default.addObserver(
            forName: .settingsLanguageDidChange,
            object: Settings.shared,
            queue: .main
        ) { [previewPresenter] _ in
            Task { @MainActor in
                previewPresenter.refreshLocalizedTitles()
            }
        }

        notificationObservers = [hotkeyObserver, clipboardHotkeyObserver, shareCardHotkeyObserver, themeObserver, languageObserver]
    }

}

/// Services 菜单项提供者（右键菜单集成）
class QuickCookiesServiceProvider: NSObject {
    private let requestController: PreviewRequestController
    private let showToastHandler: (@MainActor (String, String?) -> Void)?

    init(requestController: PreviewRequestController, showToastHandler: (@MainActor (String, String?) -> Void)? = nil) {
        self.requestController = requestController
        self.showToastHandler = showToastHandler
    }

    /// Services 菜单项：系统调用入口
    @objc func quickCookiesService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handleServicePasteboard(pasteboard)
    }

    /// 核心服务解析逻辑
    func handleServicePasteboard(_ pasteboard: NSPasteboard) {
        // 1. 尝试作为 URL 读取
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = urls.first,
           firstURL.isFileURL {
            Task { @MainActor in
                requestController.openPath(firstURL.path, source: .service)
            }
            return
        }

        // 2. 尝试作为 Filenames (NSFilenamesPboardType) 读取
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String],
           let firstPath = filenames.first {
            Task { @MainActor in
                requestController.openPath(firstPath, source: .service)
            }
            return
        }

        // 3. 核心：读取划选的纯文本（NSStringPboardType / .string）
        let stringType = NSPasteboard.PasteboardType("NSStringPboardType")
        if let text = pasteboard.string(forType: .string) ?? pasteboard.string(forType: stringType),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let target = UniversalPathResolver.resolve(text) {
                Task { @MainActor in
                    requestController.openPath(target.fileURL.path, source: .service, targetLine: target.targetLine)
                }
                return
            }
        }

        // 4. 未能找到有效本地路径时，温和弹出 Toast 提示
        Task { @MainActor in
            showToastHandler?("No valid file path found".localized(), "questionmark.folder")
        }
    }
}
