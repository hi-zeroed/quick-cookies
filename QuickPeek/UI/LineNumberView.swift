import AppKit

/// 共享的高性能行号标尺视图 (LineNumberView)
/// 完美融入一体化暗黑主题背景，自动适应文本滚动与换行
class LineNumberView: NSRulerView {
    weak var textView: NSTextView?

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
            NotificationCenter.default.addObserver(self, selector: #selector(rulerNeedsDisplay), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(rulerNeedsDisplay), name: NSView.frameDidChangeNotification, object: textView)
        NotificationCenter.default.addObserver(self, selector: #selector(rulerNeedsDisplay), name: NSText.didChangeNotification, object: textView)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func rulerNeedsDisplay() {
        self.needsDisplay = true
    }

    override func drawBackground(in rect: NSRect) {
        // 彻底用 TextView 相同的暗黑底色填充，物理消除系统默认的刻度背景与右侧竖向灰色边线
        NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0).set()
        rect.fill()
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { return }

        let visibleRect = textView.visibleRect
        // 字体比正文略小 2pt，且使用 light 字重，纤细简约
        let font = NSFont.monospacedSystemFont(ofSize: (textView.font?.pointSize ?? 12) - 2, weight: .light)
        
        // 极淡的暗灰色，低调内敛，不抢夺视线
        let textColor = NSColor(white: 0.24, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let string = textStorage.string as NSString
        let textContainer = textView.textContainer!

        // 获取可见区域的 glyphs 范围，仅渲染可见视口行号，性能极佳
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
                // 计算当前物理行的行号
                var lineNumber = 1
                var tempIndex = 0
                while tempIndex < charIndex {
                    let searchRange = NSRange(location: tempIndex, length: charIndex - tempIndex)
                    let range = string.rangeOfCharacter(from: CharacterSet.newlines, options: [], range: searchRange)
                    if range.location != NSNotFound {
                        lineNumber += 1
                        tempIndex = range.location + range.length
                    } else {
                        break
                    }
                }
                
                // 将 TextView 的 lineRect.minY 转换到 NSRulerView 坐标系
                let yInTextView = lineRect.minY + textView.textContainerInset.height
                let pointInRuler = self.convert(NSPoint(x: 0, y: yInTextView), from: textView)
                
                let lineNumberString = String(lineNumber)
                let stringSize = lineNumberString.size(withAttributes: attributes)
                
                // 行号靠右绘制，只留出 6pt 的极窄呼吸边界，紧凑极简
                let drawX = self.bounds.width - stringSize.width - 6
                let drawY = pointInRuler.y + (lineRect.height - stringSize.height) / 2
                
                lineNumberString.draw(at: NSPoint(x: drawX, y: drawY), withAttributes: attributes)
            }
            
            glyphIndex = NSMaxRange(effectiveRange)
        }
    }

    override var requiredThickness: CGFloat {
        return 32 // 宽度缩窄至 32px，整体视界极简化
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
