import SwiftUI
import AppKit

/// 自定义 NSPanel 子类，允许 borderless 无标题栏窗口接收键盘焦点和快捷键事件
class QuickLookPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
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

/// Quick Look 风格预览动画 system
/// 使用 Core Animation + Spring 物理动画实现 macOS 原生体验
class QuickLookOverlay: NSObject, NSWindowDelegate {
    static let shared = QuickLookOverlay()

    private var previewWindow: NSWindow?
    private var sourceRectBackup: CGRect?
    private var activeToastPanel: NSPanel?
    private var lastDiagnosticMessage: String = ""

    private override init() {
        super.init()
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
        // 如果预览窗口已经打开，按快捷键应快速关闭 (Toggle 交互)
        if let window = previewWindow, window.isVisible {
            closeWithAnimation()
            return
        }

        // 打开文件
        switch FileDetector.getSelectedFilePath() {
        case .success(let path):
            show(filePath: path)
        case .failure(let error):
            self.showToast(
                message: error.errorDescription ?? "未知错误",
                icon: "xmark.circle"
            )
        }
    }

    /// 显示预览窗口（Quick Look 动画）
    func show(filePath: String) {
        let resolvedPath = FileUtils.resolveSymlink(at: filePath)

        if !FileTypeClassifier.isSupported(path: resolvedPath) {
            self.showToast(message: "不支持此文件类型", icon: "xmark.circle")
            return
        }

        switch FileUtils.readFile(at: resolvedPath) {
        case .success(let result):
            let renderType = FileTypeClassifier.classify(path: resolvedPath)
            let language = FileTypeClassifier.getLanguageName(path: resolvedPath)

            showOverlay(
                filePath: resolvedPath,
                renderType: renderType,
                language: language,
                content: result.content
            )

        case .failure(let error):
            self.showToast(
                message: error.errorDescription ?? "未知错误",
                icon: "xmark.circle"
            )
        }
    }

    /// 创建预览面板并执行动画，不带任何黑色背景遮罩
    private func showOverlay(filePath: String, renderType: FileRenderType, language: String?, content: String) {
        // 关闭旧窗口
        close()

        // 获取触发源位置（Finder 选中文件的真实物理坐标）并备份
        let sourceRect = getSourceRect()
        sourceRectBackup = sourceRect

        // 创建预览面板（动态尺寸）
        let screenVisibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowWidth = screenVisibleFrame.width * 0.5
        let windowHeight = screenVisibleFrame.height * 0.6
        let targetRect = NSRect(
            x: screenVisibleFrame.midX - windowWidth / 2,
            y: screenVisibleFrame.midY - windowHeight / 2,
            width: windowWidth,
            height: windowHeight
        )

        // 采用 .borderless 彻底去除红绿灯按钮和顶端标题栏占位/边框线
        let previewPanel = QuickLookPanel(
            contentRect: targetRect,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // 允许用户按住预览窗口的任何背景空白区域随意拖动窗口位置
        previewPanel.isMovableByWindowBackground = true
        
        previewPanel.title = "QuickPeek - \(URL(fileURLWithPath: filePath).lastPathComponent)"
        previewPanel.level = .modalPanel
        previewPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        previewPanel.isFloatingPanel = true
        previewPanel.hidesOnDeactivate = false
        
        // 设置窗口背景为透明，并将圆角和内容阴影交由 layer 处理
        previewPanel.backgroundColor = .clear
        previewPanel.isOpaque = false
        previewPanel.hasShadow = true
        previewPanel.isReleasedWhenClosed = false
        previewPanel.delegate = self

        // SwiftUI 内容视图
        let contentView = ContentView(
            filePath: filePath,
            renderType: renderType,
            language: language,
            content: content
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = targetRect
        previewPanel.contentView = hostingView
        
        // 挂载到窗口后，立刻开启 Layer 并配置物理属性，确保处于正确的渲染上下文中（非 nil）
        hostingView.wantsLayer = true
        if let layer = hostingView.layer {
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)
            layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer.cornerRadius = 12
            layer.masksToBounds = true
        }

        // 先让预览窗口以 0.01 的极小不透明度显示，这在视觉上完全透明，但可以强制触发 NSHostingView 进行首帧排版和渲染
        previewPanel.alphaValue = 0.01
        previewPanel.makeKeyAndOrderFront(nil)
        
        // 诊断 Toast：实时输出获取到的选中项物理坐标，以及定位诊断信息
        let sizeInfo = "Size: \(Int(sourceRect.size.width))x\(Int(sourceRect.size.height))"
        let diagnosticMsg = self.lastDiagnosticMessage.isEmpty ? "" : " (\(self.lastDiagnosticMessage))"
        self.showToast(message: "Pos: (\(Int(sourceRect.origin.x)), \(Int(sourceRect.origin.y))) \(sizeInfo)\(diagnosticMsg)")

        // 延迟大约 30ms (两帧)，给系统充足的缓冲时间，确保离屏渲染的纹理数据在主线程 RunLoop 中自然完成首帧绘制并提交
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            self.performQuickLookAnimation(
                previewPanel: previewPanel,
                sourceRect: sourceRect,
                targetRect: targetRect
            )
        }

        self.previewWindow = previewPanel
    }

    /// 模拟 macOS 原生 Space (Quick Look) 的满帧 GPU 仿射变换弹簧动画 (CASpringAnimation)
    private func performQuickLookAnimation(previewPanel: NSPanel, sourceRect: CGRect, targetRect: CGRect) {
        guard let contentView = previewPanel.contentView, let layer = contentView.layer else { return }
        
        // 再次校准 anchorPoint & position，以防挂载后被 AppKit 布局重置
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)

        // 计算从图标（sourceRect）缩放到中心（targetRect）所需的 Scale 和 Translation
        let scaleX = sourceRect.width / targetRect.width
        let scaleY = sourceRect.height / targetRect.height
        
        let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
        let sourceCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        let translationX = sourceCenter.x - targetCenter.x
        let translationY = sourceCenter.y - targetCenter.y
        
        // 拼接初始的变换矩阵 (先 Scale 后 Translation)
        let initialTransform = CATransform3DConcat(
            CATransform3DMakeScale(scaleX, scaleY, 1.0),
            CATransform3DMakeTranslation(translationX, translationY, 0)
        )
        
        // 窗口本身的透明度直接置为 1.0 呈现
        previewPanel.alphaValue = 1.0

        // 使用物理公式驱动的 CASpringAnimation 弹簧动画
        let springTransform = CASpringAnimation(keyPath: "transform")
        springTransform.damping = 16
        springTransform.stiffness = 170
        springTransform.mass = 0.8
        springTransform.fromValue = NSValue(caTransform3D: initialTransform)
        springTransform.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        springTransform.duration = springTransform.settlingDuration
        
        // 透明度淡入动画
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 0.0
        fadeAnim.toValue = 1.0
        fadeAnim.duration = 0.18
        
        let group = CAAnimationGroup()
        group.animations = [springTransform, fadeAnim]
        group.duration = springTransform.settlingDuration
        group.isRemovedOnCompletion = true // 动画播完自动从层级移除
        group.fillMode = .removed           // 移除后自动采用模型图层的真实属性值（即最终态）
        
        CATransaction.begin()
        layer.add(group, forKey: "quickLookShow")
        CATransaction.commit()
    }

    /// 高精度获取 Finder 中当前选中项的视觉物理坐标 (AXUIElement API)
    private func getSourceRect() -> CGRect {
        lastDiagnosticMessage = ""
        
        // 1. 获取 Finder 的 PID
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
            lastDiagnosticMessage = "Finder PID 失败"
            return getDefaultSourceRect()
        }
        let pid = finderApp.processIdentifier
        
        // 2. 创建 Finder 应用 of AXUIElement
        let appElement = AXUIElementCreateApplication(pid)
        
        // 3. 寻找选中的 UI 元素：优先从键盘聚焦 focusedElement 获取，其次通过主窗口选中项列表 AXSelectedChildren 深度兜底遍历
        var selectedElement: AXUIElement?
        var diagnosticSource = "默认中心"
        
        var focusedElementRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
           let element = focusedElementRef as! AXUIElement? {
            // 校验 role 避免把 window 当作选中项
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String {
                if role == "AXCell" || role == "AXRow" || role == "AXStaticText" || role == "AXImage" || role == "AXTextField" {
                    selectedElement = element
                    diagnosticSource = "Focused (\(role))"
                }
            }
        }
        
        if selectedElement == nil {
            if let found = getSelectedElementFromWindows(appElement: appElement) {
                selectedElement = found
                diagnosticSource = "Window 遍历成功"
            }
        }
        
        guard let element = selectedElement else {
            lastDiagnosticMessage = "未搜寻到选中项"
            return getDefaultSourceRect()
        }
        
        // 4. 从选中元素中读取其 Position 和 Size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)
        
        guard posResult == .success, sizeResult == .success,
              let positionVal = positionRef, let sizeVal = sizeRef else {
            lastDiagnosticMessage = "坐标/大小属性读取失败"
            return getDefaultSourceRect()
        }
        
        var point = CGPoint.zero
        var size = CGSize.zero
        
        AXValueGetValue(positionVal as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        
        lastDiagnosticMessage = "源: \(diagnosticSource)"
        
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
            let hasTitle = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success
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
        if let window = previewWindow {
            previewWindow = nil
            window.delegate = nil
            window.contentView = nil
            window.close()
        }
    }

    /// 关闭窗口并附带平滑缩小到图标位置的 GPU 变换动画
    func closeWithAnimation() {
        guard let window = previewWindow, let contentView = window.contentView, let layer = contentView.layer else {
            close()
            return
        }

        // 立即解绑全局强引用和 delegate，避免动画中重复触发快捷键
        previewWindow = nil
        window.delegate = nil

        let targetRect = window.frame
        let sourceRect = sourceRectBackup ?? getDefaultSourceRect()
        
        let scaleX = sourceRect.width / targetRect.width
        let scaleY = sourceRect.height / targetRect.height
        
        let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
        let sourceCenter = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
        let translationX = sourceCenter.x - targetCenter.x
        let translationY = sourceCenter.y - targetCenter.y
        
        let finalTransform = CATransform3DConcat(
            CATransform3DMakeScale(scaleX, scaleY, 1.0),
            CATransform3DMakeTranslation(translationX, translationY, 0)
        )
        
        // 保证锚点为 (0.5, 0.5) 并且 position 居中，以进行高精度逆向收缩
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: targetRect.width / 2, y: targetRect.height / 2)

        // 使用非常平稳的缩放与淡出动画
        let shrinkAnim = CABasicAnimation(keyPath: "transform")
        shrinkAnim.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
        shrinkAnim.toValue = NSValue(caTransform3D: finalTransform)
        shrinkAnim.duration = 0.22
        shrinkAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0
        fadeAnim.toValue = 0.0
        fadeAnim.duration = 0.18
        fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        
        let group = CAAnimationGroup()
        group.animations = [shrinkAnim, fadeAnim]
        group.duration = 0.22
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