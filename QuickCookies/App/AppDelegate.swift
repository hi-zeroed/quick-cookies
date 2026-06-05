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
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 450),
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