import SwiftUI
import AppKit

/// 自定义 NSPanel 子类，允许 borderless 无标题栏窗口接收键盘焦点和快捷键事件
class QuickLookPanel: NSPanel {
    override var canBecomeKey: Bool {
        return QuickLookOverlay.shared.canBecomeKeyDynamic
    }
    
    override var canBecomeMain: Bool {
        return QuickLookOverlay.shared.canBecomeKeyDynamic
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

class QuickLookOverlay: NSObject, NSWindowDelegate {
    static let shared = QuickLookOverlay()

    private let windowPadding: CGFloat = 40
    private var previewWindow: NSWindow?
    var currentWindow: NSWindow? { previewWindow }
    private var sourceRectBackup: CGRect?
    private var activeToastPanel: NSPanel?
    private var lastDiagnosticMessage: String = ""
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var pollingTimer: Timer?
    
    // 用于通知 ContentView 状态的共享模型
    private let previewState = PreviewState()

    var canBecomeKeyDynamic: Bool {
        return previewState.mode == .edit
    }
    
    func focusWindowForEdit() {
        guard let window = previewWindow else { return }
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
        previewState.onStateChanged = { [weak self] in
            self?.handleStateChange()
        }
    }
    
    private func handleStateChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isUnsupported = self.previewState.renderType == .unsupported
            let isError = self.previewState.errorMessage != nil
            
            if isUnsupported || isError {
                self.resizeWindowForErrorOrUnsupported()
            } else {
                self.resizeWindowForSupported()
            }
        }
    }
    
    private func resizeWindowForErrorOrUnsupported() {
        guard let window = previewWindow else {
            return
        }
        
        // 强制重置 isExpanded，防范未缩回状态
        if previewState.isExpanded {
            previewState.isExpanded = false
        }
        
        // 计算目标内容区 450x320（加上 padding 缓冲）对应的窗口物理 Frame 大小
        let contentRect = NSRect(x: 0, y: 0, width: 450 + windowPadding * 2, height: 320 + windowPadding * 2)
        let frameRect = window.frameRect(forContentRect: contentRect)
        let targetWidth = frameRect.width
        let targetHeight = frameRect.height
        
        let currentFrame = window.frame
        
        // 如果物理尺寸已完全匹配，直接返回，绝不执行二次 setFrame 动画
        if abs(currentFrame.width - targetWidth) < 1.0 && abs(currentFrame.height - targetHeight) < 1.0 {
            return
        }
        
        let screenVisibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let newFrame = NSRect(
            x: screenVisibleFrame.midX - targetWidth / 2,
            y: screenVisibleFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        
        window.setFrame(newFrame, display: true, animate: true)
    }

    private func resizeWindowForSupported() {
        guard let window = previewWindow else {
            return
        }
        let screenVisibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // 依据 isExpanded（true 为 68%，false 为 38%）平滑变换宽度
        let widthRatio = previewState.isExpanded ? 0.68 : 0.38
        let contentWidth = screenVisibleFrame.width * widthRatio
        let contentHeight = screenVisibleFrame.height * 0.88
        
        // 计算加上 padding 缓冲对应的窗口物理 Frame 大小
        let contentRect = NSRect(x: 0, y: 0, width: contentWidth + windowPadding * 2, height: contentHeight + windowPadding * 2)
        let frameRect = window.frameRect(forContentRect: contentRect)
        let targetWidth = frameRect.width
        let targetHeight = frameRect.height
        
        let currentFrame = window.frame
        
        if abs(currentFrame.width - targetWidth) < 1.0 && abs(currentFrame.height - targetHeight) < 1.0 {
            return
        }
        
        let newFrame = NSRect(
            x: screenVisibleFrame.midX - targetWidth / 2,
            y: screenVisibleFrame.midY - targetHeight / 2,
            width: targetWidth,
            height: targetHeight
        )
        
        window.setFrame(newFrame, display: true, animate: true)
    }

    /// 显示 Toast 提示（合并自 PreviewWindowController）
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

    /// 从 Finder 触发预览（双击 Option 或 Services 菜单）
    func showFromFinder() {
        // 1. 如果预览窗口已经打开且可见，按快捷键应快速关闭 (Toggle 关闭豁免前台 Finder 限制)
        if let window = previewWindow, window.isVisible {
            closeWithAnimation()
            return
        }

        // 2. 增加前台应用校验：仅当前台活跃应用为 Finder (com.apple.finder) 时才响应快捷键拉起新预览
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "com.apple.finder" else {
            return
        }

        // 3. 尝试同步获取当前 Finder 选中文件路径（一般耗时很低，~5-15ms），以防不支持文件先大后小
        var detectedPath: String? = nil
        let result = FileDetector.getSelectedFilePath()
        switch result {
        case .success(let path):
            detectedPath = FileUtils.resolveSymlink(at: path)
        case .failure:
            break
        }

        // 瞬间弹框
        show(filePath: detectedPath)
    }

    /// 显示预览窗口（Quick Look 动画） - 秒开重构版
    func show(filePath: String?) {
        if let path = filePath {
            let resolvedPath = FileUtils.resolveSymlink(at: path)
            let renderType = FileTypeClassifier.classify(path: resolvedPath)
            let language = FileTypeClassifier.getLanguageName(path: resolvedPath)

            showOverlay(
                filePath: resolvedPath,
                renderType: renderType,
                language: language
            )
        } else {
            // 没有已知路径，说明是从 Finder 触发，我们需要异步探测
            showOverlay(
                filePath: nil,
                renderType: nil,
                language: nil
            )
        }
    }

    /// 创建预览面板并执行动画，不带任何黑色背景遮罩 - 极速响应版
    private func showOverlay(filePath: String?, renderType: FileRenderType?, language: String?) {
        // 关闭旧窗口
        close()

        // 1. 瞬间确定窗口比例（若已知为不支持类型，则使用较矮的原生 Quick Look 风格卡片尺寸，加上 padding 缓冲）
        let screenVisibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let isUnsupported = renderType == .unsupported
        
        let windowWidth: CGFloat
        let windowHeight: CGFloat
        if isUnsupported {
            windowWidth = 450 + windowPadding * 2
            windowHeight = 320 + windowPadding * 2
        } else {
            windowWidth = screenVisibleFrame.width * 0.38 + windowPadding * 2
            windowHeight = screenVisibleFrame.height * 0.88 + windowPadding * 2
        }
        
        let targetRect = NSRect(
            x: screenVisibleFrame.midX - windowWidth / 2,
            y: screenVisibleFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        // 2. 瞬间在主线程实例化窗口并展现 (borderless 极简自研控制按钮模式)
        let previewPanel = QuickLookPanel(
            contentRect: targetRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        previewPanel.isMovableByWindowBackground = true
        if let path = filePath {
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
        previewPanel.hasShadow = false
        previewPanel.isReleasedWhenClosed = false
        previewPanel.delegate = self

        // 重置状态并在已知路径时原子化更新，防范多余重绘
        previewState.reset()
        if let path = filePath {
            previewState.updateState(
                filePath: path,
                renderType: renderType,
                language: language,
                isLoadingPath: false
            )
        } else {
            previewState.updateState(
                filePath: nil,
                renderType: nil,
                language: nil,
                isLoadingPath: true
            )
        }

        // SwiftUI 内容视图，传入共享 state
        let contentView = ContentView(state: previewState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = targetRect
        previewPanel.contentView = hostingView
        
        hostingView.wantsLayer = true
        if let layer = hostingView.layer {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)
            // layer 自身保持透明且不剪切，由 SwiftUI 内部卡片渲染圆角和背景
            layer.backgroundColor = NSColor.clear.cgColor
            layer.cornerRadius = 0
            layer.masksToBounds = false
        }

        // 先让预览窗口以极透明状态挂载，置顶显示但不抢占焦点（保持 Finder 在前台）
        previewPanel.alphaValue = 0.01
        previewPanel.orderFrontRegardless()
        self.previewWindow = previewPanel
        self.updateAppearance()

        // 1. 注册本地键盘事件监视器（当编辑模式下窗口成为 Key 窗口时，在此拦截按键）
        self.localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self else { return event }
            let keyCode = event.keyCode
            
            // Esc 键处理
            if keyCode == 53 {
                if self.previewState.mode == .edit {
                    // 编辑模式下按 Esc 则是返回预览模式，并交还焦点给 Finder
                    self.previewState.mode = .preview
                    self.unfocusWindowToFinder()
                } else {
                    // 预览模式下按 Esc 为优雅关闭窗口
                    self.closeWithAnimation()
                }
                return nil
            }
            return event
        }

        // 2. 注册全局键盘事件监视器，用于在焦点在 Finder 时捕获 Esc 键以流畅飞回收缩关闭
        self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.isVisible,
               self.previewState.mode == .preview,
               let frontApp = NSWorkspace.shared.frontmostApplication,
               frontApp.bundleIdentifier == "com.apple.finder",
               event.keyCode == 53 {
                DispatchQueue.main.async {
                    self.closeWithAnimation()
                }
            }
        }

        // 3. 启动 150ms 周期定时监测，利用高性能 NSAppleScript 内存级实时拉取选中项变化
        self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.updatePreviewFromFinder()
        }

        // 3. 0ms 瞬间起跳：获取鼠标位置作为打开时的初始起跳点，保证无阻塞，体验丝滑
        let initialSourceRect = self.getMouseOrCenterSourceRect(targetRect: targetRect)
        self.performQuickLookAnimation(
            previewPanel: previewPanel,
            sourceRect: initialSourceRect,
            targetRect: targetRect
        )

        // 4. 后台执行文件路径和图标实际坐标的获取
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // a. 异步获取真实物理坐标（用于关闭时收缩飞回）
            let realSourceRect = self.getSourceRect()
            
            // b. 如果 filePath 为 nil，异步从 Finder 中获取文件路径
            var pathResult: Result<String, FileDetector.DetectError>? = nil
            if filePath == nil {
                pathResult = FileDetector.getSelectedFilePath()
            }
            
            // c. 回到主线程更新状态
            DispatchQueue.main.async {
                // 保存真实物理坐标
                self.sourceRectBackup = realSourceRect
                
                if let result = pathResult {
                    switch result {
                    case .success(let detectedPath):
                        let resolvedPath = FileUtils.resolveSymlink(at: detectedPath)
                        if !FileTypeClassifier.isSupported(path: resolvedPath) {
                            self.previewState.errorMessage = "\("不支持的文件类型".localized()): \(URL(fileURLWithPath: resolvedPath).lastPathComponent)"
                            self.previewState.renderType = .unsupported
                            self.previewState.isLoadingPath = false
                        } else {
                            let rType = FileTypeClassifier.classify(path: resolvedPath)
                            let lang = FileTypeClassifier.getLanguageName(path: resolvedPath)
                            
                            // 更新窗口标题
                            previewPanel.title = "Quick Cookies - \(URL(fileURLWithPath: resolvedPath).lastPathComponent)"
                            
                            // 更新状态触发 ContentView 异步加载文件内容
                            self.previewState.filePath = resolvedPath
                            self.previewState.renderType = rType
                            self.previewState.language = lang
                            self.previewState.isLoadingPath = false
                        }
                    case .failure(let error):
                        self.previewState.errorMessage = (error.errorDescription ?? "未检测到选中文件").localized()
                        self.previewState.isLoadingPath = false
                    }
                }
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
        let paddedSourceRect = sourceRect.insetBy(dx: -windowPadding, dy: -windowPadding)
        
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
        
        // 窗口本身的透明度直接置为 1.0 呈现
        previewPanel.alphaValue = 1.0

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
        group.fillMode = .removed           // 移除后自动采用模型图层的真实属性值（即最终态）
        
        CATransaction.begin()
        layer.add(group, forKey: "quickLookShow")
        CATransaction.commit()
        
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
    private func getSourceRect() -> CGRect {
        lastDiagnosticMessage = ""
        
        // 1. 如果没有辅助功能权限，直接优雅降级到当前鼠标位置，消除权限阻断
        if !HotkeyManager.shared.checkAccessibilityPermission() {
            let mouseLoc = NSEvent.mouseLocation
            lastDiagnosticMessage = "免授权降级".localized()
            return CGRect(
                x: mouseLoc.x - 16,
                y: mouseLoc.y - 16,
                width: 32,
                height: 32
            )
        }
        
        // 2. 获取 Finder 的 PID
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            lastDiagnosticMessage = "Finder PID 失败".localized()
            return getDefaultSourceRect()
        }
        let pid = finderApp.processIdentifier
        
        // 2. 创建 Finder 应用 of AXUIElement
        let appElement = AXUIElementCreateApplication(pid)
        
        // 3. 寻找选中的 UI 元素：优先从键盘聚焦 focusedElement 获取，其次通过主窗口选中项列表 AXSelectedChildren 深度兜底遍历
        var selectedElement: AXUIElement?
        var diagnosticSource = "默认中心".localized()
        
        var focusedElementRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
           let element = focusedElementRef as! AXUIElement? {
            // 校验 role 避免把 window 当作选中项
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String {
                if role == "AXCell" || role == "AXRow" || role == "AXStaticText" || role == "AXImage" || role == "AXTextField" {
                    selectedElement = element
                    diagnosticSource = "\("聚焦".localized()) (\(role))"
                }
            }
        }
        
        if selectedElement == nil {
            if let found = getSelectedElementFromWindows(appElement: appElement) {
                selectedElement = found
                diagnosticSource = "Window 遍历成功".localized()
            }
        }
        
        guard let element = selectedElement else {
            lastDiagnosticMessage = "未搜寻到选中项".localized()
            return getDefaultSourceRect()
        }
        
        // 4. 从选中元素中读取其 Position 和 Size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        guard posResult == .success, sizeResult == .success,
              let positionVal = positionRef, let sizeVal = sizeRef else {
            lastDiagnosticMessage = "坐标/大小属性读取失败".localized()
            return getDefaultSourceRect()
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(positionVal as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        
        lastDiagnosticMessage = "\("源".localized()): \(diagnosticSource)"
        
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
    private func getBoolAttribute(_ element: AXUIElement, attribute: String) -> Bool {
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
    private func getSelectedElementFromWindows(appElement: AXUIElement) -> AXUIElement? {
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
    private func deepFindSelected(in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
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
    private func getDefaultSourceRect() -> CGRect {
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
        if let timer = pollingTimer {
            timer.invalidate()
            pollingTimer = nil
        }

        // 2. 关闭并清理窗口引用
        if let window = previewWindow {
            previewWindow = nil
            window.delegate = nil
            window.contentView = nil
            window.close()
        }
        
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

    private func updatePreviewFromFinder() {
        // PERF: 将同步 IPC (AppleEvent) 发送检测移至后台高优先级队列中执行，彻底消除周期轮询对主线程滚动渲染的挂起和丢帧
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            let result = FileDetector.getSelectedFilePath()
            
            DispatchQueue.main.async {
                switch result {
                case .success(let path):
                    let resolvedPath = FileUtils.resolveSymlink(at: path)
                    if resolvedPath != self.previewState.filePath {
                        let renderType = FileTypeClassifier.classify(path: resolvedPath)
                        let language = FileTypeClassifier.getLanguageName(path: resolvedPath)
                        
                        // 更新窗口标题
                        if let window = self.previewWindow {
                            window.title = "Quick Cookies - \(URL(fileURLWithPath: resolvedPath).lastPathComponent)"
                        }
                        
                        // 更新状态触发 ContentView 异步加载文件内容
                        self.previewState.updateState(
                            filePath: resolvedPath,
                            renderType: renderType,
                            language: language,
                            isLoadingPath: false
                        )
                        
                        // 异步更新物理坐标 (用于下一次关闭时飞回)
                        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                            guard let self = self else { return }
                            let realSourceRect = self.getSourceRect()
                            DispatchQueue.main.async {
                                self.sourceRectBackup = realSourceRect
                            }
                        }
                    }
                case .failure(let error):
                    // 静默处理，不频繁写入错误日志以防爆磁盘
                    print("updatePreviewFromFinder 获取失败: \(error.localizedDescription)")
                }
            }
        }
    }

    /// 关闭窗口并附带平滑缩小到图标位置的 GPU 变换动画
    func closeWithAnimation() {
        guard let window = previewWindow, let contentView = window.contentView, let layer = contentView.layer else {
            close()
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
        if let timer = pollingTimer {
            timer.invalidate()
            pollingTimer = nil
        }

        // 立即激活并归还焦点给 Finder，使视觉缩小动画播放的同时焦点已经回到 Finder
        if let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) {
            finderApp.activate(options: [.activateIgnoringOtherApps])
        }

        // 立即解绑全局强引用和 delegate，避免动画中重复触发快捷键
        previewWindow = nil
        window.delegate = nil

        let targetRect = window.frame
        let sourceRect = sourceRectBackup ?? getDefaultSourceRect()
        
        // 同样在关闭时也要将 sourceRect 进行 padding 扩展以精准反向对齐
        let paddedSourceRect = sourceRect.insetBy(dx: -windowPadding, dy: -windowPadding)
        
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
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            window.contentView = nil
            window.close()
        }
        layer.add(group, forKey: "quickLookClose")
        window.animator().alphaValue = 0.0
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
        return previewWindow?.isVisible == true
    }
    
}