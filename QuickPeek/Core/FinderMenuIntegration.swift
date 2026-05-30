import Foundation
import AppKit
import SwiftUI

/// Finder 菜单集成管理
class FinderMenuIntegration {
    static let shared = FinderMenuIntegration()

    private init() {}

    /// 从 MenuBarExtra 打开选中的文件
    static func openSelectedFile() {
        switch FileDetector.getSelectedFilePath() {
        case .success(let path):
            QuickLookOverlay.shared.show(filePath: path)
        case .failure(let error):
            QuickLookOverlay.shared.showToast(
                message: error.errorDescription ?? "未知错误",
                icon: "xmark.circle"
            )
        }
    }

    /// 获取 MenuBarExtra 菜单内容
    @ViewBuilder
    static func getMenuBarMenu() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // 快速打开选中文件（使用 Unicode 字符替代图标）
            Button(action: openSelectedFile) {
                HStack(spacing: 8) {
                    Text("📄") // doc.text.fill Unicode
                    Text("打开选中文件")
                }
            }
            .buttonStyle(.plain)
            .help("双击 Option 或点击此按钮打开 Finder 选中的文件")

            Divider()

            // 设置
            Button(action: { SettingsWindowController.shared.show() }) {
                HStack(spacing: 8) {
                    Text("⚙") // gear Unicode
                    Text("设置")
                }
            }
            .buttonStyle(.plain)

            Divider()

            // 退出
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack(spacing: 8) {
                    Text("⏻") // power Unicode
                    Text("退出")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(8)
    }

    /// 注册 Services 菜单（通过 Info.plist 配置，这里提供辅助方法）
    func registerServices() {
        // macOS Services 菜单通过 Info.plist 的 NSServices 配置
        // AppDelegate.swift 中已注册 NSApp.servicesProvider = QuickPeekServiceProvider()
        // 这里提供额外的配置检查和日志
        print("Services menu configured via Info.plist")
        print("QuickPeekServiceProvider registered in AppDelegate")
    }
}