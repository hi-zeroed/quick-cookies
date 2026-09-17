import SwiftUI
import AppKit
import Combine

enum CodeViewTextColorPolicy {
    static func shouldApplyTextViewTextColor(language: String?) -> Bool {
        true
    }
}

struct FontVariantCache {
    let regular: NSFont
    let bold: NSFont
    let italic: NSFont
    let boldItalic: NSFont
}

struct CodeViewRenderIdentity: Equatable {
    let filePath: String
    let contentLength: Int
    let contentHash: Int
    let language: String?
    let themeName: String
    let fontName: String
    let fontSize: CGFloat
}

enum CodeViewAsyncRenderPolicy {
    static func shouldApply(
        capturedIdentity: CodeViewRenderIdentity,
        currentIdentity: CodeViewRenderIdentity?,
        capturedContent: String,
        currentText: String
    ) -> Bool {
        capturedIdentity == currentIdentity && capturedContent == currentText
    }
}

enum CodeViewRepresentableUpdatePolicy {
    static func shouldSkipRenderSync(
        previousIdentity: CodeViewRenderIdentity?,
        nextIdentity: CodeViewRenderIdentity
    ) -> Bool {
        previousIdentity == nextIdentity
    }
}

enum CodeViewHighlightFallbackPolicy {
    static func attributedText(
        highlighted: NSAttributedString?,
        fallbackContent: String,
        fontName: String,
        fontSize: CGFloat,
        isDark: Bool,
        fontCache: FontVariantCache? = nil
    ) -> NSAttributedString {
        if let highlighted {
            if let fontCache {
                return highlighted.applyingFontCache(fontCache)
            }
            return highlighted.applyingEditorFont(name: fontName, size: fontSize)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.editorFont(name: fontName, size: fontSize),
            .foregroundColor: isDark ? NSColor(white: 0.85, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
        ]
        return NSAttributedString(string: fallbackContent, attributes: attributes)
    }
}

struct CodeView: NSViewRepresentable {
    let filePath: String
    let content: String
    let language: String?
    let fontSize: CGFloat
    let fontName: String
    let isDark: Bool
    let loadState: PreviewLoadState
    let onLoadMore: () -> Void
    var findBarState: FindBarState? = nil
    var goToLineState: GoToLineState? = nil
    var liveWatchingState: LiveWatchingState? = nil
    var gitDiffState: GitDiffState? = nil
    var initialTargetLine: Int? = nil
    var onInitialTargetLineConsumed: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private var themeName: String {
        isDark ? "atom-one-dark" : "atom-one-light"
    }

    private var renderIdentity: CodeViewRenderIdentity {
        CodeViewRenderIdentity(
            filePath: filePath,
            contentLength: content.count,
            contentHash: content.hashValue,
            language: language,
            themeName: themeName,
            fontName: fontName,
            fontSize: fontSize
        )
    }

    class Coordinator: NSObject {
        var lastIsDark: Bool?
        var lastFontName: String?
        var lastFontSize: CGFloat?       // NOTE: 缓存字号以防高亮富文本首字字形覆盖导致误判 fontChanged
        var lastFilePath: String?
        var lastContentLength: Int = 0   // NOTE: 用长度缓存替代 O(n) 字符串前缀比较
        var lastRenderedContent: String = ""
        var loadState: PreviewLoadState?
        var onLoadMore: (() -> Void)?
        var fontCache: FontVariantCache?
        var currentRenderIdentity: CodeViewRenderIdentity?
        
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
        
        @objc @MainActor func handleScroll(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let scrollView = clipView.superview as? NSScrollView,
                  let documentView = scrollView.documentView else { return }
            
            let visibleRect = clipView.documentVisibleRect
            let documentHeight = documentView.frame.height

            // 监听日志追尾模式下的用户手动滚离/滚回底端状态
            if let liveState = self.liveWatchingState, liveState.isLiveTailMode {
                let distanceToBottom = documentHeight - visibleRect.maxY
                if distanceToBottom > 40 {
                    liveState.userScrolledAwayFromBottom()
                } else if distanceToBottom <= 15 {
                    liveState.userScrolledToBottom()
                }
            }

            // PERF: 同步进行前置拦截过滤，如果不需要加载更多，直接返回，避免高频向主线程队列提交垃圾 block
            guard let loadState = self.loadState,
                  loadState.hasMoreChunks,
                  !loadState.isIncrementalLoading else { return }
                  
            if visibleRect.maxY >= documentHeight - 150 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          let loadState = self.loadState,
                          loadState.hasMoreChunks,
                          !loadState.isIncrementalLoading else { return }
                    self.onLoadMore?()
                }
            }
        }

        var findBarCancellables = Set<AnyCancellable>()
        var goToLineCancellables = Set<AnyCancellable>()
        var liveWatchingCancellables = Set<AnyCancellable>()
        var gitDiffCancellables = Set<AnyCancellable>()
        weak var textView: NSTextView?
        var findBarState: FindBarState?
        var goToLineState: GoToLineState?
        var liveWatchingState: LiveWatchingState?
        weak var gitDiffState: GitDiffState?
        var activeGitDiffRanges: [NSRange] = []
        var currentMatches: [NSRange] = []
        private var activePulseRange: NSRange?
        private var pulseWorkItem: DispatchWorkItem?
        var hasConsumedInitialTargetLine: Bool = false
        private var lastCalculatedLineCount: Int?
        private var lastCalculatedContentHash: Int?

        /// 缓存计算总行数，避免在没有内容变动的 updateNSView 周期重复切分超大文本
        func calculateTotalLines(for content: String) -> Int {
            let contentHash = content.hashValue
            if let cached = lastCalculatedLineCount, lastCalculatedContentHash == contentHash {
                return cached
            }
            let count = max(1, (content as NSString).components(separatedBy: "\n").count)
            lastCalculatedContentHash = contentHash
            lastCalculatedLineCount = count
            return count
        }

        func setupFindBarSubscription(findBarState: FindBarState?, textView: NSTextView) {
            findBarCancellables.removeAll()
            self.findBarState = findBarState
            self.textView = textView

            guard let findBarState = findBarState else {
                clearSearchHighlights(in: textView)
                return
            }

            findBarState.$query
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] query in
                    guard let self = self, let textView = textView else { return }
                    self.performSearch(query: query, in: textView)
                }
                .store(in: &findBarCancellables)

            findBarState.$isPresented
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] isPresented in
                    guard let self = self, let textView = textView else { return }
                    if !isPresented {
                        self.clearSearchHighlights(in: textView)
                    } else if !findBarState.query.isEmpty {
                        self.performSearch(query: findBarState.query, in: textView)
                    }
                }
                .store(in: &findBarCancellables)

            findBarState.findNextTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] in
                    guard let self = self, let textView = textView else { return }
                    self.nextMatch(in: textView)
                }
                .store(in: &findBarCancellables)

            findBarState.findPreviousTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] in
                    guard let self = self, let textView = textView else { return }
                    self.previousMatch(in: textView)
                }
                .store(in: &findBarCancellables)

            if findBarState.isPresented && !findBarState.query.isEmpty {
                performSearch(query: findBarState.query, in: textView)
            }
        }

        func setupGoToLineSubscription(goToLineState: GoToLineState?, textView: NSTextView) {
            goToLineCancellables.removeAll()
            self.goToLineState = goToLineState
            self.textView = textView

            guard let goToLineState = goToLineState else { return }

            goToLineState.jumpToLineTrigger
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] line in
                    guard let self = self, let textView = textView else { return }
                    self.jumpToLine(line, in: textView, pulse: true)
                }
                .store(in: &goToLineCancellables)
        }

        func setupLiveWatchingSubscription(liveWatchingState: LiveWatchingState?, textView: NSTextView) {
            liveWatchingCancellables.removeAll()
            self.liveWatchingState = liveWatchingState
            self.textView = textView

            guard let liveWatchingState = liveWatchingState else { return }

            liveWatchingState.scrollToBottomSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak textView] in
                    guard let textView = textView else { return }
                    let textLength = (textView.string as NSString).length
                    let bottomRange = NSRange(location: textLength, length: 0)
                    textView.scrollRangeToVisible(bottomRange)
                }
                .store(in: &liveWatchingCancellables)
        }

        @MainActor
        func setupGitDiffSubscription(gitDiffState: GitDiffState?, textView: NSTextView) {
            gitDiffCancellables.removeAll()
            self.gitDiffState = gitDiffState
            self.textView = textView

            guard let gitDiffState = gitDiffState else {
                clearGitDiffHighlights(in: textView)
                return
            }

            gitDiffState.jumpToLineSubject
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] line in
                    guard let self = self, let textView = textView else { return }
                    self.jumpToLine(line, in: textView, pulse: true)
                }
                .store(in: &gitDiffCancellables)

            gitDiffState.$report
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak textView] _ in
                    guard let self = self, let textView = textView else { return }
                    self.applyGitDiffHighlights(in: textView)
                }
                .store(in: &gitDiffCancellables)
        }

        @MainActor
        func clearGitDiffHighlights(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager else { return }
            for range in activeGitDiffRanges {
                if range.location + range.length <= (textView.textStorage?.length ?? 0) {
                    layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
                }
            }
            activeGitDiffRanges.removeAll()
        }

        @MainActor
        func applyGitDiffHighlights(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage,
                  let gitDiffState = gitDiffState else {
                clearGitDiffHighlights(in: textView)
                return
            }

            clearGitDiffHighlights(in: textView)

            let report = gitDiffState.report
            guard report.status == .modified, !report.changedLines.isEmpty else { return }

            let text = (textView.string as NSString)
            guard text.length > 0 else { return }

            var lineRanges: [NSRange] = []
            var index = 0
            let length = text.length
            while index < length {
                let lineRange = text.lineRange(for: NSRange(location: index, length: 0))
                lineRanges.append(lineRange)
                index = NSMaxRange(lineRange)
            }

            let isDark = self.lastIsDark ?? false
            let greenColor = NSColor.systemGreen.withAlphaComponent(isDark ? 0.16 : 0.10)
            let orangeColor = NSColor.systemOrange.withAlphaComponent(isDark ? 0.18 : 0.12)

            for (lineNum, diffType) in report.changedLines {
                guard lineNum >= 1, lineNum <= lineRanges.count else { continue }
                let range = lineRanges[lineNum - 1]
                guard range.location + range.length <= textStorage.length else { continue }

                let color: NSColor
                switch diffType {
                case .added:
                    color = greenColor
                case .modified:
                    color = orangeColor
                case .deleted:
                    continue
                }

                layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
                activeGitDiffRanges.append(range)
            }
        }

        /// 精准跳转至指定行号（1-indexed），并将目标行平滑居中展示，触发脉冲微光
        func jumpToLine(_ targetLine: Int, in textView: NSTextView, pulse: Bool = true) {
            let text = (textView.string as NSString)
            guard text.length > 0, targetLine >= 1 else { return }

            var currentLine = 1
            var index = 0
            let length = text.length
            var foundRange: NSRange? = nil

            while index < length {
                let lineRange = text.lineRange(for: NSRange(location: index, length: 0))
                if currentLine == targetLine {
                    foundRange = lineRange
                    break
                }
                currentLine += 1
                index = NSMaxRange(lineRange)
            }

            let lineRange = foundRange ?? text.lineRange(for: NSRange(location: max(0, length - 1), length: 0))

            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                textView.scrollRangeToVisible(lineRange)
                return
            }

            // 1. 视口滚动并垂直居中
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            if let scrollView = textView.enclosingScrollView {
                let clipView = scrollView.contentView
                let visibleHeight = clipView.bounds.height
                let targetY = max(0, rect.origin.y - (visibleHeight - rect.height) / 2)
                clipView.scroll(to: NSPoint(x: 0, y: targetY))
                scrollView.reflectScrolledClipView(clipView)
            } else {
                textView.scrollRangeToVisible(lineRange)
            }

            // 2. 原生系统指示圈
            textView.showFindIndicator(for: lineRange)

            // 3. 脉冲高亮动效（1.2s 平滑淡出）
            if pulse {
                applyLinePulseHighlight(lineRange: lineRange, in: textView)
            }
        }

        func applyLinePulseHighlight(lineRange: NSRange, in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager else { return }

            pulseWorkItem?.cancel()
            if let prev = activePulseRange, prev.location + prev.length <= (textView.textStorage?.length ?? 0) {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: prev)
            }

            activePulseRange = lineRange
            let pulseColor = NSColor.systemYellow.withAlphaComponent(0.38)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: pulseColor, forCharacterRange: lineRange)

            let item = DispatchWorkItem { [weak self, weak textView] in
                guard let self = self, let textView = textView, let lm = textView.layoutManager else { return }
                if let current = self.activePulseRange, current.location + current.length <= (textView.textStorage?.length ?? 0) {
                    lm.removeTemporaryAttribute(.backgroundColor, forCharacterRange: current)
                    self.activePulseRange = nil
                }
            }
            pulseWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
        }


        func performSearch(query: String, in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
            currentMatches.removeAll()

            guard !query.isEmpty else {
                DispatchQueue.main.async { [weak self] in
                    self?.findBarState?.totalMatches = 0
                    self?.findBarState?.currentMatchIndex = 0
                }
                return
            }

            let text = (textView.string as NSString)
            var searchRange = NSRange(location: 0, length: text.length)

            while searchRange.location < text.length {
                searchRange.length = text.length - searchRange.location
                let foundRange = text.range(of: query, options: .caseInsensitive, range: searchRange)
                if foundRange.location != NSNotFound {
                    currentMatches.append(foundRange)
                    searchRange.location = foundRange.location + max(foundRange.length, 1)
                } else {
                    break
                }
            }

            let total = currentMatches.count
            let activeIdx = !currentMatches.isEmpty ? 1 : 0

            DispatchQueue.main.async { [weak self] in
                self?.findBarState?.totalMatches = total
                self?.findBarState?.currentMatchIndex = activeIdx
            }

            if !currentMatches.isEmpty {
                applyMatchHighlights(in: textView, activeMatchIndex: activeIdx)
                scrollToMatch(at: activeIdx, in: textView)
            }
        }

        /// 当大文件追加内容或异步高亮覆写后，重新计算匹配项并刷新高亮，保持当前浏览位置不跳变
        func refreshSearchPreservingPosition(in textView: NSTextView) {
            guard let findBarState = findBarState,
                  findBarState.isPresented,
                  !findBarState.query.isEmpty else { return }

            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage else { return }

            let previousIndex = findBarState.currentMatchIndex
            let query = findBarState.query

            let fullRange = NSRange(location: 0, length: textStorage.length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
            currentMatches.removeAll()

            let text = (textView.string as NSString)
            var searchRange = NSRange(location: 0, length: text.length)

            while searchRange.location < text.length {
                searchRange.length = text.length - searchRange.location
                let foundRange = text.range(of: query, options: .caseInsensitive, range: searchRange)
                if foundRange.location != NSNotFound {
                    currentMatches.append(foundRange)
                    searchRange.location = foundRange.location + max(foundRange.length, 1)
                } else {
                    break
                }
            }

            let total = currentMatches.count
            let nextIndex: Int
            if !currentMatches.isEmpty {
                if previousIndex > 0 && previousIndex <= currentMatches.count {
                    nextIndex = previousIndex
                } else {
                    nextIndex = 1
                }
            } else {
                nextIndex = 0
            }

            DispatchQueue.main.async { [weak self] in
                self?.findBarState?.totalMatches = total
                self?.findBarState?.currentMatchIndex = nextIndex
            }

            if !currentMatches.isEmpty {
                applyMatchHighlights(in: textView, activeMatchIndex: nextIndex)
            }
        }

        func applyMatchHighlights(in textView: NSTextView, activeMatchIndex: Int? = nil) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)

            let matchIndex = activeMatchIndex ?? (findBarState?.currentMatchIndex ?? 0)
            guard !currentMatches.isEmpty, matchIndex > 0 else { return }
            let activeIndex = matchIndex - 1

            let matchBg = NSColor.systemYellow.withAlphaComponent(0.35)
            let activeBg = NSColor.systemOrange.withAlphaComponent(0.75)

            for (idx, range) in currentMatches.enumerated() {
                guard range.location + range.length <= textStorage.length else { continue }
                if idx == activeIndex {
                    layoutManager.addTemporaryAttribute(.backgroundColor, value: activeBg, forCharacterRange: range)
                    layoutManager.addTemporaryAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, forCharacterRange: range)
                } else {
                    layoutManager.addTemporaryAttribute(.backgroundColor, value: matchBg, forCharacterRange: range)
                }
            }
        }

        func scrollToMatch(at matchIndex: Int, in textView: NSTextView) {
            guard !currentMatches.isEmpty, matchIndex > 0 else { return }
            let activeIndex = matchIndex - 1
            guard activeIndex < currentMatches.count else { return }
            let range = currentMatches[activeIndex]
            textView.scrollRangeToVisible(range)
            textView.showFindIndicator(for: range)
        }

        func scrollToCurrentMatch(in textView: NSTextView) {
            let activeIndex = findBarState?.currentMatchIndex ?? 0
            scrollToMatch(at: activeIndex, in: textView)
        }

        func nextMatch(in textView: NSTextView) {
            guard let findBarState = findBarState, currentMatches.count > 0 else { return }
            var nextIndex = findBarState.currentMatchIndex + 1
            if nextIndex > currentMatches.count {
                nextIndex = 1
            }
            findBarState.currentMatchIndex = nextIndex
            applyMatchHighlights(in: textView)
            scrollToCurrentMatch(in: textView)
        }

        func previousMatch(in textView: NSTextView) {
            guard let findBarState = findBarState, currentMatches.count > 0 else { return }
            var prevIndex = findBarState.currentMatchIndex - 1
            if prevIndex < 1 {
                prevIndex = currentMatches.count
            }
            findBarState.currentMatchIndex = prevIndex
            applyMatchHighlights(in: textView)
            scrollToCurrentMatch(in: textView)
        }

        func clearSearchHighlights(in textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: textStorage.length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
            layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullRange)
            currentMatches.removeAll()
        }
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        
        // PERF: 显式开启方向轴锁定优化，防止滚动时抖动
        scrollView.usesPredominantAxisScrolling = true

        // 创建 TextView
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.editorFont(name: fontName, size: fontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        if CodeViewTextColorPolicy.shouldApplyTextViewTextColor(language: language) {
            textView.textColor = .appText
        }
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
        context.coordinator.currentRenderIdentity = renderIdentity

        // 首次加载语法高亮
        loadSyntaxHighlightFirstTime(
            for: textView,
            isDark: isDark,
            fontCache: cache,
            coordinator: context.coordinator
        )

        // 挂载搜索监听
        context.coordinator.setupFindBarSubscription(findBarState: findBarState, textView: textView)

        // 挂载行号跳转监听
        context.coordinator.setupGoToLineSubscription(goToLineState: goToLineState, textView: textView)

        // 挂载实时监听与追尾状态监听
        context.coordinator.setupLiveWatchingSubscription(liveWatchingState: liveWatchingState, textView: textView)

        // 挂载 Git 差异监听
        context.coordinator.setupGitDiffSubscription(gitDiffState: gitDiffState, textView: textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let previousIdentity = context.coordinator.currentRenderIdentity
        let nextIdentity = renderIdentity

        // 传递最新的回调与状态引用给 Coordinator
        context.coordinator.loadState = loadState
        context.coordinator.onLoadMore = onLoadMore
        if context.coordinator.findBarState !== findBarState {
            context.coordinator.setupFindBarSubscription(findBarState: findBarState, textView: textView)
        }
        if context.coordinator.goToLineState !== goToLineState {
            context.coordinator.setupGoToLineSubscription(goToLineState: goToLineState, textView: textView)
        }
        if context.coordinator.liveWatchingState !== liveWatchingState {
            context.coordinator.setupLiveWatchingSubscription(liveWatchingState: liveWatchingState, textView: textView)
        }
        if context.coordinator.gitDiffState !== gitDiffState {
            context.coordinator.setupGitDiffSubscription(gitDiffState: gitDiffState, textView: textView)
        }

        let totalLineCount = context.coordinator.calculateTotalLines(for: content)
        if goToLineState?.totalLines != totalLineCount {
            DispatchQueue.main.async { [weak goToLineState] in
                goToLineState?.updateTotalLines(totalLineCount)
            }
        }

        if let targetLine = initialTargetLine, !context.coordinator.hasConsumedInitialTargetLine {
            context.coordinator.hasConsumedInitialTargetLine = true
            DispatchQueue.main.async {
                context.coordinator.jumpToLine(targetLine, in: textView, pulse: true)
                onInitialTargetLineConsumed?()
            }
        }

        guard !CodeViewRepresentableUpdatePolicy.shouldSkipRenderSync(
            previousIdentity: previousIdentity,
            nextIdentity: nextIdentity
        ) else {
            return
        }

        let isSameFile = context.coordinator.lastFilePath == filePath
        if !isSameFile {
            context.coordinator.hasConsumedInitialTargetLine = false
        }
        let contentChanged = context.coordinator.lastRenderedContent != content
        let lastRendered = context.coordinator.lastRenderedContent
        let lastLength = lastRendered.count
        let isIncremental = isSameFile && lastLength > 0 && content.count > lastLength && content.hasPrefix(lastRendered)

        // NOTE: 相比于直接对比高亮富文本的 textView.font?.pointSize (它会返回富文本首字高亮字体，导致判断失误)，
        //       直接比对 Coordinator 缓存的上一次 font 属性才是最可靠的。
        let fontChanged = context.coordinator.lastFontSize != fontSize || context.coordinator.lastFontName != fontName
        let isDarkChanged = context.coordinator.lastIsDark != isDark

        context.coordinator.lastIsDark = isDark
        context.coordinator.lastFontName = fontName
        context.coordinator.lastFontSize = fontSize
        context.coordinator.lastFilePath = filePath
        context.coordinator.currentRenderIdentity = nextIdentity

        // 动态更新字体变体缓存
        if fontChanged || context.coordinator.fontCache == nil {
            context.coordinator.fontCache = context.coordinator.makeFontVariantCache(name: fontName, size: fontSize)
        }
        let cache = context.coordinator.fontCache!

        // PERF: 只有在不同时才更新颜色属性，避免触发 NSTextView 冗余的 needsDisplay 和整屏重绘，守护滚动流畅度
        if scrollView.backgroundColor != .clear {
            scrollView.backgroundColor = .clear
        }
        if scrollView.drawsBackground != false {
            scrollView.drawsBackground = false
        }
        if textView.backgroundColor != .clear {
            textView.backgroundColor = .clear
        }
        if textView.drawsBackground != false {
            textView.drawsBackground = false
        }
        if CodeViewTextColorPolicy.shouldApplyTextViewTextColor(language: language),
           textView.textColor != .appText {
            textView.textColor = .appText
        }

        if isIncremental {
            // 增量追加段落（基于纯 Swift 字符安全切片，杜绝 UTF-16 code units 偏移带来的越界与错位）
            let newText = String(content.dropFirst(lastLength))
            appendChunk(
                newText: newText,
                for: textView,
                isDark: isDark,
                fontCache: cache,
                coordinator: context.coordinator
            )
            context.coordinator.lastRenderedContent = content
            context.coordinator.lastContentLength = content.count
        } else if !isSameFile || contentChanged || isDarkChanged || fontChanged {
            // 首次加载、修改主题或字体；同一文件外部热重载时无感保持当前视口滚动位置
            let isHotReload = isSameFile && contentChanged && !isDarkChanged && !fontChanged
            let savedScrollOrigin = isHotReload ? scrollView.contentView.bounds.origin : nil

            textView.string = content
            if let savedOrigin = savedScrollOrigin {
                scrollView.contentView.scroll(to: savedOrigin)
                scrollView.reflectScrolledClipView(scrollView.contentView)
            } else {
                textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            }

            loadSyntaxHighlightFirstTime(
                for: textView,
                isDark: isDark,
                fontCache: cache,
                coordinator: context.coordinator
            )
            context.coordinator.lastRenderedContent = content
            context.coordinator.lastContentLength = content.count
        } else {
            context.coordinator.lastContentLength = content.count
        }
    }

    /// 首次异步语法高亮（首屏 500 行秒开展示 + 后台全量高亮平滑刷入）
    private func loadSyntaxHighlightFirstTime(
        for textView: NSTextView,
        isDark: Bool,
        fontCache: FontVariantCache,
        coordinator: Coordinator
    ) {
        let fullContent = content
        let themeName = self.themeName
        let capturedIdentity = renderIdentity
        let modDate = FileUtils.getModificationDate(at: filePath)

        // 1. 安全降级防护网：如果无指定语言（纯文本），或者高亮引擎初始化失败（Release 包环境差异）
        //    则以用户配置的默认字体与高对比度前景颜色渲染并覆写 textStorage，消除默认的“黑底黑字”空白现象
        guard let language = language,
              SyntaxHighlighter.shared != nil else {
            let attributed = CodeViewHighlightFallbackPolicy.attributedText(
                highlighted: nil,
                fallbackContent: fullContent,
                fontName: fontName,
                fontSize: fontSize,
                isDark: isDark
            )
            DispatchQueue.main.async {
                guard CodeViewAsyncRenderPolicy.shouldApply(
                    capturedIdentity: capturedIdentity,
                    currentIdentity: coordinator.currentRenderIdentity,
                    capturedContent: fullContent,
                    currentText: textView.string
                ) else { return }
                textView.textStorage?.setAttributedString(attributed)
                coordinator.refreshSearchPreservingPosition(in: textView)
                coordinator.applyGitDiffHighlights(in: textView)
            }
            return
        }
        
        // 2. 尝试从内存缓存中直接匹配高亮文本
        if let cached = HighlightCache.shared.get(for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate) {
            if CodeViewAsyncRenderPolicy.shouldApply(
                capturedIdentity: capturedIdentity,
                currentIdentity: coordinator.currentRenderIdentity,
                capturedContent: fullContent,
                currentText: textView.string
            ) {
                textView.textStorage?.setAttributedString(cached)
                coordinator.refreshSearchPreservingPosition(in: textView)
                coordinator.applyGitDiffHighlights(in: textView)
            }
            return
        }

        // 3. 异步后台执行语法高亮
        DispatchQueue.global(qos: .userInteractive).async {
            let lines = fullContent.components(separatedBy: "\n")
            
            if lines.count <= 1000 {
                // 中小文件：直接一次性后台高亮并缓存，极速呈现
                let highlighted = SyntaxHighlighter.shared?.highlight(code: fullContent, language: language, theme: themeName)
                let customAttributed = CodeViewHighlightFallbackPolicy.attributedText(
                    highlighted: highlighted,
                    fallbackContent: fullContent,
                    fontName: fontName,
                    fontSize: fontSize,
                    isDark: isDark,
                    fontCache: fontCache
                )
                if highlighted != nil {
                    HighlightCache.shared.set(customAttributed, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
                }
                    
                DispatchQueue.main.async {
                    guard CodeViewAsyncRenderPolicy.shouldApply(
                        capturedIdentity: capturedIdentity,
                        currentIdentity: coordinator.currentRenderIdentity,
                        capturedContent: fullContent,
                        currentText: textView.string
                    ) else { return }
                    // NOTE: 直接替换，无 CATransition 动画
                    textView.textStorage?.setAttributedString(customAttributed)
                    coordinator.refreshSearchPreservingPosition(in: textView)
                    coordinator.applyGitDiffHighlights(in: textView)
                }
            } else {
                // 超大文件首段：先高亮前 500 行，剩下普通文本显示，实现窗口 0ms 秒开
                let firstPart = lines[0..<500].joined(separator: "\n")
                let remainPart = "\n" + lines[500...].joined(separator: "\n")
                
                guard let highlighter = SyntaxHighlighter.shared,
                      let firstAttributed = highlighter.highlight(code: firstPart, language: language, theme: themeName) else {
                    let fallbackAttributed = CodeViewHighlightFallbackPolicy.attributedText(
                        highlighted: nil,
                        fallbackContent: fullContent,
                        fontName: fontName,
                        fontSize: fontSize,
                        isDark: isDark
                    )
                    DispatchQueue.main.async {
                        guard CodeViewAsyncRenderPolicy.shouldApply(
                            capturedIdentity: capturedIdentity,
                            currentIdentity: coordinator.currentRenderIdentity,
                            capturedContent: fullContent,
                            currentText: textView.string
                        ) else { return }
                        textView.textStorage?.setAttributedString(fallbackAttributed)
                        coordinator.refreshSearchPreservingPosition(in: textView)
                        coordinator.applyGitDiffHighlights(in: textView)
                    }
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
                    guard CodeViewAsyncRenderPolicy.shouldApply(
                        capturedIdentity: capturedIdentity,
                        currentIdentity: coordinator.currentRenderIdentity,
                        capturedContent: fullContent,
                        currentText: textView.string
                    ) else { return }
                    textView.textStorage?.setAttributedString(tempFull)
                    coordinator.refreshSearchPreservingPosition(in: textView)
                    coordinator.applyGitDiffHighlights(in: textView)
                }
                
                // 随后在后台默默做首段文本的全量高亮（使用 utility 优先级避免与主线程滚动抢占 CPU 资源）
                DispatchQueue.global(qos: .utility).async {
                    let highlighted = highlighter.highlight(code: fullContent, language: language, theme: themeName)
                    let customFull = CodeViewHighlightFallbackPolicy.attributedText(
                        highlighted: highlighted,
                        fallbackContent: fullContent,
                        fontName: fontName,
                        fontSize: fontSize,
                        isDark: isDark,
                        fontCache: fontCache
                    )

                    if highlighted != nil {
                        HighlightCache.shared.set(customFull, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
                    }
                    
                    DispatchQueue.main.async {
                        guard CodeViewAsyncRenderPolicy.shouldApply(
                                  capturedIdentity: capturedIdentity,
                                  currentIdentity: coordinator.currentRenderIdentity,
                                  capturedContent: fullContent,
                                  currentText: textView.string
                              ),
                              let textStorage = textView.textStorage else { return }
                        // PERF: 高效率的 setAttributedString 整体覆写（仅耗时 0.3ms）
                        // 避免在主线程使用 enumerateAttributes 产生上千次 ObjC 桥接调用阻塞主线程
                        textStorage.setAttributedString(customFull)
                        coordinator.refreshSearchPreservingPosition(in: textView)
                        coordinator.applyGitDiffHighlights(in: textView)
                    }
                }
            }
        }
    }

    /// 增量追加新片段（新文本在主线程追加呈现，后台头部起算高亮以保证完美着色，完成后刷入属性）
    @MainActor
    private func appendChunk(
        newText: String,
        for textView: NSTextView,
        isDark: Bool,
        fontCache: FontVariantCache,
        coordinator: Coordinator
    ) {
        guard let textStorage = textView.textStorage else { return }
        
        let previousFullText = textView.string
        
        // 1. 瞬间在主线程把普通文本追加上去，使滚动区域变大，滚动条拉长，体验不卡顿
        let font = NSFont.editorFont(name: fontName, size: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isDark ? NSColor(white: 0.85, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
        ]
        let appendedAttrString = NSAttributedString(string: newText, attributes: attributes)
        
        textStorage.append(appendedAttrString)
        coordinator.refreshSearchPreservingPosition(in: textView)

        if let liveState = coordinator.liveWatchingState, liveState.isLiveTailMode && liveState.isFollowingTail {
            let endRange = NSRange(location: (textView.string as NSString).length, length: 0)
            textView.scrollRangeToVisible(endRange)
        }
        
        // 如果没有 language，说明是 plainText 模式，无需高亮
        guard let language = language else { return }
        
        // 2. 后台执行全量高亮，保障边界着色完美连续（使用 utility 优先级避免与滚动竞争 CPU）
        let themeName = self.themeName
        let capturedIdentity = renderIdentity
        let modDate = FileUtils.getModificationDate(at: filePath)
        let fullText = previousFullText + newText
        
        DispatchQueue.global(qos: .utility).async {
            let highlighted = SyntaxHighlighter.shared?.highlight(code: fullText, language: language, theme: themeName)
            let customFull = CodeViewHighlightFallbackPolicy.attributedText(
                highlighted: highlighted,
                fallbackContent: fullText,
                fontName: fontName,
                fontSize: fontSize,
                isDark: isDark,
                fontCache: fontCache
            )

            if highlighted != nil {
                HighlightCache.shared.set(customFull, for: filePath, themeName: themeName, fontName: fontName, fontSize: fontSize, modificationDate: modDate)
            }
            
            // 4. 主线程中直接一次性将高亮完整的富文本整体写入（仅需一次 Bridge 桥接，速度比 enumerateAttributes 快 20 倍以上）
            DispatchQueue.main.async { @MainActor in
                guard CodeViewAsyncRenderPolicy.shouldApply(
                    capturedIdentity: capturedIdentity,
                    currentIdentity: coordinator.currentRenderIdentity,
                    capturedContent: fullText,
                    currentText: textView.string
                ) else { return }
                textStorage.setAttributedString(customFull)
                if let liveState = coordinator.liveWatchingState, liveState.isLiveTailMode && liveState.isFollowingTail {
                    let endRange = NSRange(location: (textView.string as NSString).length, length: 0)
                    textView.scrollRangeToVisible(endRange)
                }
                coordinator.refreshSearchPreservingPosition(in: textView)
                coordinator.applyGitDiffHighlights(in: textView)
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
