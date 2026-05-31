import AppKit

/// 共享的高性能行号标尺视图 (LineNumberView)
/// 完美融入一体化暗黑主题背景，自动适应文本滚动与换行
///
/// NOTE: 行号计算采用预计算索引缓存策略：
///   - 文本变化时一次性扫描全文建立 lineStartIndices 数组（O(n)）
///   - 绘制时对每个可见行使用二分查找（O(log n)），彻底消除滚动时的 O(n²) 开销
class LineNumberView: NSRulerView {
    weak var textView: NSTextView?

    // NOTE: lineStartIndices[i] 存储第 (i+1) 行的起始字符索引
    //       例如 [0, 15, 32] 表示：第1行从0开始，第2行从15开始，第3行从32开始
    //       文本变化时重建，绘制时二分查找，O(log n) 确定任意位置的行号
    private var lineStartIndices: [Int] = [0]

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        
        // 启用 Layer 并设置与 TextView 一致的背景色
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0).cgColor
        
        // 监听滚动和内容变化以触发重绘
        if let scrollView = textView.enclosingScrollView {
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(rulerNeedsDisplay),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rulerNeedsDisplay),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
        // 文本内容变化时重建行索引缓存并触发重绘
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
        
        // 初始建立索引
        rebuildLineStartIndices()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func rulerNeedsDisplay() {
        self.needsDisplay = true
    }
    
    @objc private func textDidChange() {
        // 文本变化时重建索引缓存（O(n) 一次性扫描），然后触发重绘
        rebuildLineStartIndices()
        self.needsDisplay = true
    }

    // MARK: - 预计算行号索引（核心性能优化）
    
    /// 一次性扫描全文，建立"行起始字符索引"数组
    /// 复杂度 O(n)，执行后每次绘制查找行号只需 O(log n) 二分查找
    private func rebuildLineStartIndices() {
        guard let textView = textView,
              let textStorage = textView.textStorage else {
            lineStartIndices = [0]
            return
        }
        
        let string = textStorage.string as NSString
        var indices: [Int] = [0]
        var searchStart = 0
        
        while searchStart < string.length {
            let searchRange = NSRange(location: searchStart, length: string.length - searchStart)
            let range = string.rangeOfCharacter(from: .newlines, options: [], range: searchRange)
            
            guard range.location != NSNotFound else { break }
            
            let nextLineStart = range.location + range.length
            // 只有非末尾换行才需要记录新行起始点
            if nextLineStart < string.length {
                indices.append(nextLineStart)
            }
            searchStart = nextLineStart
        }
        
        lineStartIndices = indices
    }
    
    /// 二分查找：给定字符索引，返回该位置所在的行号（1-indexed）
    /// 复杂度 O(log n)，完全消除滚动时的 O(n) 扫描开销
    private func lineNumber(forCharIndex charIndex: Int) -> Int {
        guard lineStartIndices.count > 1 else { return 1 }
        
        var lo = 0
        var hi = lineStartIndices.count - 1
        
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStartIndices[mid] <= charIndex {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        
        return lo + 1  // 1-indexed
    }

    // MARK: - 绘制

    override func draw(_ rect: NSRect) {
        // 用与正文框一致的暗黑底色填充，彻底盖掉系统自带的灰色渐变与刻度标尺底色
        NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0).set()
        rect.fill()
        
        // 仅绘制自定义的行号文本，不调用 super.draw(rect) 从而物理抹杀系统的竖向边线与右边框
        drawHashMarksAndLabels(in: rect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { return }

        let visibleRect = textView.visibleRect
        // 字体缩小 3.5pt 且使用 light，极其小巧秀气
        let font = NSFont.monospacedSystemFont(ofSize: (textView.font?.pointSize ?? 12) - 3.5, weight: .light)
        
        // 极度暗淡的灰色（相比主背景 #18181c 仅略微显现，隐约可见即可）
        let textColor = NSColor(white: 0.16, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let string = textStorage.string as NSString
        let textContainer = textView.textContainer!

        // 获取可见区域的 glyphs 范围，仅渲染可见视口行号
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        
        var glyphIndex = visibleGlyphRange.location
        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            var effectiveRange = NSRange(location: NSNotFound, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            
            // 只有物理行的起始位置才需要显示行号
            let isNewLine: Bool
            if charIndex == 0 {
                isNewLine = true
            } else {
                let prevChar = string.character(at: charIndex - 1)
                isNewLine = (prevChar == 10) // '\n'
            }
            
            if isNewLine {
                // O(log n) 二分查找行号，替代原来的 O(n) 线性扫描
                let lineNum = lineNumber(forCharIndex: charIndex)
                
                // 将 TextView 的 lineRect.minY 转换到 NSRulerView 坐标系
                let yInTextView = lineRect.minY + textView.textContainerInset.height
                let pointInRuler = self.convert(NSPoint(x: 0, y: yInTextView), from: textView)
                
                let lineNumberString = String(lineNum)
                let stringSize = lineNumberString.size(withAttributes: attributes)
                
                // 行号靠右绘制，只留出 4pt 的极窄呼吸边界
                let drawX = self.bounds.width - stringSize.width - 4
                let drawY = pointInRuler.y + (lineRect.height - stringSize.height) / 2
                
                lineNumberString.draw(at: NSPoint(x: drawX, y: drawY), withAttributes: attributes)
            }
            
            glyphIndex = NSMaxRange(effectiveRange)
        }
    }

    override var requiredThickness: CGFloat {
        return 26
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
