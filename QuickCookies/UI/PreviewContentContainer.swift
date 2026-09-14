import SwiftUI

/// 预览主内容区通用容器，管理毛玻璃底板、搜索浮层对齐与底部 HUD
struct PreviewContentContainer<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let activeRenderType: FileRenderType?
    let isSVGSourceMode: Bool
    @ObservedObject var findBarState: FindBarState
    @ObservedObject var loadState: PreviewLoadState
    let shouldShowLoadingOverlay: Bool
    let isLocatingSelection: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topTrailing) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(contentAreaBackgroundColor)
                    .cornerRadius(15)
                    .overlay(
                        Group {
                            if PreviewProviderRegistry.borderStyle(for: activeRenderType, isSVGSourceMode: isSVGSourceMode) == .appBorder {
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(Color.appBorder.opacity(colorScheme == .dark ? 0.25 : 0.12), lineWidth: 0.8)
                            }
                        }
                    )
                    .padding([.horizontal, .bottom], 5)

                FindBarView(state: findBarState)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowLoadingOverlay {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.4)))
                    Text("Loading content...".localized())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground.opacity(0.98))
                .cornerRadius(15)
                .padding([.horizontal, .bottom], 5)
                .transition(.opacity)
            }
            
            // 增量加载悬浮条
            PreviewFooterHUD(loadState: loadState, isLocatingSelection: isLocatingSelection)
        }
    }

    private var contentAreaBackgroundColor: Color {
        switch PreviewProviderRegistry.backgroundStyle(for: activeRenderType, isSVGSourceMode: isSVGSourceMode) {
        case .appBackground:
            return Color.appBackground
        case .transparent:
            return Color.clear
        }
    }
}
