import SwiftUI

/// 预览浮层底部 HUD 视图，承载大文件增量流式加载指示条与状态提示
struct PreviewFooterHUD: View {
    @ObservedObject var loadState: PreviewLoadState
    let isLocatingSelection: Bool

    var body: some View {
        Group {
            if loadState.isIncrementalLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
                        .scaleEffect(0.8)
                    Text("Loading remaining content...".localized())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .liquidGlassPill(cornerRadius: 12)
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 20)
            }
        }
    }
}
