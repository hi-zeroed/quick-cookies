import SwiftUI
import MarkdownUI

struct MarkdownView: View {
    let filePath: String
    let markdownText: String
    
    // 计算当前预览文件的父级目录 URL，作为相对路径图片和链接的基准路径
    private var baseDirectoryURL: URL? {
        URL(fileURLWithPath: filePath).deletingLastPathComponent()
    }
    
    @ObservedObject var settings = Settings.shared

    // 基于 GitHub 风格定制的专属 Markdown 主题，实现全文本字号动态联动与全透明背景色
    private var customMarkdownTheme: Theme {
        let fontName = settings.editorFont
        let family: FontProperties.Family = (fontName == "System Default (Inter)" || fontName.isEmpty)
            ? .system()
            : .custom(fontName)

        return Theme.gitHub
            .text {
                ForegroundColor(Color.appText)
                BackgroundColor(nil)
                FontSize(settings.fontSize)
                FontFamily(family)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                BackgroundColor(nil) // 覆盖硬编码灰色背景，实现行内代码透明底色
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                        }
                        .padding(16)
                }
                .background(Color.clear) // 覆盖硬编码灰色，使代码块背景彻底透明
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 0, bottom: 16)
            }
            .table { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .markdownTableBorderStyle(.init(color: Color.appBorder.opacity(0.4)))
                    .markdownTableBackgroundStyle(
                        .alternatingRows(
                            Color.clear,
                            Color.appText.opacity(0.045) // 使用表格每行间的背景颜色增加点透明度，更柔和地融入磨砂背景
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // 为表格增加精致的圆角形状
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder.opacity(0.4), lineWidth: 1) // 在圆角外围叠加精细边框线
                    )
                    .markdownMargin(top: 0, bottom: 16)
            }
    }

    var body: some View {
        // 设置 Markdown 渲染上限为 12,000 字符（约 300 行），彻底解决 MarkdownUI 主线程同步解析 AST 卡死问题，达成绝对秒开
        let limit = 12000
        let isTruncated = markdownText.count > limit
        let displayText = isTruncated ? String(markdownText.prefix(limit)) : markdownText
        let processedText = MarkdownHTMLPreprocessor.preprocess(displayText)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(processedText, baseURL: baseDirectoryURL)
                    .markdownTheme(customMarkdownTheme) // 挂载以 GitHub 为蓝本的定制化自适应主题
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
        .background(Color.appBackground)
        // 捕获超链接点击事件，使用默认浏览器打开，防止预览窗口内跳转
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }
}

fileprivate struct MarkdownHTMLPreprocessor {
    static func preprocess(_ text: String) -> String {
        var result = text
        
        // 1. 移除 HTML 注释 <!-- ... -->
        if let regex = try? NSRegularExpression(pattern: "<!--[\\s\\S]*?-->") {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // 2. 替换 <br> 或 <br/> 为 \n
        if let regex = try? NSRegularExpression(pattern: "<br\\s*/?>", options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "\n")
        }
        
        // 3. 替换 <img src="URL" ...> 为 ![](URL)
        if let regex = try? NSRegularExpression(pattern: "<img\\s+[^>]*src=['\"]([^'\"]+)['\"][^>]*>", options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "![]($1)")
        }
        
        // 4. 替换 <a href="URL">TEXT</a> 为 [TEXT](URL)
        if let regex = try? NSRegularExpression(pattern: "<a\\s+[^>]*href=['\"]([^'\"]+)['\"][^>]*>([\\s\\S]*?)</a>", options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "[$2]($1)")
        }
        
        // 5. 剔除所有其余 HTML 标签 (例如 <div>, </p>, <span style="..."> 等)，防止明文显示
        // 只剔除符合标准标签规范的项，以防误伤数学公式如 x < y
        if let regex = try? NSRegularExpression(pattern: "<\\/?[a-zA-Z0-9]+[^>]*>", options: [.caseInsensitive]) {
            result = regex.stringByReplacingMatches(in: result, options: [], range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        return result
    }
}