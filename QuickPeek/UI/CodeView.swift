import SwiftUI
import AppKit

struct CodeView: NSViewRepresentable {
    let filePath: String
    let content: String
    let language: String?
    let fontSize: CGFloat

    func makeNSView(context: Context) -> NSScrollView {
        // 创建 ScrollView（包装 TextView）
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalRuler = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        // 创建 TextView
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        // 改用更适合显示代码的等宽字体
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isRichText = false
        textView.string = content
        textView.wantsLayer = true // 启用 Layer 绘制以支持动画过渡

        scrollView.documentView = textView

        // 滚动到顶部（显示首行）
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))

        // 尝试加载语法高亮
        loadSyntaxHighlightAsync(for: textView, forced: true)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let contentChanged = textView.string != content
        let fontChanged = textView.font?.pointSize != fontSize

        if contentChanged {
            textView.string = content
        }

        if fontChanged {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }

        if contentChanged {
            // 只有内容确实变化时才滚动到顶部并重新进行语法高亮
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
            loadSyntaxHighlightAsync(for: textView, forced: true)
        } else if fontChanged {
            // 仅字体改变（如设置项修改）且内容没有改变时，仍然利用缓存刷新样式
            loadSyntaxHighlightAsync(for: textView, forced: false)
        }
    }

    /// 异步加载语法高亮（带 500 行截断、缓存检测与平滑 Crossfade 渐变）
    private func loadSyntaxHighlightAsync(for textView: NSTextView, forced: Bool) {
        guard let language = language else { return }
        
        let modDate = FileUtils.getModificationDate(at: filePath)
        
        // 1. 尝试从内存缓存中直接匹配高亮文本
        if let cached = HighlightCache.shared.get(for: filePath, modificationDate: modDate) {
            // 缓存命中：同步渲染（秒开）
            textView.textStorage?.setAttributedString(cached)
            return
        }

        // 2. 如果强制更新或未命中缓存，在后台运行语法高亮
        DispatchQueue.global(qos: .userInteractive).async {
            // 按行拆分，限制高亮仅针对前 500 行，解决超长文件解析性能问题
            let lines = content.components(separatedBy: "\n")
            let highlightText: String
            let remainText: String
            
            if lines.count > 500 {
                highlightText = lines[0..<500].joined(separator: "\n")
                remainText = "\n" + lines[500...].joined(separator: "\n")
            } else {
                highlightText = content
                remainText = ""
            }

            if let highlighter = SyntaxHighlighter.shared,
               let attributed = highlighter.highlight(code: highlightText, language: language) {
                
                let finalAttributed = NSMutableAttributedString(attributedString: attributed)
                
                // 拼接未高亮的剩余行文本，并赋予相同的等宽字体属性
                if !remainText.isEmpty {
                    let remainAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                        .foregroundColor: NSColor.labelColor
                    ]
                    let remainAttributed = NSAttributedString(string: remainText, attributes: remainAttributes)
                    finalAttributed.append(remainAttributed)
                }

                // 写入内存缓存
                HighlightCache.shared.set(finalAttributed, for: filePath, modificationDate: modDate)

                // 回到主线程平滑淡入呈现高亮文本
                DispatchQueue.main.async {
                    let transition = CATransition()
                    transition.type = .fade
                    transition.duration = 0.25
                    transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    textView.layer?.add(transition, forKey: kCATransition)
                    
                    textView.textStorage?.setAttributedString(finalAttributed)
                }
            }
        }
    }
}