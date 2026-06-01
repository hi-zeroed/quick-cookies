import SwiftUI
import AppKit

struct FontVariantCache {
    let regular: NSFont
    let bold: NSFont
    let italic: NSFont
    let boldItalic: NSFont
}

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
        var fontCache: FontVariantCache?
        
        func makeFontVariantCache(name: String, size: CGFloat) -> FontVariantCache {
            let baseFont = NSFont.editorFont(name: name, size: size)
            let fontManager = NSFontManager.shared
            
            let boldFont = fontManager.convert(baseFont, toHaveTrait: .boldFontMask)
            let italicFont = fontManager.convert(baseFont, toHaveTrait: .italicFontMask)
            let boldItalicFont = fontManager.convert(baseFont, toHaveTrait: [.boldFontMask, .italicFontMask])
            
            let finalBold = boldFont.pointSize == size ? boldFont : fontManager.convert(boldFont, toSize: size)
            let finalItalic = italicFont.pointSize == size ? italicFont : fontManager.convert(italicFont, toSize: size)
            let finalBoldItalic = boldItalicFont.pointSize == size ? boldItalicFont : fontManager.convert(boldItalicFont, toSize: size)
            
            return FontVariantCache(
                regular: baseFont,
                bold: finalBold,
                italic: finalItalic,
                boldItalic: finalBoldItalic
            )
        }
        
        @objc func handleScroll(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let scrollView = clipView.superview as? NSScrollView,
                  let documentView = scrollView.documentView else { return }
            
            // PERF: 同步进行前置拦截过滤，如果不需要加载更多，直接返回，避免高频向主线程队列提交垃圾 block
            guard let state = self.state,
                  state.hasMoreChunks,
                  !state.isIncrementalLoading else { return }
                  
            let visibleRect = clipView.documentVisibleRect
            let documentHeight = documentView.frame.height
            
            if visibleRect.maxY >= documentHeight - 150 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          let state = self.state,
                          state.hasMoreChunks,
                          !state.isIncrementalLoading else { return }
                    self.onLoadMore?()
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
        // NOTE: 不设置 scrollView/contentView.wantsLayer，保留 AppKit 默认的 copiesOnScroll 优化路径
        //       Layer 合成路径需要每帧合成整个 CALayer，传统路径只需复制已渲染像素+填充新露出条带
        //       对于 NSTextView 文本滚动，传统路径比 Layer 路径快得多

        // 创建 TextView
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.editorFont(name: fontName, size: fontSize)
        textView.backgroundColor = .appBackground
        textView.textColor = .appText
        textView.isRichText = false
        textView.string = content
        // NOTE: 不设置 textView.wantsLayer = true，避免在非 Layer 的 NSScrollView 中产生
        //       混合渲染上下文（Layer + 非 Layer），这会破坏 copiesOnScroll 并引入合成延迟
        
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

        // 生成字体变体缓存
        let cache = context.coordinator.makeFontVariantCache(name: fontName, size: fontSize)
        context.coordinator.fontCache = cache

        // 首次加载语法高亮
        loadSyntaxHighlightFirstTime(for: textView, isDark: isDark, fontCache: cache)

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

        // 动态更新字体变体缓存
        if fontChanged || context.coordinator.fontCache == nil {
            context.coordinator.fontCache = context.coordinator.makeFontVariantCache(name: fontName, size: fontSize)
        }
        let cache = context.coordinator.fontCache!

        // 动态更新背景色和文本色
        scrollView.backgroundColor = .appBackground
        textView.backgroundColor = .appBackground
        textView.textColor = .appText

        if isIncremental {
            // 增量追加段落
            let newText = String(content[content.index(content.startIndex, offsetBy: currentLength)...])
            appendChunk(newText: newText, for: textView, isDark: isDark, fontCache: cache)
            context.coordinator.lastContentLength = textView.textStorage?.length ?? 0
        } else if !isSameFile || isDarkChanged || fontChanged {
            // 首次加载、修改主题或字体
            textView.string = content
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            loadSyntaxHighlightFirstTime(for: textView, isDark: isDark, fontCache: cache)
        }
    }

    /// 首次异步语法高亮（首屏 500 行秒开展示 + 后台全量高亮平滑刷入）
    private func loadSyntaxHighlightFirstTime(for textView: NSTextView, isDark: Bool, fontCache: FontVariantCache) {
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
                    let customAttributed = attributed.applyingFontCache(fontCache)
                    
                    HighlightCache.shared.set(customAttributed, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
                    
                    DispatchQueue.main.async {
                        // NOTE: 直接替换，无 CATransition 动画
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
                
                let customFirst = firstAttributed.applyingFontCache(fontCache)
                let tempFull = NSMutableAttributedString(attributedString: customFirst)
                
                let remainAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.editorFont(name: fontName, size: fontSize),
                    .foregroundColor: isDark ? NSColor(white: 0.85, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
                ]
                let remainAttributed = NSAttributedString(string: remainPart, attributes: remainAttributes)
                tempFull.append(remainAttributed)
                
                DispatchQueue.main.async {
                    textView.textStorage?.setAttributedString(tempFull)
                }
                
                // 随后在后台默默做首段文本的全量高亮（使用 utility 优先级避免与主线程滚动抢占 CPU 资源）
                DispatchQueue.global(qos: .utility).async {
                    guard let fullAttributed = highlighter.highlight(code: fullContent, language: language, theme: themeName) else { return }
                    let customFull = fullAttributed.applyingFontCache(fontCache)
                    
                    HighlightCache.shared.set(customFull, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
                    
                    DispatchQueue.main.async {
                        guard textView.string == fullContent,
                              let textStorage = textView.textStorage else { return }
                        // PERF: 使用 beginEditing/endEditing 局部更新样式属性，而不是 setAttributedString 整体替换
                        // 字符内容没有改变，仅改变颜色样式，LayoutManager 不会清空已有的布局和高度缓存，滚动时无顿挫感
                        textStorage.beginEditing()
                        customFull.enumerateAttributes(in: NSRange(location: 0, length: customFull.length), options: []) { attrs, range, _ in
                            textStorage.setAttributes(attrs, range: range)
                        }
                        textStorage.endEditing()
                    }
                }
            }
        }
    }

    /// 增量追加新片段（新文本在主线程追加呈现，后台头部起算高亮以保证完美着色，完成后刷入属性）
    private func appendChunk(newText: String, for textView: NSTextView, isDark: Bool, fontCache: FontVariantCache) {
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
        
        // 2. 后台执行全量高亮，保障边界着色完美连续（使用 utility 优先级避免与滚动竞争 CPU）
        let themeName = isDark ? "atom-one-dark" : "atom-one-light"
        let modDate = FileUtils.getModificationDate(at: filePath)
        let fullText = previousFullText + newText
        
        DispatchQueue.global(qos: .utility).async {
            guard let highlighter = SyntaxHighlighter.shared,
                  let fullAttributed = highlighter.highlight(code: fullText, language: language, theme: themeName) else {
                return
            }
            
            // 3. 裁剪出新加入的片段的高亮属性
            let newPartRange = NSRange(location: previousFullText.count, length: newText.count)
            let highlightedNewPart = fullAttributed.attributedSubstring(from: newPartRange).applyingFontCache(fontCache)
            
            // 4. 将高亮完 of fullText 富文本覆盖写入缓存，以便下一次秒开
            let customFull = fullAttributed.applyingFontCache(fontCache)
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
    /// 遍历富文本属性，将默认高亮字体替换为指定的编辑器字体与字号，同时通过 NSFontManager 保留原有的粗体/斜体特征（用于主线程中的其它同步高亮，如 Markdown 中的小代码块）
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

    /// 遍历富文本属性，仅使用纯位运算从 FontVariantCache 映射字体，不调用任何全局字体锁相关的 NSFontManager，保证后台线程的绝对安全与极致性能
    func applyingFontCache(_ cache: FontVariantCache) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: self)
        mutable.beginEditing()
        
        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length), options: []) { value, range, _ in
            guard let oldFont = value as? NSFont else { return }
            
            let symbolicTraits = oldFont.fontDescriptor.symbolicTraits
            let isBold = symbolicTraits.contains(.bold)
            let isItalic = symbolicTraits.contains(.italic)
            
            let newFont: NSFont
            if isBold && isItalic {
                newFont = cache.boldItalic
            } else if isBold {
                newFont = cache.bold
            } else if isItalic {
                newFont = cache.italic
            } else {
                newFont = cache.regular
            }
            
            mutable.addAttribute(.font, value: newFont, range: range)
        }
        
        mutable.endEditing()
        return mutable
    }
}