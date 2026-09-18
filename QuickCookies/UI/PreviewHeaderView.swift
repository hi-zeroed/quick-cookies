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

    // CSV 双模（表格 ⟷ 源码）
    @Binding var isCSVSourceMode: Bool
    
    // Markdown 导出 PDF
    let isExportingPDF: Bool
    let onExportPDF: () -> Void

    // 分享代码卡片
    var onShareCard: (() -> Void)? = nil

    // 实时监听与追尾状态
    var liveWatchingState: LiveWatchingState? = nil

    // 历史往复导航 (⌘[ / ⌘])
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var onGoBack: (() -> Void)? = nil
    var onGoForward: (() -> Void)? = nil
    
    // 工程元数据洞察 (⌘I 与顶栏按钮)
    var isTelemetryActive: Bool = false
    var onToggleTelemetry: (() -> Void)? = nil
    
    @State private var isHeaderHovered: Bool = false
    @State private var isBackHovered: Bool = false
    @State private var isForwardHovered: Bool = false

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
                LiquidGlassToolbarContainer(spacing: 2) {
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
                
                // 日志追尾微徽标（仅在 .log 追尾模式下按需展示）
                if let liveState = liveWatchingState, liveState.isLiveTailMode {
                    LiveTailBadgeView(liveState: liveState)
                }
            }

            Spacer()

            // 右侧控制区域（外部接力打开、SVG模式切换、⌥F搜索、PDF导出）
            LiquidGlassToolbarContainer(spacing: 6) {
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
                                HeaderToolbarButton(
                                    iconName: "doc.on.doc",
                                    helpText: "Copy SVG Code".localized(),
                                    action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(svgContent, forType: .string)
                                        onShowToast("SVG code copied to clipboard".localized(), "doc.on.doc")
                                    }
                                )
                            }
                        }
                    }

                    // CSV / TSV 双模切换胶囊（表格 ⟷ 源码）
                    let isCSV = (activeRenderType == .csv)
                    if isCSV {
                        HStack(spacing: 2) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isCSVSourceMode = false
                                    findBarState.dismiss()
                                }
                            }) {
                                Image(systemName: "tablecells")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isCSVSourceMode ? Color.appText.opacity(0.45) : Color.appText)
                                    .frame(width: 22, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(isCSVSourceMode ? Color.clear : Color.appText.opacity(0.12))
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("Data Grid".localized())

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isCSVSourceMode = true
                                }
                            }) {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(isCSVSourceMode ? Color.appText : Color.appText.opacity(0.45))
                                    .frame(width: 22, height: 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(isCSVSourceMode ? Color.appText.opacity(0.12) : Color.clear)
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
                    }

                    // ⌥F 全文搜索按钮
                    let supportsFind = PreviewProviderRegistry.supportsSearch(
                        for: activeRenderType,
                        path: path,
                        isSVGSourceMode: isSVGSourceMode
                    )
                    if supportsFind {
                        HeaderToolbarButton(
                            iconName: "magnifyingglass",
                            helpText: "Find in file (⌥F)".localized(),
                            isActive: findBarState.isPresented,
                            action: {
                                if findBarState.isPresented {
                                    findBarState.dismiss()
                                } else {
                                    findBarState.present()
                                }
                            }
                        )
                        .keyboardShortcut("f", modifiers: .option)
                    }

                    // ⌘I 文件工程元数据洞察按钮 (点击直接开关底部 HUD，无需聚焦窗口)
                    if onToggleTelemetry != nil {
                        HeaderToolbarButton(
                            iconName: "info.circle",
                            helpText: "File Info (⌘I)".localized(),
                            isActive: isTelemetryActive,
                            action: {
                                onToggleTelemetry?()
                            }
                        )
                    }

                    // PDF 导出按钮
                    if PreviewProviderRegistry.allowsPDFExport(for: activeRenderType) {
                        Group {
                            if isExportingPDF {
                                ProgressView()
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color.appText.opacity(0.6)))
                                    .frame(width: 44)
                            } else {
                                HeaderToolbarButton(
                                    iconName: "square.and.arrow.up",
                                    helpText: "Export PDF".localized(),
                                    action: onExportPDF
                                )
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isExportingPDF)
                    }

                    // 分享精美代码卡片按钮
                    if (activeRenderType == .code || activeRenderType == .plainText || activeRenderType == .markdown), onShareCard != nil {
                        HeaderToolbarButton(
                            iconName: "sparkles.rectangle.stack",
                            helpText: (activeRenderType == .code ? "Share Code Card" : "Share Card").localized(),
                            action: { onShareCard?() }
                        )
                    }

                    // 外部应用接力打开控件
                    AppRelayControlView(filePath: path) {
                        onClose()
                    }
                }
            }
        }
        .frame(minWidth: 72, alignment: .trailing)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .background(Color.clear)
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

/// 顶栏统一规范动作按钮
struct HeaderToolbarButton: View {
    let iconName: String
    let helpText: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(
                    isActive
                        ? Color.accentColor
                        : Color.appText.opacity(isHovered ? 0.95 : 0.72)
                )
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            isActive
                                ? Color.accentColor.opacity(0.15)
                                : (isHovered ? Color.appText.opacity(0.12) : Color.appText.opacity(0.06))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isActive
                                ? Color.accentColor.opacity(0.35)
                                : (isHovered ? Color.appText.opacity(0.18) : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))),
                            lineWidth: 0.5
                        )
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(helpText)
        .onHover { isHovered = $0 }
    }
}
