import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 强制初始化 Settings 单例以加载用户偏好语言或根据系统自适应首选语言
        _ = Settings.shared

        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            // 普通激活策略，以便新手向导窗口能够居中并正常获取键盘焦点
            NSApp.setActivationPolicy(.regular)
            showOnboarding()
        } else {
            // 正常工作流
            setupNormalFlow()
        }
    }
    
    private func setupNormalFlow() {
        // 设置为后台 Agent，不显示 Dock 图标与顶部菜单栏，仅显示独立窗口
        NSApp.setActivationPolicy(.accessory)

        // 检查 Accessibility 权限，若未开启但在后台运行仍会开启热键绑定
        if !HotkeyManager.shared.checkAccessibilityPermission() {
            // 仅静默申请，由用户自由选择，已通过 Finder Sync 扩展降级
            HotkeyManager.shared.requestAccessibilityPermission()
        }

        // 注册热键（双击 Option）- 使用 QuickLookOverlay 新动画系统
        HotkeyManager.shared.registerWithSettings {
            QuickLookOverlay.shared.showFromFinder()
        }

        // 注册 Services 菜单项
        NSApp.servicesProvider = QuickCookiesServiceProvider()

        print("Quick Cookies started. Double-press Option key to preview files.")
    }
    
    private func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        
        let onboardingView = OnboardingView(onFinished: { [weak self, weak window] in
            // 写入完成新手引导标识
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            
            // 关闭 Onboarding 窗口
            window?.close()
            self?.onboardingWindow = nil
            
            // 初始化注册后台工作流
            self?.setupNormalFlow()
        })
        
        let hostingView = NSHostingView(rootView: onboardingView)
        window.contentView = hostingView
        
        self.onboardingWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 处理 URL Scheme 唤起事件（来自 Finder Sync 扩展）
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first, url.scheme == "quickcookies", url.host == "preview" else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let pathItem = components?.queryItems?.first(where: { $0.name == "path" }),
           let path = pathItem.value {
            // 解析路径并执行预览
            QuickLookOverlay.shared.show(filePath: path)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
        QuickLookOverlay.shared.close()
    }


}

/// Services 菜单项提供者（右键菜单集成）
class QuickCookiesServiceProvider: NSObject {
    /// Services 菜单项：打开 QuickCookies
    @objc func quickCookiesService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        // 1. 尝试作为 URL 读取
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let firstURL = urls.first {
            QuickLookOverlay.shared.show(filePath: firstURL.path)
            return
        }

        // 2. 尝试作为 Filenames (NSFilenamesPboardType) 读取
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String],
           let firstPath = filenames.first {
            QuickLookOverlay.shared.show(filePath: firstPath)
            return
        }
    }
}