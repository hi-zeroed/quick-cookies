import SwiftUI
import MarkdownUI

struct MarkdownView: View {
    let markdownText: String

    var body: some View {
        // 设置 Markdown 渲染上限为 12,000 字符（约 300 行），彻底解决 MarkdownUI 主线程同步解析 AST 卡死问题，达成绝对秒开
        let limit = 12000
        let isTruncated = markdownText.count > limit
        let displayText = isTruncated ? String(markdownText.prefix(limit)) : markdownText

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(displayText)
                    .markdownTheme(.gitHub) // 使用内置 GitHub 风格主题，自适应系统深浅色
                    .markdownCodeSyntaxHighlighter(.highlightr) // 挂载 Highlightr 高亮处理器
                
                if isTruncated {
                    Divider()
                        .padding(.vertical, 8)
                    HStack {
                        Spacer()
                        Text("⚠️已截取前 300 行排版，完整内容请点击右上角 ✎ 切换至编辑模式")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.8))
                        Spacer()
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.11))
        // 捕获超链接点击事件，使用默认浏览器打开，防止预览窗口内跳转
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}