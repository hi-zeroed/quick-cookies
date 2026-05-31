import SwiftUI

@main
struct QuickPeekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 使用文字标题替代 systemImage 避免 IconRendering.framework metallib 问题
        MenuBarExtra {
            // 使用 FinderMenuIntegration 提供的菜单内容
            FinderMenuIntegration.getMenuBarMenu()
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .menuBarExtraStyle(.menu)
    }
}