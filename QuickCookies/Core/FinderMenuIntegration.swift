import Foundation
import AppKit
import SwiftUI

/// Finder 菜单集成管理
class FinderMenuIntegration {
    static let shared = FinderMenuIntegration()

    private init() {}

    /// 从 MenuBarExtra 打开选中的文件
    static func openSelectedFile() {
        DispatchQueue.main.async {
            switch FileDetector.getSelectedFilePath() {
            case .success(let path):
                QuickLookOverlay.shared.show(filePath: path)
            case .failure(let error):
                QuickLookOverlay.shared.showToast(
                    message: (error.errorDescription ?? "未知错误").localized(),
                    icon: "xmark.circle"
                )
            }
        }
    }

    /// 获取 MenuBarExtra 菜单内容
    @ViewBuilder
    static func getMenuBarMenu() -> some View {
        Button(action: openSelectedFile) {
            Label("Open Selected File".localized(), image: "MenuOpen")
        }
        .help("Double-press Option or click here to open the selected Finder file".localized())

        Divider()

        Button(action: {
            DispatchQueue.main.async {
                SettingsWindowController.shared.show()
            }
        }) {
            Label("Settings".localized(), image: "MenuSettings")
        }

        Divider()

        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("Quit".localized(), image: "MenuQuit")
        }
    }

    /// 注册 Services 菜单（通过 Info.plist 配置，这里提供辅助方法）
    func registerServices() {
        // macOS Services 菜单通过 Info.plist 的 NSServices 配置
        // AppDelegate.swift 中已注册 NSApp.servicesProvider = QuickCookiesServiceProvider()
        // 这里保留为空实现，避免在正常运行路径上输出无关控制台日志。
    }
}
