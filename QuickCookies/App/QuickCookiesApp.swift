import SwiftUI

@main
struct QuickCookiesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var settings = Settings.shared

    var body: some Scene {
        // 使用文字标题替代 systemImage 避免 IconRendering.framework metallib 问题
        MenuBarExtra {
            appDelegate.finderMenuIntegration.menuBarMenu()
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}
