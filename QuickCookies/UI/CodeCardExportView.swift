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
    var cardWidth: CGFloat = 620
    
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
            return cardWidth
        case .landscape:
            return cardWidth * 9.0 / 16.0
        }
    }
    
    var body: some View {
        ZStack {
            // 1. 同源漫反射环境柔光 (Ambient Glow)
            if config.showAmbientGlow && !config.isTransparentBackground {
                config.preset.gradient
                    .frame(width: cardWidth * 0.94, height: (targetHeight ?? 240) * 0.94)
                    .blur(radius: 34)
                    .opacity(config.colorTheme == .dark ? 0.46 : 0.28)
                    .offset(y: 12)
            }
            
            // 2. 主卡片外框：艺术渐变背景 或 透明背景
            ZStack {
                if !config.isTransparentBackground {
                    config.preset.gradient
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
                        .stroke(cardBorderColor, lineWidth: 0.8)
                )
                .shadow(
                    color: Color.black.opacity(config.colorTheme == .dark ? 0.35 : 0.12),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .padding(config.padding.rawValue)
            }
            .frame(width: cardWidth, height: targetHeight)
            .fixedSize(horizontal: true, vertical: targetHeight != nil)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .frame(width: cardWidth)
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

    // MARK: - 代码视图排版 (支持上下文语法高亮与行号自适应)
    private var codeContentView: some View {
        let lines = highlightedCodeLines
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, attrLine in
                HStack(alignment: .top, spacing: 14) {
                    if config.showLineNumbers {
                        Text("\(index + 1)")
                            .font(lineNumFont)
                            .foregroundColor(secondaryTextColor.opacity(0.65))
                            .frame(minWidth: 26, alignment: .trailing)
                    }
                    
                    Text(attrLine)
                        .font(codeFont)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .id("\(effectiveHighlighterLanguage ?? "none")-\(config.colorTheme.rawValue)-\(Settings.shared.editorFont)-\(index)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    private let cardWidth: CGFloat = 620
    private let modalWidth: CGFloat = 720
    
    private var canvasHeight: CGFloat {
        // 当选择固定比例时，直接根据比例固定高度
        switch config.aspectRatio {
        case .square:
            return 480
        case .landscape:
            return 380
        case .auto:
            let ideal = measuredCardHeight + 52
            return min(max(ideal, 190), 470)
        }
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
                // 1. 顶部标题栏 + 模式分段器 + 快捷关闭
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
                    .frame(width: 220)
                    
                    Spacer()
                    
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
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
                
                Divider()
                
                // 2. 中部画板展示区：点阵网格设计工作台 (Dot Matrix Canvas) + 漫反射光晕
                ScrollView([.vertical], showsIndicators: true) {
                    VStack {
                        CodeCardSnapshotView(
                            title: title,
                            code: code,
                            language: language,
                            config: config,
                            cardWidth: cardWidth
                        )
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: CardHeightPreferenceKey.self, value: proxy.size.height)
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
                }
                .frame(height: canvasHeight)
                .background(
                    ZStack {
                        Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.85)
                        DotMatrixCanvasView()
                    }
                )
                .overlay(
                    Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .onPreferenceChange(CardHeightPreferenceKey.self) { height in
                    if height > 0 {
                        measuredCardHeight = height
                    }
                }
                
                Divider()
                
                // 3. 下部参数微调栏 (Pro Studio Controls)
                VStack(spacing: 12) {
                    // 第 1 排：主题颜色选择 + 明暗模式切换 + 社交比例预设
                    HStack(spacing: 18) {
                        // 艺术渐变主题选择器
                        HStack(spacing: 8) {
                            Text("Theme".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach(CardGradientPreset.allCases) { preset in
                                    Button(action: {
                                        config.preset = preset
                                    }) {
                                        Circle()
                                            .fill(preset.gradient)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: config.preset == preset ? 2.5 : 0)
                                            )
                                            .shadow(color: .black.opacity(0.3), radius: 3)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // 明暗主题切换 (Dark 🌙 / Light ☀️)
                        Picker("", selection: $config.colorTheme) {
                            ForEach(CardColorTheme.allCases) { theme in
                                Label(theme.displayName, systemImage: theme.iconName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                        
                        // 比例预设 (Auto / 1:1 / 16:9)
                        HStack(spacing: 6) {
                            Text("Aspect Ratio".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $config.aspectRatio) {
                                ForEach(CardAspectRatio.allCases) { ratio in
                                    Text(ratio.displayName).tag(ratio)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 第 2 排：边距选择 + 语言微调(代码模式) + 透明底开关 + 行号开关 + 水印开关
                    HStack(spacing: 16) {
                        // 边距档位
                        HStack(spacing: 6) {
                            Text("Padding".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $config.padding) {
                                ForEach(CardPaddingPreset.allCases) { padding in
                                    Text(padding.displayName).tag(padding)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 155)
                        }
                        
                        // 语言微调 (仅代码模式，支持自选 TSX, JS, JAVA, SWIFT 等)
                        if config.mode == .code {
                            HStack(spacing: 6) {
                                Text("Language".localized())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: Binding(
                                    get: { config.customLanguage ?? "Auto" },
                                    set: { config.customLanguage = ($0 == "Auto" ? nil : $0) }
                                )) {
                                    ForEach(CodeCardLanguageFormatter.popularLanguages, id: \.self) { lang in
                                        Text(lang).tag(lang)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 88)
                            }
                        }
                        
                        // 透明底导出开关
                        Toggle(isOn: $config.isTransparentBackground) {
                            Text("Transparent".localized())
                                .font(.system(size: 12))
                        }
                        .toggleStyle(.checkbox)
                        
                        Spacer()
                        
                        // 行号开关 (仅在代码模式下展示)
                        if config.mode == .code {
                            Toggle(isOn: $config.showLineNumbers) {
                                Text("Line Numbers".localized())
                                    .font(.system(size: 12))
                            }
                            .toggleStyle(.checkbox)
                        }
                        
                        // 水印开关
                        Toggle(isOn: $config.showWatermark) {
                            Text("Watermark".localized())
                                .font(.system(size: 12))
                        }
                        .toggleStyle(.checkbox)
                    }
                    .padding(.horizontal, 20)
                    
                    // 第 3 排：底部动作按钮
                    HStack(spacing: 14) {
                        Button(action: onDismiss) {
                            Text("Cancel".localized())
                                .frame(minWidth: 70)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        
                        Spacer()
                        
                        Button(action: copyToPasteboard) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy Image (⌘C)".localized())
                            }
                            .frame(minWidth: 130)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .keyboardShortcut("c", modifiers: .command)
                        
                        Button(action: saveImageToDisk) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Image... (⌘S)".localized())
                            }
                            .frame(minWidth: 130)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .keyboardShortcut("s", modifiers: .command)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 14)
                .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            }
            .frame(width: modalWidth)
            .background(Color.appBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 36, y: 16)
            .animation(.easeInOut(duration: 0.2), value: canvasHeight)
            
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
            cardWidth: cardWidth
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
            cardWidth: cardWidth
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
        let timestamp = Int(Date().timeIntervalSince1970)
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
                    showInlineToast(message: "Failed to save image: \(error.localizedDescription)", icon: "exclamationmark.triangle.fill")
                    onShowToast("Failed to save image: \(error.localizedDescription)", "exclamationmark.triangle.fill")
                }
            }
        }
        
        if let hostWindow = hostWindow {
            savePanel.beginSheetModal(for: hostWindow, completionHandler: completionHandler)
        } else {
            savePanel.begin(completionHandler: completionHandler)
        }
    }
}
