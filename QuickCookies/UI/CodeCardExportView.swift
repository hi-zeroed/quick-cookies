import SwiftUI
import AppKit

/// 微透点阵设计画板底衬视图 (Subtle Dot Matrix Canvas)
struct DotMatrixCanvasView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18.0
            let dotRadius: CGFloat = 1.0
            let dotColor = Color.white.opacity(0.12)
            
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

/// 纯粹用于离屏快照渲染的高清代码/引用卡片视图
struct CodeCardSnapshotView: View {
    let title: String
    let code: String
    let language: String?
    let config: CodeCardConfig
    var cardWidth: CGFloat? = nil
    var onToggleLineFocus: ((Int) -> Void)? = nil
    
    private var effectiveCardWidth: CGFloat {
        cardWidth ?? config.cardWidthPreset.width
    }
    
    private var codeLines: [String] {
        code.components(separatedBy: "\n")
    }
    
    /// 获取规范化的大写语言胶囊展示名 (如 TSX, JS, JAVA, SWIFT 等)
    private var displayLanguageBadge: String {
        CodeCardLanguageFormatter.format(
            customLanguage: config.customLanguage,
            detectedLanguage: language,
            title: title,
            code: code
        )
    }
    
    // 内容内衬背景色与文字色（根据 colorTheme）
    private var cardInnerBackground: Color {
        if config.colorTheme == .dark {
            return Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.82)
        } else {
            return Color.white.opacity(0.92)
        }
    }
    
    private var cardBorderColor: Color {
        if config.colorTheme == .dark {
            return Color.white.opacity(0.14)
        } else {
            return Color.black.opacity(0.08)
        }
    }
    
    private var primaryTextColor: Color {
        config.colorTheme == .dark ? Color.white.opacity(0.92) : Color(red: 0.12, green: 0.13, blue: 0.16)
    }
    
    private var secondaryTextColor: Color {
        config.colorTheme == .dark ? Color.white.opacity(0.42) : Color.black.opacity(0.45)
    }
    
    // 根据社交比例计算目标高度（若为 auto 则为 nil）
    private var targetHeight: CGFloat? {
        switch config.aspectRatio {
        case .auto:
            return nil
        case .square:
            return effectiveCardWidth
        case .landscape:
            return effectiveCardWidth * 9.0 / 16.0
        }
    }
    
    var body: some View {
        ZStack {
            // 1. 同源漫反射环境柔光 (Ambient Glow)
            if config.showAmbientGlow && !config.isTransparentBackground {
                config.preset.backgroundCanvasView()
                    .frame(width: effectiveCardWidth * 0.94, height: (targetHeight ?? 240) * 0.94)
                    .blur(radius: 34)
                    .opacity(config.colorTheme == .dark ? 0.46 : 0.28)
                    .offset(y: 12)
            }
            
            // 2. 主卡片外框：现代艺术渐变背景 (macOS 15+ MeshGradient) 或 透明背景
            ZStack {
                if !config.isTransparentBackground {
                    config.preset.backgroundCanvasView()
                }
                
                // 3. 内层拟物毛玻璃卡片 (Glassmorphism)
                VStack(alignment: .leading, spacing: 0) {
                    if config.mode == .code {
                        codeHeaderBar
                        Divider().background(cardBorderColor)
                        codeContentView
                    } else {
                        // 文本/引用模式彻底去终端化：没有红绿灯！没有 clipboard.txt！
                        quoteContentView
                    }
                    
                    // 底部水印与时间徽标
                    if config.showWatermark {
                        bottomWatermarkBar
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cardInnerBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(config.colorTheme == .dark ? 0.24 : 0.45),
                                    cardBorderColor,
                                    Color.white.opacity(config.colorTheme == .dark ? 0.06 : 0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.8
                        )
                )
                .shadow(
                    color: Color.black.opacity(config.colorTheme == .dark ? 0.35 : 0.12),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .padding(config.padding.rawValue)
            }
            .frame(width: effectiveCardWidth, height: targetHeight)
            .fixedSize(horizontal: true, vertical: targetHeight != nil)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(width: effectiveCardWidth)
    }
    
    // MARK: - 代码视图顶栏 (左侧极客红绿灯 + 右侧语言胶囊横向平衡呼应)
    private var codeHeaderBar: some View {
        HStack(spacing: 8) {
            if config.showTrafficLights {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1.0, green: 0.37, blue: 0.34)).frame(width: 9, height: 9)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 9, height: 9)
                    Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 9, height: 9)
                }
            }
            
            Spacer()
            
            // 右侧纯文字代码语言胶囊徽标 (如 TSX, JS, JAVA, SWIFT 等)，去图标化更显纯粹高级
            Text(displayLanguageBadge)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(primaryTextColor)
                .tracking(0.6)
                .padding(.horizontal, 8.5)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(config.colorTheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .stroke(cardBorderColor.opacity(0.6), lineWidth: 0.6)
                )
        }
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 9)
    }
    
    /// 生效的底层 Highlightr 语法高亮引擎语言标识
    private var effectiveHighlighterLanguage: String? {
        if let custom = config.customLanguage, !custom.isEmpty, custom.lowercased() != "auto" {
            return CodeCardLanguageFormatter.highlightrLanguage(from: custom)
        }
        if let lang = language, !lang.isEmpty {
            return CodeCardLanguageFormatter.highlightrLanguage(from: lang)
        }
        let badge = displayLanguageBadge
        return badge != "CODE" ? CodeCardLanguageFormatter.highlightrLanguage(from: badge) : nil
    }
    
    /// 获取当前用户偏好设置中的代码字体
    private var codeFont: Font {
        Font(NSFont.editorFont(name: Settings.shared.editorFont, size: config.fontSize))
    }

    /// 获取代码行号字体
    private var lineNumFont: Font {
        Font(NSFont.editorFont(name: Settings.shared.editorFont, size: max(config.fontSize - 1, 9)))
    }

    /// 全文多行上下文语法高亮结果并精准切行，保证跨行函数与类型定义 100% 着色，并在语言切换时动态刷新
    private var highlightedCodeLines: [AttributedString] {
        let theme = config.colorTheme == .dark ? "atom-one-dark" : "atom-one-light"
        let targetLines = Array(codeLines.prefix(120))
        let joinedCode = targetLines.joined(separator: "\n")
        let fontName = Settings.shared.editorFont
        
        guard let lang = effectiveHighlighterLanguage,
              let highlighter = SyntaxHighlighter.shared,
              let rawAttributed = highlighter.highlight(code: joinedCode, language: lang, theme: theme) else {
            return targetLines.map { AttributedString($0.isEmpty ? " " : $0) }
        }

        // 应用用户在偏好设置中选择的等宽编辑器字体 (如 JetBrains Mono 等)，保留语法高亮的颜色和粗斜体特征
        let fullAttributed = rawAttributed.applyingEditorFont(name: fontName, size: config.fontSize)
        
        let fullString = fullAttributed.string as NSString
        var results: [AttributedString] = []
        var lineStartIndex = 0
        
        for line in targetLines {
            let lineLen = (line as NSString).length
            let range = NSRange(location: lineStartIndex, length: lineLen)
            if range.location + range.length <= fullString.length {
                let sub = fullAttributed.attributedSubstring(from: range)
                results.append(AttributedString(sub))
            } else {
                results.append(AttributedString(line.isEmpty ? " " : line))
            }
            lineStartIndex += lineLen + 1 // +1 代表换行符 '\n'
        }
        return results
    }

    private var isDiffMode: Bool {
        effectiveHighlighterLanguage == "diff" || displayLanguageBadge == "DIFF" || CodeCardDiffAnalyzer.isDiffContent(code)
    }

    private var rawCodeLines: [String] {
        Array(codeLines.prefix(120))
    }

    // MARK: - 代码视图排版 (支持上下文语法高亮、Git Diff 与行号聚焦)
    private var codeContentView: some View {
        let lines = highlightedCodeLines
        let rawLines = rawCodeLines
        let isDiff = isDiffMode
        let hasAnyFocus = !config.focusedLineIndices.isEmpty
        
        return VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, attrLine in
                let rawLine = index < rawLines.count ? rawLines[index] : ""
                let diffKind = isDiff ? CodeCardDiffAnalyzer.classifyLine(rawLine) : .context
                let isFocused = config.focusedLineIndices.contains(index)
                let lineOpacity: Double = hasAnyFocus ? (isFocused ? 1.0 : 0.32) : 1.0
                
                HStack(alignment: .top, spacing: 10) {
                    // 1. 聚焦指示条 (聚焦时高亮突出)
                    Rectangle()
                        .fill(isFocused ? config.preset.primaryColor : Color.clear)
                        .frame(width: 2.5)
                        .cornerRadius(1.2)
                    
                    // 2. 行号与 Diff 符号
                    if config.showLineNumbers {
                        HStack(spacing: 3) {
                            if isDiff {
                                Group {
                                    switch diffKind {
                                    case .added:
                                        Text("+")
                                            .font(lineNumFont.bold())
                                            .foregroundColor(Color.green)
                                    case .deleted:
                                        Text("-")
                                            .font(lineNumFont.bold())
                                            .foregroundColor(Color.red)
                                    case .header:
                                        Text("@")
                                            .font(lineNumFont)
                                            .foregroundColor(Color.cyan.opacity(0.8))
                                    case .context:
                                        Text(" ")
                                            .font(lineNumFont)
                                    }
                                }
                                .frame(width: 10, alignment: .center)
                            }
                            
                            Text("\(index + 1)")
                                .font(lineNumFont)
                                .foregroundColor(diffNumberColor(for: diffKind))
                                .frame(minWidth: 22, alignment: .trailing)
                        }
                    }
                    
                    // 3. 代码正文
                    Text(attrLine)
                        .font(codeFont)
                        .foregroundColor(diffTextColor(for: diffKind))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
                .padding(.trailing, 12)
                .background(diffLineBackground(diffKind: diffKind, isFocused: isFocused))
                .cornerRadius(4)
                .opacity(lineOpacity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onToggleLineFocus?(index)
                }
                .id("\(effectiveHighlighterLanguage ?? "none")-\(config.colorTheme.rawValue)-\(Settings.shared.editorFont)-\(index)")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func diffNumberColor(for kind: CodeCardDiffLineKind) -> Color {
        switch kind {
        case .added:
            return Color.green.opacity(0.85)
        case .deleted:
            return Color.red.opacity(0.85)
        case .header:
            return Color.cyan.opacity(0.8)
        case .context:
            return secondaryTextColor.opacity(0.65)
        }
    }
    
    private func diffTextColor(for kind: CodeCardDiffLineKind) -> Color? {
        switch kind {
        case .added:
            return config.colorTheme == .dark ? Color(red: 0.50, green: 0.95, blue: 0.65) : Color(red: 0.10, green: 0.60, blue: 0.25)
        case .deleted:
            return config.colorTheme == .dark ? Color(red: 0.98, green: 0.50, blue: 0.50) : Color(red: 0.75, green: 0.15, blue: 0.15)
        case .header:
            return config.colorTheme == .dark ? Color.cyan.opacity(0.9) : Color.blue.opacity(0.9)
        case .context:
            return nil
        }
    }
    
    private func diffLineBackground(diffKind: CodeCardDiffLineKind, isFocused: Bool) -> Color {
        switch diffKind {
        case .added:
            return Color.green.opacity(config.colorTheme == .dark ? 0.16 : 0.12)
        case .deleted:
            return Color.red.opacity(config.colorTheme == .dark ? 0.16 : 0.12)
        case .header:
            return Color.cyan.opacity(config.colorTheme == .dark ? 0.10 : 0.06)
        case .context:
            return isFocused ? config.preset.primaryColor.opacity(config.colorTheme == .dark ? 0.14 : 0.08) : Color.clear
        }
    }
    
    // MARK: - 文本与引言视图排版 (人文书香美学：大双引号 + 纯净留白 + 舒展排版)
    private var quoteContentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部优雅大双引号 (SF Pro Serif / New York 衬线艺术质感)
            HStack {
                Text("“")
                    .font(.system(size: 38, weight: .bold, design: .serif))
                    .foregroundColor(config.preset.primaryColor.opacity(0.85))
                    .frame(height: 24, alignment: .leading)
                Spacer()
            }
            .padding(.top, 6)
            
            // 正文舒展自然排版
            Text(code)
                .font(.system(size: config.fontSize + 2.0, weight: .regular, design: .default))
                .lineSpacing(7)
                .foregroundColor(primaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }
    
    // MARK: - 底部水印栏
    private var bottomWatermarkBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 9))
                    .foregroundColor(secondaryTextColor)
                Text("QuickCookies")
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundColor(secondaryTextColor)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
    }
}

/// 卡片真实渲染高度偏好键，用于画板自适应紧凑贴合
private struct CardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 画板查看缩放模式
enum CardZoomMode: String, CaseIterable, Identifiable {
    case fit = "fit"
    case actual = "actual"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fit: return "Fit".localized()
        case .actual: return "100%"
        }
    }
}

/// 交互式分享代码/引用卡片导出弹窗 (Card Studio 2.0)
struct CodeCardExportModalView: View {
    let title: String
    let code: String
    let language: String?
    let initialMode: CardContentMode
    let onDismiss: () -> Void
    let onShowToast: (String, String?) -> Void
    
    @ObservedObject private var settings = Settings.shared
    @State private var config: CodeCardConfig
    @State private var isCopying: Bool = false
    @State private var isSaving: Bool = false
    @State private var inlineToast: (message: String, icon: String?)? = nil
    @State private var measuredCardHeight: CGFloat = 260
    @State private var zoomMode: CardZoomMode = .fit
    
    private var currentCardWidth: CGFloat {
        config.cardWidthPreset.width
    }
    
    private let modalWindowWidth: CGFloat = 1020
    private let modalWindowHeight: CGFloat = 630
    private let inspectorWidth: CGFloat = 270
    
    private var canvasViewportWidth: CGFloat {
        modalWindowWidth - inspectorWidth - 1
    }
    
    private var canvasViewportHeight: CGFloat {
        modalWindowHeight - 48
    }
    
    /// 适应视口缩放比例计算 (四周保留呼吸感点阵间距)
    private var fitScale: CGFloat {
        let availableWidth = max(canvasViewportWidth - 64, 200)
        let availableHeight = max(canvasViewportHeight - 64, 200)
        let widthScale = availableWidth / max(currentCardWidth, 100)
        let heightScale = availableHeight / max(measuredCardHeight, 100)
        return min(1.0, min(widthScale, heightScale))
    }
    
    init(
        title: String,
        code: String,
        language: String?,
        initialMode: CardContentMode = .code,
        onDismiss: @escaping () -> Void,
        onShowToast: @escaping (String, String?) -> Void
    ) {
        self.title = title
        self.code = code
        self.language = language
        self.initialMode = initialMode
        self.onDismiss = onDismiss
        self.onShowToast = onShowToast
        
        var initialConfig = CodeCardConfig()
        initialConfig.mode = initialMode
        _config = State(initialValue: initialConfig)
    }
    
    var body: some View {
        ZStack {
            // 全局透明交互层：点击红框外部任意桌面区域优雅退出，彻底消除大黑方块与硬边缘
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // 居中卡片工作台 (Card Studio)
            VStack(spacing: 0) {
                // 1. 顶部标题栏 + 模式分段器 + 缩放模式切换 + 快捷关闭
                topHeaderBar
                
                Divider()
                
                // 2. 左右双栏主体：左侧沉浸大画板 (Canvas) ⟷ 右侧专业属性检查器 (Inspector)
                HStack(spacing: 0) {
                    canvasArea
                    
                    Divider()
                    
                    inspectorPanel
                }
                .frame(height: canvasViewportHeight)
            }
            .frame(width: modalWindowWidth, height: modalWindowHeight)
            .background(Color.appBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 36, y: 16)
            
            // 弹窗最高层级内联反馈胶囊 (保证 100% 绝对可见)
            if let toast = inlineToast {
                VStack {
                    HStack(spacing: 8) {
                        if let icon = toast.icon {
                            Image(systemName: icon)
                                .foregroundColor(.white)
                        }
                        Text(toast.message)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.12, green: 0.13, blue: 0.16).opacity(0.96))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 12, y: 6)
                    .padding(.top, 24)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(200)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: inlineToast != nil)
    }
    
    // MARK: - 顶部标题工具栏 (Header Bar)
    private var topHeaderBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Share Card".localized())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // 卡片类型模式分段器 (代码 ⟷ 文本/引用)
            Picker("", selection: $config.mode) {
                ForEach(CardContentMode.allCases) { mode in
                    Label(mode.displayName, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            
            Spacer()
            
            // 右侧：缩放模式微胶囊 (适应 ⟷ 100%) 与快捷关闭
            HStack(spacing: 12) {
                Picker("", selection: $zoomMode) {
                    ForEach(CardZoomMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 125)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
    }
    
    // MARK: - 左侧画板展示区 (Canvas Viewport)
    private var canvasArea: some View {
        ZStack {
            Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.85)
            DotMatrixCanvasView()
            
            if zoomMode == .fit {
                // 适应模式：计算 fitScale 居中展示卡片，四周留有匀称点阵呼吸感
                let effectiveScale = fitScale
                let scaledWidth = currentCardWidth * effectiveScale
                let scaledHeight = max(measuredCardHeight * effectiveScale, 80)
                
                VStack {
                    cardSnapshotCanvas
                        .scaleEffect(effectiveScale)
                        .frame(width: scaledWidth, height: scaledHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
            } else {
                // 100% 原始尺寸模式：双向水平与垂直自由滚动平移，可仔细校对行号与字形
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack {
                        cardSnapshotCanvas
                    }
                    .padding(.horizontal, max((canvasViewportWidth - currentCardWidth) / 2, 36))
                    .padding(.vertical, 36)
                    .frame(minWidth: canvasViewportWidth, minHeight: canvasViewportHeight, alignment: .center)
                }
            }
        }
        .frame(width: canvasViewportWidth, height: canvasViewportHeight)
        .clipped()
        .onPreferenceChange(CardHeightPreferenceKey.self) { height in
            if height > 0 {
                measuredCardHeight = height
            }
        }
    }
    
    // MARK: - 右侧专业属性检查器 (Inspector Panel)
    private var inspectorPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. 外观 (APPEARANCE)
                    inspectorAppearanceSection
                    
                    Divider().opacity(0.5)
                    
                    // 2. 画幅 (CANVAS)
                    inspectorCanvasSection
                    
                    Divider().opacity(0.5)
                    
                    // 3. 内容 (CONTENT)
                    inspectorContentSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            
            Divider()
            
            // 4. 动作底栏 (ACTIONS)
            inspectorActionsBottomBar
        }
        .frame(width: inspectorWidth, height: canvasViewportHeight)
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
    }
    
    // MARK: - 检查器小节辅助视图
    private func inspectorSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.85))
            .tracking(0.6)
    }
    
    private func inspectorItemLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.secondary)
            .fixedSize()
    }
    
    // 1. 外观小节 (APPEARANCE)
    private var inspectorAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSectionHeader("Appearance".localized().uppercased())
            
            // 4x2 渐变色块矩阵
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(CardGradientPreset.allCases) { preset in
                    Button(action: {
                        config.preset = preset
                    }) {
                        Circle()
                            .fill(preset.gradient)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: config.preset == preset ? 2.5 : 0)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
            
            // 明暗外观模式
            Picker("", selection: $config.colorTheme) {
                ForEach(CardColorTheme.allCases) { theme in
                    Label(theme.displayName, systemImage: theme.iconName).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            
            // 透明底开关
            Toggle(isOn: $config.isTransparentBackground) {
                Text("Transparent".localized())
                    .font(.system(size: 11.5))
            }
            .toggleStyle(.checkbox)
        }
    }
    
    // 2. 画幅小节 (CANVAS)
    private var inspectorCanvasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSectionHeader("Canvas".localized().uppercased())
            
            // 比例 (Ratio)
            VStack(alignment: .leading, spacing: 5) {
                inspectorItemLabel("Ratio".localized())
                Picker("", selection: $config.aspectRatio) {
                    ForEach(CardAspectRatio.allCases) { ratio in
                        Text(ratio.displayName).tag(ratio)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 宽度 (Width)
            VStack(alignment: .leading, spacing: 5) {
                inspectorItemLabel("Width".localized())
                Picker("", selection: $config.cardWidthPreset) {
                    ForEach(CardWidthPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 边距 (Padding)
            VStack(alignment: .leading, spacing: 5) {
                inspectorItemLabel("Padding".localized())
                Picker("", selection: $config.padding) {
                    ForEach(CardPaddingPreset.allCases) { padding in
                        Text(padding.displayName).tag(padding)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // 3. 内容小节 (CONTENT)
    private var inspectorContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            inspectorSectionHeader("Content".localized().uppercased())
            
            if config.mode == .code {
                // 语言选择
                VStack(alignment: .leading, spacing: 5) {
                    inspectorItemLabel("Lang".localized())
                    
                    Picker("", selection: Binding(
                        get: { config.customLanguage ?? "Auto" },
                        set: { config.customLanguage = ($0 == "Auto" ? nil : $0) }
                    )) {
                        ForEach(CodeCardLanguageFormatter.popularLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // 行号开关与已聚焦清除
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $config.showLineNumbers) {
                        Text("Line Numbers".localized())
                            .font(.system(size: 11.5))
                    }
                    .toggleStyle(.checkbox)
                    
                    if !config.focusedLineIndices.isEmpty {
                        HStack {
                            Text(config.focusedLineIndices.count == 1 ? "Focused 1 line".localized() : String(format: "Focused %d lines".localized(), config.focusedLineIndices.count))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.accentColor)
                            Spacer()
                            Button("Clear".localized()) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    config.focusedLineIndices.removeAll()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                        }
                        .padding(.leading, 18)
                    }
                }
            }
            
            // 品牌水印
            Toggle(isOn: $config.showWatermark) {
                Text("Watermark".localized())
                    .font(.system(size: 11.5))
            }
            .toggleStyle(.checkbox)
        }
    }
    
    // 4. 底部动作区 (ACTIONS)
    private var inspectorActionsBottomBar: some View {
        VStack(spacing: 8) {
            Button(action: copyToPasteboard) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy Image (⌘C)".localized())
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut("c", modifiers: .command)
            
            Button(action: saveImageToDisk) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Save Image... (⌘S)".localized())
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut("s", modifiers: .command)
            
            Text("Esc Cancel · ⌘C Copy · ⌘S Save".localized())
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color.primary.opacity(0.02))
    }
    
    private func showInlineToast(message: String, icon: String?) {
        withAnimation {
            inlineToast = (message, icon)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                inlineToast = nil
            }
        }
    }
    
    private func copyToPasteboard() {
        let snapshotView = CodeCardSnapshotView(
            title: title,
            code: code,
            language: language,
            config: config,
            cardWidth: currentCardWidth
        )
        let success = CodeCardRenderer.copyImageToPasteboard(view: snapshotView, scale: 2.0)
        if success {
            showInlineToast(message: "Copied card image to clipboard".localized(), icon: "checkmark.circle.fill")
            onShowToast("Copied card image to clipboard".localized(), "checkmark.circle.fill")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss()
            }
        } else {
            showInlineToast(message: "Failed to copy image".localized(), icon: "exclamationmark.triangle.fill")
            onShowToast("Failed to copy image".localized(), "exclamationmark.triangle.fill")
        }
    }
    
    private func saveImageToDisk() {
        let snapshotView = CodeCardSnapshotView(
            title: title,
            code: code,
            language: language,
            config: config,
            cardWidth: currentCardWidth
        )
        guard let data = CodeCardRenderer.renderToPNGData(view: snapshotView, scale: 2.0) else {
            showInlineToast(message: "Failed to render image".localized(), icon: "exclamationmark.triangle.fill")
            onShowToast("Failed to render image".localized(), "exclamationmark.triangle.fill")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        let badge = CodeCardLanguageFormatter.format(
            customLanguage: config.customLanguage,
            detectedLanguage: language,
            title: title,
            code: code
        ).lowercased()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmm"
        let timestamp = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "card-\(badge)-\(timestamp).png"
        savePanel.level = .modalPanel
        
        let hostWindow = NSApp.keyWindow ?? NSApp.mainWindow
        let completionHandler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    showInlineToast(message: "Saved card image successfully".localized(), icon: "checkmark.circle.fill")
                    onShowToast("Saved card image successfully".localized(), "checkmark.circle.fill")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onDismiss()
                    }
                } catch {
                    let errorMessage = String(format: "Failed to save image: %@".localized(), error.localizedDescription)
                    showInlineToast(message: errorMessage, icon: "exclamationmark.triangle.fill")
                    onShowToast(errorMessage, "exclamationmark.triangle.fill")
                }
            }
        }
        
        if let hostWindow = hostWindow {
            savePanel.beginSheetModal(for: hostWindow, completionHandler: completionHandler)
        } else {
            savePanel.begin(completionHandler: completionHandler)
        }
    }
    
    // MARK: - 画板渲染视图
    private var cardSnapshotCanvas: some View {
        CodeCardSnapshotView(
            title: title,
            code: code,
            language: language,
            config: config,
            cardWidth: currentCardWidth,
            onToggleLineFocus: { lineIndex in
                withAnimation(.easeInOut(duration: 0.18)) {
                    if config.focusedLineIndices.contains(lineIndex) {
                        config.focusedLineIndices.remove(lineIndex)
                    } else {
                        config.focusedLineIndices.insert(lineIndex)
                    }
                }
            }
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: CardHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
    }
}

