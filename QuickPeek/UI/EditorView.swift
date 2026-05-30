import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var content: String
    @Binding var isModified: Bool
    let fontSize: CGFloat
    let showLineNumbers: Bool
    let onSave: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // 统一深黑色主题背景
        scrollView.backgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        scrollView.drawsBackground = true

        // 创建 TextView 并定制样式以契合参考图
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        textView.textColor = NSColor(red: 0.88, green: 0.88, blue: 0.90, alpha: 1.0)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.string = content
        
        // 增加四周留白
        textView.textContainerInset = NSSize(width: 8, height: 8)

        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 仅在外部内容变化时更新
        if textView.string != content {
            textView.string = content
        }

        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, isModified: $isModified, onSave: onSave)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var content: String
        @Binding var isModified: Bool
        let onSave: (() -> Void)?

        init(content: Binding<String>, isModified: Binding<Bool>, onSave: (() -> Void)? = nil) {
            self._content = content
            self._isModified = isModified
            self.onSave = onSave
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            content = textView.string
            isModified = true
        }

        // NSTextViewDelegate method for keyboard commands
        func textDidChange(_ textView: NSTextView) {
            content = textView.string
            isModified = true
        }
    }
}

/// 行号视图
class LineNumberView: NSRulerView {
    weak var textView: NSTextView?

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        
        // 监听滚动和内容变化
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

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textStorage = textView.textStorage else { return }

        let visibleRect = textView.visibleRect
        let font = NSFont.monospacedSystemFont(ofSize: textView.font?.pointSize ?? 12, weight: .regular)
        let textColor = NSColor.secondaryLabelColor
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let string = textStorage.string as NSString
        let textContainer = textView.textContainer!

        // 获取可见区域的 glyphs 范围
        let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        
        var glyphIndex = visibleGlyphRange.location
        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            var effectiveRange = NSRange(location: NSNotFound, length: 0)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange)
            
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            
            // 只有物理行首才需要显示行号
            let isNewLine: Bool
            if charIndex == 0 {
                isNewLine = true
            } else {
                let prevChar = string.character(at: charIndex - 1)
                isNewLine = (prevChar == 10) // '\n'
            }
            
            if isNewLine {
                // 计算当前物理行的行号（利用 O(N) 仅对到当前可见首字符的换行符计数）
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
                
                // 靠右绘制行号，留出 8pt 边距
                let drawX = self.bounds.width - stringSize.width - 8
                // 微调 Y 坐标以在行高度中居中对齐
                let drawY = pointInRuler.y + (lineRect.height - stringSize.height) / 2
                
                lineNumberString.draw(at: NSPoint(x: drawX, y: drawY), withAttributes: attributes)
            }
            
            glyphIndex = NSMaxRange(effectiveRange)
        }
    }

    override var requiredThickness: CGFloat {
        return 40
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}