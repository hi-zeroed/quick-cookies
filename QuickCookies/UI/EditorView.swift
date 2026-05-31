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
        
        scrollView.backgroundColor = .appBackground
        scrollView.drawsBackground = true

        // 创建 TextView 并定制样式以契合参考图
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.editorFont(name: fontName, size: fontSize)
        textView.backgroundColor = .appBackground
        textView.textColor = .appText
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

        textView.font = NSFont.editorFont(name: fontName, size: fontSize)

        // 动态更新背景色和文本色
        scrollView.backgroundColor = .appBackground
        textView.backgroundColor = .appBackground
        textView.textColor = .appText
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