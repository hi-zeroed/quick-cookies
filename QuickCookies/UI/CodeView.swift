import SwiftUI
import AppKit

struct CodeView: NSViewRepresentable {
    let filePath: String
    let content: String
    let language: String?
    let fontSize: CGFloat
    let fontName: String
    let isDark: Bool
    let state: PreviewState
    let onLoadMore: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var lastIsDark: Bool?
        var lastFontName: String?
        var lastFilePath: String?
        var lastContentLength: Int = 0   // NOTE: 用长度缓存替代 O(n) 字符串前缀比较
        var state: PreviewState?
        var onLoadMore: (() -> Void)?
        
        @objc func handleScroll(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let scrollView = clipView.superview as? NSScrollView,
                  let documentView = scrollView.documentView else { return }
            
            let visibleRect = clipView.documentVisibleRect
            let documentHeight = documentView.frame.height
            
            // 将状态判断与闭包调用派发至下一个 RunLoop，彻底根治 SwiftUI 渲染周期内同步更新状态的 Fault
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let state = self.state else { return }
                
                if visibleRect.maxY >= documentHeight - 150 {
                    if state.hasMoreChunks && !state.isIncrementalLoading {
                        self.onLoadMore?()
                    }
                }
            }
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        scrollView.backgroundColor = .appBackground
        scrollView.drawsBackground = true
        
        // PERF: 启用 Layer 异步合成滑动，走 GPU 层合成路径而非 legacy CPU draw-on-scroll
        scrollView.wantsLayer = true
        scrollView.contentView.wantsLayer = true

        // 创建 TextView
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.editorFont(name: fontName, size: fontSize)
        textView.backgroundColor = .appBackground
        textView.textColor = .appText
        textView.isRichText = false
        textView.string = content
        textView.wantsLayer = true
        
        // 增加四周留白
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // PERF: 核心性能修复！未开启时， NSLayoutManager 必须从第 1 行开始
        //       顺序同步计算到当前滚动位置的全部布局。大文件滚动到某行需要将该行之前
        //       的所有内容全部先行布局，O(n) 主线程阀塞导致滚动卡顿。
        //       开启后只对可见区域附近按需布局，滚动帧率恒保 60fps。
        textView.layoutManager?.allowsNonContiguousLayout = true
        
        // PERF: 禁用所有文本自动处理特性，这些功能在布局期间对每个字符额外消耗 CPU
        //       对于代码预览模式完全无意义
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        scrollView.documentView = textView

        // 滚动到顶部（显示首行）
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))

        // 注册滚动监听
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // 首次加载语法高亮
        loadSyntaxHighlightFirstTime(for: textView, isDark: isDark)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 传递最新的回调与状态引用给 Coordinator
        context.coordinator.state = state
        context.coordinator.onLoadMore = onLoadMore

        let isSameFile = context.coordinator.lastFilePath == filePath
        // NOTE: 用长度对比替代 O(n) 的 content.hasPrefix(textView.string)，避免大文件在 updateNSView 每次都做全量字符串扫描
        let cachedLength = context.coordinator.lastContentLength
        let currentLength = textView.textStorage?.length ?? 0
        let isIncremental = isSameFile && content.count > currentLength && currentLength == cachedLength

        let fontChanged = textView.font?.pointSize != fontSize || context.coordinator.lastFontName != fontName
        let isDarkChanged = context.coordinator.lastIsDark != isDark

        context.coordinator.lastIsDark = isDark
        context.coordinator.lastFontName = fontName
        context.coordinator.lastFilePath = filePath
        context.coordinator.lastContentLength = textView.textStorage?.length ?? 0

        // 动态更新背景色和文本色
        scrollView.backgroundColor = .appBackground
        textView.backgroundColor = .appBackground
        textView.textColor = .appText

        if isIncremental {
            // 增量追加段落
            let newText = String(content[content.index(content.startIndex, offsetBy: currentLength)...])
            appendChunk(newText: newText, for: textView, isDark: isDark)
            context.coordinator.lastContentLength = textView.textStorage?.length ?? 0
        } else if !isSameFile || isDarkChanged || fontChanged {
            // 首次加载、修改主题或字体
            textView.string = content
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            loadSyntaxHighlightFirstTime(for: textView, isDark: isDark)
        }
    }

    /// 首次异步语法高亮（首屏 500 行秒开展示 + 后台全量高亮平滑刷入）
    private func loadSyntaxHighlightFirstTime(for textView: NSTextView, isDark: Bool) {
        guard let language = language else { return }
        
        let modDate = FileUtils.getModificationDate(at: filePath)
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        
        // 尝试从内存缓存中直接匹配高亮文本
        if let cached = HighlightCache.shared.get(for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate) {
            textView.textStorage?.setAttributedString(cached)
            return
        }

        let fullContent = content
        
        DispatchQueue.global(qos: .userInteractive).async {
            let lines = fullContent.components(separatedBy: "\n")
            
            if lines.count <= 1000 {
                // 中小文件：直接一次性后台高亮并缓存，极速呈现
                if let highlighter = SyntaxHighlighter.shared,
                   let attributed = highlighter.highlight(code: fullContent, language: language, theme: themeName) {
                    let customAttributed = attributed.applyingEditorFont(name: fontName, size: fontSize)
                    
                    HighlightCache.shared.set(customAttributed, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
                    
                    DispatchQueue.main.async {
                        let transition = CATransition()
                        transition.type = .fade
                        transition.duration = 0.25
                        textView.layer?.add(transition, forKey: kCATransition)
                        textView.textStorage?.setAttributedString(customAttributed)
                    }
                }
            } else {
                // 超大文件首段：先高亮前 500 行，剩下普通文本显示，实现窗口 0ms 秒开
                let firstPart = lines[0..<500].joined(separator: "\n")
                let remainPart = "\n" + lines[500...].joined(separator: "\n")
                
                guard let highlighter = SyntaxHighlighter.shared,
                      let firstAttributed = highlighter.highlight(code: firstPart, language: language, theme: themeName) else {
                    return
                }
                
                let customFirst = firstAttributed.applyingEditorFont(name: fontName, size: fontSize)
                let tempFull = NSMutableAttributedString(attributedString: customFirst)
                
                let remainAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.editorFont(name: fontName, size: fontSize),
                    .foregroundColor: isDark ? NSColor(white: 0.85, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
                ]
                let remainAttributed = NSAttributedString(string: remainPart, attributes: remainAttributes)
                tempFull.append(remainAttributed)
                
                DispatchQueue.main.async {
                    let transition = CATransition()
                    transition.type = .fade
                    transition.duration = 0.20
                    textView.layer?.add(transition, forKey: kCATransition)
                    textView.textStorage?.setAttributedString(tempFull)
                }
                
                // 随后在后台默默做首段文本的全量高亮
                DispatchQueue.global(qos: .utility).async {
                    guard let fullAttributed = highlighter.highlight(code: fullContent, language: language, theme: themeName) else { return }
                    let customFull = fullAttributed.applyingEditorFont(name: fontName, size: fontSize)
                    
                    HighlightCache.shared.set(customFull, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
                    
                DispatchQueue.main.async {
                        guard textView.string == fullContent else { return }
                        // NOTE: 使用 setAttributedString 一次性整体替换，
                        // 性能远优于 enumerateAttributes 逐 range setAttributes（O(n) 主线程阻塞）
                        // NSTextStorage 内部会自动做最小化 diff 优化
                        textView.textStorage?.setAttributedString(customFull)
                    }
                }
            }
        }
    }

    /// 增量追加新片段（新文本在主线程追加呈现，后台头部起算高亮以保证完美着色，完成后刷入属性）
    private func appendChunk(newText: String, for textView: NSTextView, isDark: Bool) {
        guard let textStorage = textView.textStorage else { return }
        
        let originalLength = textStorage.length
        let previousFullText = textView.string
        
        // 1. 瞬间在主线程把普通文本追加上去，使滚动区域变大，滚动条拉长，体验不卡顿
        let font = NSFont.editorFont(name: fontName, size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isDark ? NSColor(white: 0.85, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
        ]
        let appendedAttrString = NSAttributedString(string: newText, attributes: attributes)
        
        textStorage.append(appendedAttrString)
        
        // 如果没有 language，说明是 plainText 模式，无需高亮
        guard let language = language else { return }
        
        // 2. 后台从文件头部（0字节）起算执行全量高亮，保障边界着色完美连续
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        let modDate = FileUtils.getModificationDate(at: filePath)
        let fullText = previousFullText + newText
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let highlighter = SyntaxHighlighter.shared,
                  let fullAttributed = highlighter.highlight(code: fullText, language: language, theme: themeName) else {
                return
            }
            
            // 3. 裁剪出新加入的片段的高亮属性
            let newPartRange = NSRange(location: previousFullText.count, length: newText.count)
            let highlightedNewPart = fullAttributed.attributedSubstring(from: newPartRange).applyingEditorFont(name: fontName, size: fontSize)
            
            // 4. 将高亮完的 fullText 富文本覆盖写入缓存，以便下一次秒开
            let customFull = fullAttributed.applyingEditorFont(name: fontName, size: fontSize)
            HighlightCache.shared.set(customFull, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
            
            // 5. 主线程中在原地仅以 setAttributes 刷入新的属性
            DispatchQueue.main.async {
                guard textView.string == fullText else { return }
                
                textStorage.beginEditing()
                highlightedNewPart.enumerateAttributes(in: NSRange(location: 0, length: highlightedNewPart.length), options: []) { attrs, range, _ in
                    let translatedRange = NSRange(location: originalLength + range.location, length: range.length)
                    textStorage.setAttributes(attrs, range: translatedRange)
                }
                textStorage.endEditing()
            }
        }
    }
}

extension NSAttributedString {
    /// 遍历富文本属性，将默认高亮字体替换为指定的编辑器字体与字号，同时通过 NSFontManager 保留原有的粗体/斜体特征
    func applyingEditorFont(name: String, size: CGFloat) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        mutable.beginEditing()
        
        let targetBaseFont = NSFont.editorFont(name: name, size: size)
        
        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let oldFont = value as? NSFont else { return }
            
            // 使用 NSFontManager 检测字体的 bold/italic traits，避免直接读取 symbolicTraits 发生转换丢失
            let traits = NSFontManager.shared.traits(of: oldFont)
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)
            
            var newFont = targetBaseFont
            
            if isBold && isItalic {
                newFont = NSFontManager.shared.convert(newFont, toHaveTrait: [.boldFontMask, .italicFontMask])
            } else if isBold {
                newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .boldFontMask)
            } else if isItalic {
                newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .italicFontMask)
            }
            
            if newFont.pointSize != size {
                newFont = NSFontManager.shared.convert(newFont, toSize: size)
            }
            
            mutable.addAttribute(.font, value: newFont, range: range)
        }
        
        mutable.endEditing()
        return mutable
    }
}