import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 强制初始化 Settings 单例以加载用户偏好语言或根据系统自适应首选语言
        _ = Settings.shared

        // 设置为后台 Agent，不显示 Dock 图标与顶部菜单栏，仅显示独立窗口
        NSApp.setActivationPolicy(.accessory)

        // 检查 Accessibility 权限
        if !HotkeyManager.shared.checkAccessibilityPermission() {
            showPermissionAlert()
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

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
        QuickLookOverlay.shared.close()
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限".localized()
        alert.informativeText = "Quick Cookies 需要辅助功能权限来监听全局快捷键。\n请前往 系统偏好设置 → 安全性与隐私 → 辅助功能，添加 Quick Cookies。".localized()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开设置".localized())
        alert.addButton(withTitle: "稍后".localized())

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统偏好设置
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
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