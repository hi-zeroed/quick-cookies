import SwiftUI

/// 预览浮层顶部工具栏视图，整合窗控、文件名徽标与各类交互动作
struct PreviewHeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    let activePath: String?
    let activeDisplayName: String?
    let activeRenderType: FileRenderType?
    let activeErrorMessage: String?
    let isExpanded: Bool
    let onClose: () -> Void
    let onToggleExpanded: () -> Void
    
    // 搜索状态
    @ObservedObject var findBarState: FindBarState
    
    // SVG 双模与源码复制
    @Binding var isSVGSourceMode: Bool
    let svgContent: String
    let onShowToast: (String, String?) -> Void
    
    // Markdown 导出 PDF
    let isExportingPDF: Bool
    let onExportPDF: () -> Void

    // 分享代码卡片
    var onShareCard: (() -> Void)? = nil

    // 实时监听与追尾状态
    var liveWatchingState: LiveWatchingState? = nil

    // Git 差异状态
    var gitDiffState: GitDiffState? = nil

    // 历史往复导航 (⌘[ / ⌘])
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var onGoBack: (() -> Void)? = nil
    var onGoForward: (() -> Void)? = nil
    
    @State private var isHeaderHovered: Bool = false
    @State private var isBackHovered: Bool = false
    @State private var isForwardHovered: Bool = false
    @State private var isSearchHovered: Bool = false
    @State private var isCopySVGHovered: Bool = false
    @State private var isPDFHovered: Bool = false
    @State private var isShareCardHovered: Bool = false

    var body: some View {
        HStack {
            // 左侧控制区域：关闭/全屏窗控 + 历史往复导航 (◀ ▶)
            HStack(spacing: 10) {
                // 关闭与展开按钮
                HStack(spacing: 8) {
                    // 关闭按钮
                    CircleControlButton(iconName: "xmark", isHovered: isHeaderHovered) {
                        onClose()
                    }
                    
                    // 全屏/还原按钮
                    CircleControlButton(
                        iconName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                        isHovered: isHeaderHovered
                    ) {
                        onToggleExpanded()
                    }
                    .help(isExpanded ? "Exit Full Screen".localized() : "Full Screen".localized())
                }

                // 历史往复回溯导航微按钮组 (◀ ▶)
                HStack(spacing: 2) {
                    Button(action: { onGoBack?() }) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(canGoBack ? Color.appText.opacity(isBackHovered ? 1.0 : 0.65) : Color.appText.opacity(0.18))
                            .frame(width: 18, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(canGoBack && isBackHovered ? Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18) : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canGoBack)
                    .onHover { isBackHovered = $0 }
                    .help("Back (⌘[)".localized())

                    Button(action: { onGoForward?() }) {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(canGoForward ? Color.appText.opacity(isForwardHovered ? 1.0 : 0.65) : Color.appText.opacity(0.18))
                            .frame(width: 18, height: 18)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(canGoForward && isForwardHovered ? Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18) : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canGoForward)
                    .onHover { isForwardHovered = $0 }
                    .help("Forward (⌘])".localized())
                }
            }
            .frame(width: 108, alignment: .leading)
            
            Spacer()

            // 中间文件名 + 文件类型小图标 + 状态修饰点
            HStack(spacing: 6) {
                if let displayName = activeDisplayName {
                    HStack(spacing: 5) {
                        previewFileIcon(for: activeRenderType)

                        Text(displayName)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.appText)
                    }
                } else if let path = activePath {
                    HStack(spacing: 5) {
                        previewFileIcon(for: activeRenderType)
                        
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.appText)
                    }
                } else if activeErrorMessage != nil {
                    Text(activePath == nil ? "QuickCookies" : "Failed to Get".localized())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(activePath == nil ? Color.appText.opacity(0.85) : .red.opacity(0.8))
                } else {
                    Text("Locating...".localized())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.6))
                }
                
                // 状态修饰点与日志追尾微徽标
                if let liveState = liveWatchingState, liveState.isLiveTailMode {
                    LiveTailBadgeView(liveState: liveState)
                } else {
                    Circle()
                        .fill(activePath == nil ? Color.accentColor.opacity(0.8) : (liveWatchingState?.isHotReloading == true ? Color.green.opacity(0.9) : Color.blue.opacity(0.8)))
                        .frame(width: 6, height: 6)
                        .scaleEffect(liveWatchingState?.isHotReloading == true ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: liveWatchingState?.isHotReloading)
                }

                // Git 差异状态微徽标
                if let diffState = gitDiffState {
                    GitDiffBadgeView(gitDiffState: diffState)
                }
            }

            Spacer()

            // 右侧控制区域（外部接力打开、SVG模式切换、⌥F搜索、PDF导出）
            HStack(spacing: 8) {
                if let path = activePath, activeErrorMessage == nil {
                    // SVG 双模切换胶囊 & 源码复制按钮
                    let isSVG = path.lowercased().hasSuffix(".svg")
                    if isSVG {
                        HStack(spacing: 4) {
                            // 模式切换极简微胶囊（纯图标：photo ⟷ code）
                            HStack(spacing: 2) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isSVGSourceMode = false
                                        findBarState.dismiss()
                                    }
                                }) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(isSVGSourceMode ? Color.appText.opacity(0.45) : Color.appText)
                                        .frame(width: 22, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(isSVGSourceMode ? Color.clear : Color.appText.opacity(0.12))
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Visual Preview".localized())

                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        isSVGSourceMode = true
                                    }
                                }) {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(isSVGSourceMode ? Color.appText : Color.appText.opacity(0.45))
                                        .frame(width: 22, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(isSVGSourceMode ? Color.appText.opacity(0.12) : Color.clear)
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Source Code".localized())
                            }
                            .padding(2)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color.appText.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.appBorder.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 0.5)
                            )

                            // 源码模式下一键复制 SVG 源码
                            if isSVGSourceMode {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(svgContent, forType: .string)
                                    onShowToast("SVG code copied to clipboard".localized(), "doc.on.doc")
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color.appText.opacity(isCopySVGHovered ? 0.95 : 0.75))
                                        .frame(width: 22, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color.appText.opacity(isCopySVGHovered ? 0.12 : 0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.appText.opacity(isCopySVGHovered ? 0.18 : (colorScheme == .dark ? 0.12 : 0.08)), lineWidth: 0.5)
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Copy SVG Code".localized())
                                .onHover { hovering in
                                    isCopySVGHovered = hovering
                                }
                            }
                        }
                    }

                    // ⌥F 全文搜索按钮
                    let supportsFind = PreviewProviderRegistry.supportsSearch(
                        for: activeRenderType,
                        path: path,
                        isSVGSourceMode: isSVGSourceMode
                    )
                    if supportsFind {
                        Button(action: {
                            if findBarState.isPresented {
                                findBarState.dismiss()
                            } else {
                                findBarState.present()
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(findBarState.isPresented ? Color.accentColor : Color.appText.opacity(isSearchHovered ? 0.95 : 0.75))
                                .frame(width: 22, height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(findBarState.isPresented ? Color.accentColor.opacity(0.15) : Color.appText.opacity(isSearchHovered ? 0.12 : 0.06))
                                 )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(findBarState.isPresented ? Color.accentColor.opacity(0.3) : Color.appText.opacity(isSearchHovered ? 0.18 : (colorScheme == .dark ? 0.12 : 0.08)), lineWidth: 0.5)
                                 )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Find in file (⌥F)".localized())
                        .keyboardShortcut("f", modifiers: .option)
                        .onHover { hovering in
                            isSearchHovered = hovering
                        }
                    }

                    if PreviewProviderRegistry.allowsPDFExport(for: activeRenderType) {
                        Group {
                            if isExportingPDF {
                                ProgressView()
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color.appText.opacity(0.6)))
                                    .frame(width: 50)
                            } else {
                                Button(action: onExportPDF) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color.appText.opacity(isPDFHovered ? 0.95 : 0.8))
                                        .frame(width: 22, height: 22)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color.appText.opacity(isPDFHovered ? 0.12 : 0.06))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(Color.appText.opacity(isPDFHovered ? 0.18 : (colorScheme == .dark ? 0.12 : 0.08)), lineWidth: 0.5)
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Export PDF".localized())
                                .onHover { hovering in
                                    isPDFHovered = hovering
                                }
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isExportingPDF)
                    }

                    // 分享精美代码卡片按钮
                    if (activeRenderType == .code || activeRenderType == .plainText || activeRenderType == .markdown), onShareCard != nil {
                        Button(action: {
                            onShareCard?()
                        }) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appText.opacity(isShareCardHovered ? 0.95 : 0.75))
                                .frame(width: 22, height: 22)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.appText.opacity(isShareCardHovered ? 0.12 : 0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.appText.opacity(isShareCardHovered ? 0.18 : (colorScheme == .dark ? 0.12 : 0.08)), lineWidth: 0.5)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help((activeRenderType == .code ? "Share Code Card" : "Share Card").localized())
                        .onHover { hovering in
                            isShareCardHovered = hovering
                        }
                    }

                    // 外部应用接力打开控件
                    AppRelayControlView(filePath: path) {
                        onClose()
                    }
                }
            }
            .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onHover { hovering in
            isHeaderHovered = hovering
        }
    }

    @ViewBuilder
    private func previewFileIcon(for renderType: FileRenderType?) -> some View {
        if let assetName = PreviewFileIconAssetRegistry.assetName(for: renderType) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundColor(Color.appText.opacity(0.6))
        }
    }
}
