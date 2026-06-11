import Foundation
import AppKit
import SwiftUI

/// Finder 菜单集成管理
struct FinderMenuIntegration {
    enum OpenSelectedFileOutcome: Equatable {
        case request(PreviewLaunchRequest)
        case failure(message: String, icon: String?)
    }

    let openSelectedFile: () -> Void
    let showSettings: () -> Void
    let finderSelectionPathProvider: any FinderSelectionPathProviding

    init(
        openSelectedFile: @escaping () -> Void,
        showSettings: @escaping () -> Void,
        finderSelectionPathProvider: any FinderSelectionPathProviding = AppleScriptFinderSelectionPathProvider()
    ) {
        self.openSelectedFile = openSelectedFile
        self.showSettings = showSettings
        self.finderSelectionPathProvider = finderSelectionPathProvider
    }

    func resolveOpenSelectedFileRequest() -> OpenSelectedFileOutcome {
        switch finderSelectionPathProvider.selectedPath() {
        case .success(let path):
            return .request(.openPath(path, source: .menuBar))
        case .failure(let error):
            let message = (error.errorDescription ?? "未知错误").localized()
            return .failure(message: message, icon: "xmark.circle")
        }
    }

    @ViewBuilder
    func menuBarMenu() -> some View {
        Button(action: openSelectedFile) {
            Label("Open Selected File".localized(), image: "MenuOpen")
        }
        .help("Double-press Option or click here to open the selected Finder file".localized())

        Divider()

        Button(action: showSettings) {
            Label("Settings".localized(), image: "MenuSettings")
        }

        Divider()

        Button(action: { NSApplication.shared.terminate(nil) }) {
            Label("Quit".localized(), image: "MenuQuit")
        }
    }
}
