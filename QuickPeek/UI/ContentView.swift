import SwiftUI

enum ContentMode {
    case preview    // 预览模式
    case edit       // 编辑模式
}

struct ContentView: View {
    let filePath: String
    let renderType: FileRenderType
    let language: String?
    let initialContent: String

    @State private var content: String
    @State private var mode: ContentMode = .preview
    @State private var isModified: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    @ObservedObject var settings = Settings.shared

    init(filePath: String, renderType: FileRenderType, language: String?, content: String) {
        self.filePath = filePath
        self.renderType = renderType
        self.language = language
        self.initialContent = content
        self._content = State(initialValue: content)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            // 内容区域
            contentArea
                .padding([.horizontal, .bottom], 16) // 四周加内边距，防止文本贴边
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.11))
        .alert("保存失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // 左侧占位（完美避让 macOS 系统红绿灯按钮，占位 80px）
            Spacer()
                .frame(width: 80)
            
            Spacer()

            // 中间文件名 + 状态修饰点 (完美重现参考图 Project_Notes.md 样式)
            HStack(spacing: 6) {
                Text(URL(fileURLWithPath: filePath).lastPathComponent)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(white: 0.85))
                
                // 蓝点装饰，若修改则显示亮橙色
                Circle()
                    .fill(isModified ? Color.orange : Color.blue.opacity(0.8))
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // 右侧控制区域（模式切换与保存，右对齐固定 80px）
            HStack(spacing: 12) {
                // 模式切换按钮
                Button(action: toggleMode) {
                    Text(mode == .preview ? "✎" : "👁")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.7))
                }
                .buttonStyle(.plain)
                .help(mode == .preview ? "进入编辑 (Cmd+E)" : "回到预览 (Esc)")

                // 保存按钮
                if mode == .edit && isModified {
                    Button(action: saveFile) {
                        Text("⬇")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help("保存 (Cmd+S)")
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10) // 增加顶端高度，让红绿灯和文字中线对齐
        .padding(.bottom, 10)
        .background(Color(red: 0.09, green: 0.09, blue: 0.11))
    }

    @ViewBuilder
    private var contentArea: some View {
        Group {
            switch mode {
            case .preview:
                previewView
            case .edit:
                editView
            }
        }
    }

    @ViewBuilder
    private var previewView: some View {
        switch renderType {
        case .markdown:
            MarkdownView(markdownText: content)
        case .code:
            CodeView(
                filePath: filePath,
                content: content,
                language: language,
                fontSize: settings.fontSize
            )
        case .plainText:
            CodeView(
                filePath: filePath,
                content: content,
                language: nil,
                fontSize: settings.fontSize
            )
        }
    }

    private var editView: some View {
        EditorView(
            content: $content,
            isModified: $isModified,
            fontSize: settings.fontSize,
            showLineNumbers: settings.showLineNumbers,
            onSave: saveFile
        )
    }

    private func toggleMode() {
        mode = mode == .preview ? .edit : .preview
    }

    private func saveFile() {
        let result = FileUtils.writeFile(at: filePath, content: content)

        switch result {
        case .success:
            isModified = false
        case .failure(let error):
            errorMessage = error.errorDescription ?? "未知错误"
            showErrorAlert = true
        }
    }
}