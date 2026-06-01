import Foundation
import WebKit
import AppKit

class MarkdownPDFExporter: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Result<Data, Error>) -> Void)?
    private static var activeExporter: MarkdownPDFExporter? // 强引用保活，防止被提前释放

    /// 导出 Markdown 为 PDF 数据
    static func export(markdownText: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let exporter = MarkdownPDFExporter()
        activeExporter = exporter
        exporter.startExport(markdownText: markdownText, completion: completion)
    }

    private func startExport(markdownText: String, completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion

        // 转义 JS 模板字符串中的特殊字符
        let escapedMarkdown = markdownText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <!-- 引入 GitHub 风格代码高亮 CSS 样式 -->
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/github.min.css">
        <!-- 引入 Github Markdown 基础样式 -->
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            word-wrap: break-word;
            color: #24292e;
            background-color: #ffffff;
            padding: 40px;
        }
        .markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        .markdown-body h1 { padding-bottom: 0.3em; font-size: 2em; border-bottom: 1px solid #eaecef; }
        .markdown-body h2 { padding-bottom: 0.3em; font-size: 1.5em; border-bottom: 1px solid #eaecef; }
        .markdown-body code {
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            background-color: rgba(27,31,35,0.05);
            border-radius: 3px;
            font-family: SFMono-Regular, Consolas, Menlo, monospace;
        }
        .markdown-body pre {
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            background-color: #f6f8fa;
            border-radius: 6px;
            word-wrap: normal;
        }
        .markdown-body pre code {
            background-color: transparent;
            padding: 0;
        }
        .markdown-body blockquote {
            padding: 0 1em;
            color: #6a737d;
            border-left: 0.25em solid #dfe2e5;
            margin: 0 0 16px 0;
        }
        .markdown-body table {
            border-spacing: 0;
            border-collapse: collapse;
            margin-top: 0;
            margin-bottom: 16px;
            width: 100%;
            overflow: auto;
        }
        .markdown-body table th, .markdown-body table td {
            padding: 6px 13px;
            border: 1px solid #dfe2e5;
        }
        .markdown-body table tr {
            background-color: #ffffff;
            border-top: 1px solid #c6cbd1;
        }
        .markdown-body table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }
        </style>
        <!-- 引入内置的 marked.js -->
        <script>
        \(MarkedJS.source)
        </script>
        <!-- 引入 highlight.js，做在线语法高亮支持 -->
        <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js"></script>
        </head>
        <body>
        <div id="content" class="markdown-body"></div>
        <script>
        try {
            const rawMarkdown = `\(escapedMarkdown)`;
            document.getElementById('content').innerHTML = marked.parse(rawMarkdown);
            // 渲染完毕后，若 highlight.js 已成功加载，执行语法高亮
            if (typeof hljs !== 'undefined') {
                hljs.highlightAll();
            }
        } catch (e) {
            document.getElementById('content').innerText = "渲染错误: " + e.message;
        }
        </script>
        </body>
        </html>
        """

        DispatchQueue.main.async {
            let webConfiguration = WKWebViewConfiguration()
            let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1000), configuration: webConfiguration)
            webView.navigationDelegate = self
            self.webView = webView
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 延时 0.6 秒等待 JS 渲染及 Highlight 完毕
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if #available(macOS 11.0, *) {
                let config = WKPDFConfiguration()
                webView.createPDF(configuration: config) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let data):
                        self.completion?(.success(data))
                    case .failure(let error):
                        self.completion?(.failure(error))
                    }
                    self.cleanup()
                }
            } else {
                let error = NSError(domain: "QuickCookies", code: -1, userInfo: [NSLocalizedDescriptionKey: "macOS 版本过低，不支持生成 PDF".localized()])
                self.completion?(.failure(error))
                self.cleanup()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.completion?(.failure(error))
        self.cleanup()
    }

    private func cleanup() {
        self.webView = nil
        self.completion = nil
        MarkdownPDFExporter.activeExporter = nil
    }
}
