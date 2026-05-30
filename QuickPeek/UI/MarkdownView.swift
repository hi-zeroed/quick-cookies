import SwiftUI
import MarkdownUI

struct MarkdownView: View {
    let markdownText: String

    var body: some View {
        ScrollView {
            Markdown(markdownText)
                .markdownTheme(.gitHub) // 使用内置 GitHub 风格主题，自适应系统深浅色
                .markdownCodeSyntaxHighlighter(.highlightr) // 挂载 Highlightr 高亮适配器
                .padding(20)
        }
        // 捕获超链接点击事件，使用默认浏览器打开，防止预览窗口内跳转
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}