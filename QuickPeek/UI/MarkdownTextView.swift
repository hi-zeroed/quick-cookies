import SwiftUI
import AppKit

/// Markdown 纯文本显示视图（降级方案，不依赖 WebKit/Metal）
/// 用于 metallib 加载失败时的 fallback
struct MarkdownTextView: NSViewRepresentable {
    let markdownText: String

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.string = markdownText
        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        textView.string = markdownText
    }
}