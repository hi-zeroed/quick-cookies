import SwiftUI
import AppKit

struct EditorView: NSViewRepresentable {
    @Binding var content: String
    @Binding var isModified: Bool
    let fontSize: CGFloat
    let fontName: String
    let showLineNumbers: Bool
    let onSave: (() -> Void)?

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

        // 创建 TextView 并定制样式以契合参考图
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.editorFont(name: fontName, size: fontSize)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .appText
        textView.isRichText = false
        textView.allowsUndo = true
        textView.string = content
        
        // PERF: 开启按需非连续布局，防止大文本在滚动和渲染时发生主线程卡顿
        textView.layoutManager?.allowsNonContiguousLayout = true

        // PERF: 禁用所有文本自动处理特性以减少输入/滚动时的 CPU 额外计算
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        
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

        // PERF: 只有当字体发生实际变化时才更新，防止 layoutManager 丢弃布局缓存重新排版全文
        let targetFont = NSFont.editorFont(name: fontName, size: fontSize)
        if textView.font != targetFont {
            textView.font = targetFont
        }

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
        if textView.textColor != .appText {
            textView.textColor = .appText
        }
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


// NOTE: LineNumberView 已在 LineNumberView.swift 中统一实现（支持 O(log n) 行号查找缓存）
// EditorView 与 CodeView 共享同一实现，此处无需重复定义