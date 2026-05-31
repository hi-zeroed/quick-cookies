import SwiftUI

enum ContentMode {
    case preview    // 预览模式
    case edit       // 编辑模式
}

class PreviewState: ObservableObject {
    @Published var filePath: String?
    @Published var renderType: FileRenderType?
    @Published var language: String?
    @Published var isLoadingPath: Bool = true
    @Published var errorMessage: String?
    
    func reset() {
        filePath = nil
        renderType = nil
        language = nil
        isLoadingPath = true
        errorMessage = nil
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var state: PreviewState

    @State private var content: String = ""
    @State private var isLoading: Bool = true
    @State private var isTruncated: Bool = false
    @State private var mode: ContentMode = .preview
    @State private var isModified: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""

    @ObservedObject var settings = Settings.shared

    init(state: PreviewState) {
        self.state = state
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar

            // 内容区域
            contentArea
                .padding([.horizontal, .bottom], 28) // 进一步加大内边距，提供极高颜值的宽留白卡片视感
        }
        .background(Color.appBackground)
        .alert("保存失败", isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .task {
            if let path = state.filePath {
                await loadFileAsync(path: path)
            }
        }
        .onChange(of: state.filePath) { newPath in
            if let path = newPath {
                isLoading = true
                Task {
                    await loadFileAsync(path: path)
                }
            }
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // 左侧占位（完美避让 macOS 系统红绿灯按钮，占位 80px）
            Spacer()
                .frame(width: 80)
            
            Spacer()

            // 中间文件名 + 状态修饰点
            HStack(spacing: 6) {
                if let path = state.filePath {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.appText)
                } else if state.errorMessage != nil {
                    Text("获取失败")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                } else {
                    Text("定位中...")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.6))
                }
                
                // 大文件截断提示（参考极简设计）
                if isTruncated {
                    Text("⚠️只加载了前1000行")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(3)
                }
                
                // 状态修饰点
                Circle()
                    .fill(isModified ? Color.orange : (state.filePath == nil ? Color.gray.opacity(0.5) : Color.blue.opacity(0.8)))
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // 右侧控制区域（模式切换与保存，右对齐固定 80px）
            HStack(spacing: 12) {
                if state.filePath != nil && state.errorMessage == nil {
                    // 模式切换按钮
                    Button(action: toggleMode) {
                        Text(mode == .preview ? "✎" : "👁")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appText.opacity(0.8))
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
            }
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10) // 增加顶端高度，让红绿灯和文字中线对齐
        .padding(.bottom, 10)
        .background(Color.toolbarBackground)
    }

    @ViewBuilder
    private var contentArea: some View {
        if let err = state.errorMessage {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange.opacity(0.8))
                Text(err)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Text("按 Esc 键关闭窗口")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else if state.isLoadingPath && state.filePath == nil {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(1.2)
                Text("正在定位 Finder 选中文件...")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else if isLoading {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.4)))
                Text("正在载入并高亮文本...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else {
            Group {
                switch mode {
                case .preview:
                    previewView
                case .edit:
                    editView
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var previewView: some View {
        if let path = state.filePath, let renderType = state.renderType {
            let isDark = colorScheme == .dark
            switch renderType {
            case .markdown:
                MarkdownView(markdownText: content)
            case .code:
                CodeView(
                    filePath: path,
                    content: content,
                    language: state.language,
                    fontSize: settings.fontSize,
                    isDark: isDark
                )
            case .plainText:
                CodeView(
                    filePath: path,
                    content: content,
                    language: nil,
                    fontSize: settings.fontSize,
                    isDark: isDark
                )
            }
        }
    }

    @ViewBuilder
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
        guard let path = state.filePath else { return }
        let result = FileUtils.writeFile(at: path, content: content)

        switch result {
        case .success:
            isModified = false
        case .failure(let error):
            errorMessage = error.errorDescription ?? "未知错误"
            showErrorAlert = true
        }
    }

    /// 后台并发异步读取与分段解码，保证窗口零延迟弹出
    private func loadFileAsync(path: String) async {
        let result = await Task.detached(priority: .userInitiated) {
            return FileUtils.readLimitFile(at: path, limitBytes: 128 * 1024)
        }.value

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                switch result {
                case .success(let payload):
                    self.content = payload.content
                    self.isTruncated = payload.isTruncated
                    self.isLoading = false
                case .failure(let error):
                    self.errorMessage = error.errorDescription ?? "读取文件失败"
                    self.isLoading = false
                    self.showErrorAlert = true
                }
            }
        }
    }
}