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
        }
        .alert("保存失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // 文件名 + 修改标记
            Text(URL(fileURLWithPath: filePath).lastPathComponent)
                .font(.system(size: 13, weight: .medium))

            if isModified {
                Text("●")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
            }

            Spacer()

            // 模式切换按钮（使用 Unicode 字符替代图标）
            Button(action: toggleMode) {
                Text(mode == .preview ? "✎" : "👁") // pencil / eye Unicode
            }
            .buttonStyle(.plain)
            .help(mode == .preview ? "编辑" : "预览")

            // 保存按钮（编辑模式）
            if mode == .edit && isModified {
                Button(action: saveFile) {
                    Text("⬇") // download Unicode
                }
                .buttonStyle(.plain)
                .help("保存 (Cmd+S)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
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