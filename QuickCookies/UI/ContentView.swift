import SwiftUI
import UniformTypeIdentifiers

enum ContentMode {
    case preview    // 预览模式
    case edit       // 编辑模式
}

class PreviewState: ObservableObject {
    private var isResetting = false

    @Published var filePath: String? {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    @Published var renderType: FileRenderType? {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    @Published var language: String? {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    @Published var isLoadingPath: Bool = true {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    @Published var errorMessage: String? {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    @Published var mode: ContentMode = .preview {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    @Published var isExpanded: Bool = false {
        didSet {
            if !isResetting { onStateChanged?() }
        }
    }
    
    // 大文件分段增量读取状态
    @Published var hasMoreChunks: Bool = false
    @Published var isIncrementalLoading: Bool = false
    
    var onStateChanged: (() -> Void)?
    
    func reset() {
        isResetting = true
        filePath = nil
        renderType = nil
        language = nil
        isLoadingPath = true
        errorMessage = nil
        hasMoreChunks = false
        isIncrementalLoading = false
        mode = .preview
        isExpanded = false
        isResetting = false
        onStateChanged?()
    }
    
    /// 批量原子化更新属性，防止在更新期间由于局部属性改变误发通知
    func updateState(filePath: String?, renderType: FileRenderType?, language: String?, isLoadingPath: Bool, errorMessage: String? = nil) {
        isResetting = true
        self.filePath = filePath
        self.renderType = renderType
        self.language = language
        self.isLoadingPath = isLoadingPath
        self.errorMessage = errorMessage
        self.mode = .preview
        self.isExpanded = false
        isResetting = false
        onStateChanged?()
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var state: PreviewState

    @State private var content: String = ""
    @State private var isLoading: Bool = true
    @State private var isTruncated: Bool = false
    @State private var isModified: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var fileWatcher: FileWatcher? = nil
    @State private var showReloadAlert: Bool = false
    @State private var isSaving: Bool = false
    
    // Markdown 导出 PDF 状态与本地 Toast 提示
    @State private var isExportingPDFActive: Bool = false
    @State private var isExportingPDF: Bool = false
    @State private var showLocalToast: Bool = false
    @State private var localToastMessage: String = ""
    @State private var localToastIcon: String? = nil
    
    // 状态化分段文件读取器
    @State private var chunkReader: FileChunkReader? = nil
    
    // 头部顶栏 Hover 状态
    @State private var isHeaderHovered: Bool = false

    // NOTE: 不在 ContentView 根节点订阅 Settings.shared，
    //       避免任意设置变化触发整个视图树 invalidate + CodeView.updateNSView 冒餐调用。
    //       fontSize / editorFont 只在 previewView / editView 子节点内读取，训练范围最小化。

    init(state: PreviewState) {
        self.state = state
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            toolbar
                .zIndex(1) // 锁定层级，确保工具栏处于最前，防止 MarkdownView 的 ScrollView 穿透遮挡

            // 内容区域（去除原本的 padding，改在 contentArea 内部 ZStack 包装）
            contentArea
                .zIndex(0)
        }
        .ignoresSafeArea(edges: .top)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        )
        .cornerRadius(20) // 卡片自身的圆角
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 16, x: 0, y: 10) // 卡片精致的外阴影
        .padding(40) // 核心透明留白，用于支撑弹簧过冲回弹的防裁剪与阴影扩散
        .background(Color.clear) // 根容器背景必须是透明 clear，保持留白边缘穿透
        .toast(isShowing: $showLocalToast, message: localToastMessage, icon: localToastIcon)
        .alert("保存失败".localized(), isPresented: $showErrorAlert) {
            Button("确定".localized(), role: .cancel) { }
        } message: {
            Text(errorMessage.localized())
        }
        .alert("文件已被外部修改".localized(), isPresented: $showReloadAlert) {
            Button("重新加载".localized()) {
                if let path = state.filePath {
                    isLoading = true
                    Task {
                        await loadFileAsync(path: path)
                    }
                }
            }
            Button("忽略".localized(), role: .cancel) { }
        } message: {
            Text("该文件已被其他编辑器修改，是否重新加载最新内容？".localized())
        }
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
            chunkReader?.close()
            chunkReader = nil
        }
        .task {
            if let path = state.filePath {
                await loadFileAsync(path: path)
                startWatchingFile(path: path)
            }
        }
        .onChange(of: state.filePath) { newPath in
            if let path = newPath {
                isLoading = true
                Task {
                    await loadFileAsync(path: path)
                    startWatchingFile(path: path)
                }
            } else {
                fileWatcher?.stop()
                fileWatcher = nil
                chunkReader?.close()
                chunkReader = nil
            }
        }
    }

    // 文件类型小图标名称
    private func fileIconName(for renderType: FileRenderType?) -> String {
        guard let type = renderType else { return "doc" }
        switch type {
        case .markdown: return "doc.text"
        case .code: return "curlybraces"
        case .plainText: return "doc.plaintext"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .office: return "briefcase"
        case .unsupported: return "doc"
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // 左侧自定义关闭与展开按钮，控制在 72px 宽度中靠左对齐，替代系统红绿灯
            HStack(spacing: 8) {
                // 关闭按钮
                CircleControlButton(iconName: "xmark", isHovered: isHeaderHovered) {
                    QuickLookOverlay.shared.closeWithAnimation()
                }
                
                // 展开/收起按钮
                CircleControlButton(iconName: "arrow.left.and.right", isHovered: isHeaderHovered) {
                    state.isExpanded.toggle()
                }
            }
            .frame(width: 72, alignment: .leading)
            
            Spacer()

            // 中间文件名 + 文件类型小图标 + 状态修饰点
            HStack(spacing: 6) {
                if let path = state.filePath {
                    HStack(spacing: 5) {
                        Image(systemName: fileIconName(for: state.renderType))
                            .font(.system(size: 11))
                            .foregroundColor(Color.appText.opacity(0.6))
                        
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.appText)
                    }
                } else if state.errorMessage != nil {
                    Text("获取失败".localized())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                } else {
                    Text("定位中...".localized())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.6))
                }
                
                // 状态修饰点
                Circle()
                    .fill(isModified ? Color.orange : (state.filePath == nil ? Color.gray.opacity(0.5) : Color.blue.opacity(0.8)))
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // 右侧控制区域（模式切换与保存，右对齐固定 72px）
            HStack(spacing: 12) {
                if state.filePath != nil && state.errorMessage == nil {
                    // 导出 PDF 按钮 (仅在预览 Markdown 时显示)
                    if state.renderType == .markdown && state.mode == .preview {
                        Group {
                            if isExportingPDF {
                                ProgressView()
                                    .progressViewStyle(LinearProgressViewStyle(tint: Color.appText.opacity(0.6)))
                                    .frame(width: 60)
                            } else {
                                Button(action: exportMarkdownToPDF) {
                                    Image("ToolbarExport")
                                        .renderingMode(.template)
                                        .resizable()
                                        .frame(width: 16, height: 16)
                                        .foregroundColor(Color.appText.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("导出 PDF".localized())
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isExportingPDF)
                    }
                    
                    if state.renderType != .pdf && state.renderType != .image && state.renderType != .office {
                        // 模式切换按钮
                        Button(action: toggleMode) {
                            Image(state.mode == .preview ? "ToolbarEdit" : "ToolbarPreview")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color.appText.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(state.mode == .preview ? "进入编辑 (Cmd+E)".localized() : "回到预览 (Esc)".localized())

                        // 保存按钮
                        if state.mode == .edit && isModified {
                            Button(action: saveFile) {
                                Image("ToolbarSave")
                                   .renderingMode(.template)
                                   .resizable()
                                   .frame(width: 16, height: 16)
                                   .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("保存 (Cmd+S)".localized())
                        }
                    }
                }
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.toolbarBackground)
        .onHover { hovering in
            isHeaderHovered = hovering
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: .bottom) {
            // 主展示内容
            mainContent
                .padding([.horizontal, .bottom], 28) // 保留精美的大内边距
            
            // 增量加载悬浮条
            if state.isIncrementalLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
                        .scaleEffect(0.8)
                    Text("正在载入后续内容...".localized())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        .cornerRadius(12)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if let err = state.errorMessage {
            UnsupportedFileView(filePath: state.filePath, errorMessage: err)
                .transition(.opacity)
        } else if state.isLoadingPath && state.filePath == nil {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(1.2)
                Text("正在定位 Finder 选中文件...".localized())
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
                Text("正在载入内容...".localized())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else {
            Group {
                switch state.mode {
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
                MarkdownView(filePath: path, markdownText: content)
            case .code:
                // NOTE: 将 settings 订阅下沉到 PreviewCodeView 内部，
                //       防止 Settings 变化导致 ContentView 根节点重绘触发 CodeView.updateNSView
                PreviewCodeView(
                    path: path,
                    content: content,
                    language: state.language,
                    isDark: isDark,
                    state: state,
                    onLoadMore: {
                        Task { await loadNextChunkAsync() }
                    }
                )
            case .plainText:
                PreviewCodeView(
                    path: path,
                    content: content,
                    language: nil,
                    isDark: isDark,
                    state: state,
                    onLoadMore: {
                        Task { await loadNextChunkAsync() }
                    }
                )
            case .pdf, .image:
                MediaPreviewView(filePath: path, renderType: renderType)
            case .office:
                OfficePreviewView(fileURL: URL(fileURLWithPath: path))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appBorder.opacity(0.3), lineWidth: 1)
                    )
            case .unsupported:
                UnsupportedFileView(filePath: path, errorMessage: state.errorMessage)
            }
        }
    }

    @ViewBuilder
    private var editView: some View {
        // NOTE: 将 settings 订阅下沉到 EditContentView 内部，训练范围最小化
        EditContentView(
            content: $content,
            isModified: $isModified,
            onSave: saveFile
        )
    }

    private func toggleMode() {
        if state.mode == .preview {
            // 准备进入编辑模式，确保后台一次性静默读完全文，以保证保存时内容的绝对完整性
            if state.hasMoreChunks, let reader = chunkReader {
                isLoading = true
                Task {
                    let result = await Task.detached(priority: .userInitiated) { () -> Result<String, FileUtils.FileError> in
                        return reader.readRemaining()
                    }.value
                    
                    await MainActor.run {
                        switch result {
                        case .success(let remainingText):
                            self.content += remainingText
                            self.state.hasMoreChunks = false
                            self.isLoading = false
                            self.state.mode = .edit
                        case .failure(let error):
                            self.errorMessage = (error.errorDescription ?? "读取剩余文件失败").localized()
                            self.isLoading = false
                            self.showErrorAlert = true
                        }
                    }
                }
            } else {
                state.mode = .edit
            }
        } else {
            state.mode = .preview
        }
    }

    private func saveFile() {
        guard let path = state.filePath else { return }
        isSaving = true
        let result = FileUtils.writeFile(at: path, content: content)

        switch result {
        case .success:
            isModified = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isSaving = false
            }
        case .failure(let error):
            errorMessage = error.errorDescription ?? "未知错误"
            showErrorAlert = true
            isSaving = false
        }
    }

    /// 后台并发异步读取首段，保证窗口 0ms 秒开起跳弹出
    private func loadFileAsync(path: String) async {
        if state.renderType == .pdf || state.renderType == .image || state.renderType == .unsupported || state.renderType == .office {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        // 1. 在后台初始化 chunkReader 并快速读取前 256KB
        let result = await Task.detached(priority: .userInitiated) { () -> Result<(FileChunkReader, String, Bool), FileUtils.FileError> in
            do {
                let reader = try FileChunkReader(path: path)
                let res = reader.readNextChunk(limitBytes: Constants.chunkSize)
                switch res {
                case .success(let payload):
                    return .success((reader, payload.content, payload.hasMore))
                case .failure(let error):
                    return .failure(error)
                }
            } catch let error as FileUtils.FileError {
                return .failure(error)
            } catch {
                return .failure(.readFailed(path: path, reason: error.localizedDescription))
            }
        }.value

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                switch result {
                case .success(let payload):
                    self.chunkReader = payload.0
                    self.content = payload.1
                    self.state.hasMoreChunks = payload.2
                    self.isLoading = false
                case .failure(let error):
                    self.errorMessage = (error.errorDescription ?? "读取文件失败").localized()
                    self.isLoading = false
                    self.state.errorMessage = self.errorMessage
                    if case .binaryFile = error {
                        self.state.renderType = .unsupported
                    }
                }
            }
        }
    }

    /// 后台线程增量读取后续段落，并通过 state.isIncrementalLoading 提示加载中
    private func loadNextChunkAsync() async {
        guard let reader = chunkReader, state.hasMoreChunks, !state.isIncrementalLoading else { return }
        
        await MainActor.run {
            state.isIncrementalLoading = true
        }
        
        let result = await Task.detached(priority: .userInitiated) { () -> Result<(String, Bool), FileUtils.FileError> in
            let res = reader.readNextChunk(limitBytes: Constants.chunkSize)
            switch res {
            case .success(let payload):
                return .success((payload.content, payload.hasMore))
            case .failure(let error):
                return .failure(error)
            }
        }.value
        
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.2)) {
                switch result {
                case .success(let payload):
                    self.content += payload.0
                    self.state.hasMoreChunks = payload.1
                    self.state.isIncrementalLoading = false
                case .failure(let error):
                    self.errorMessage = (error.errorDescription ?? "载入后续文本失败").localized()
                    self.state.isIncrementalLoading = false
                    QuickLookOverlay.shared.showToast(message: self.errorMessage, icon: "xmark.circle")
                }
            }
        }
    }

    private func startWatchingFile(path: String) {
        fileWatcher?.stop()
        fileWatcher = nil
        
        let watcher = FileWatcher(url: URL(fileURLWithPath: path))
        watcher.onFileChanged = {
            if self.isSaving { return }
            self.showReloadAlert = true
        }
        watcher.start()
        fileWatcher = watcher
    }

    private func exportMarkdownToPDF() {
        guard let path = state.filePath, state.renderType == .markdown else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        let fileURL = URL(fileURLWithPath: path)
        savePanel.directoryURL = fileURL.deletingLastPathComponent() // 默认导出路径保持与源文件一致
        savePanel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".pdf"
        savePanel.canCreateDirectories = true
        savePanel.prompt = "导出".localized()
        
        let completionHandler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .OK, let targetURL = savePanel.url {
                self.isExportingPDFActive = true
                self.isExportingPDF = false
                
                // 延迟 0.25 秒决定是否显示进度条，避免快速导出时产生闪现
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if self.isExportingPDFActive {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isExportingPDF = true
                        }
                    }
                }
                
                MarkdownPDFExporter.export(markdownText: self.content) { result in
                    DispatchQueue.main.async {
                        self.isExportingPDFActive = false
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.isExportingPDF = false
                        }
                        switch result {
                        case .success(let data):
                            do {
                                try data.write(to: targetURL)
                                // 窗口内成功提醒
                                self.localToastMessage = "PDF 导出成功".localized()
                                self.localToastIcon = "checkmark.circle"
                                self.showLocalToast = true
                            } catch {
                                // 窗口内失败提醒
                                self.localToastMessage = error.localizedDescription
                                self.localToastIcon = "xmark.circle"
                                self.showLocalToast = true
                            }
                        case .failure(let error):
                            // 窗口内失败提醒
                            self.localToastMessage = error.localizedDescription
                            self.localToastIcon = "xmark.circle"
                            self.showLocalToast = true
                        }
                    }
                }
            }
        }
        
        if let window = QuickLookOverlay.shared.currentWindow {
            savePanel.beginSheetModal(for: window, completionHandler: completionHandler)
        } else {
            savePanel.begin(completionHandler: completionHandler)
        }
    }
}

// MARK: - Settings 订阅隔离子视图

/// 代码预览的 Settings 隔离包装视图
/// NOTE: 将 Settings.shared 订阅下沉到此独立结构体，
///       避免 Settings 任意属性变化（如主题/语言切换）触发 ContentView 根节点重绘，
///       进而避免 CodeView.updateNSView 被冗余调用导致滚动卡顿
private struct PreviewCodeView: View {
    let path: String
    let content: String
    let language: String?
    let isDark: Bool
    let state: PreviewState
    let onLoadMore: () -> Void

    // NOTE: 恢复 @ObservedObject 绑定，以实现设置修改时文本字号与字体的实时热联动
    @ObservedObject private var settings = Settings.shared

    init(path: String, content: String, language: String?, isDark: Bool, state: PreviewState, onLoadMore: @escaping () -> Void) {
        self.path = path
        self.content = content
        self.language = language
        self.isDark = isDark
        self.state = state
        self.onLoadMore = onLoadMore
    }

    var body: some View {
        CodeView(
            filePath: path,
            content: content,
            language: language,
            fontSize: settings.fontSize,
            fontName: settings.editorFont,
            isDark: isDark,
            state: state,
            onLoadMore: onLoadMore
        )
    }
}

/// 编辑器的 Settings 隔离包装视图
/// NOTE: 同上，恢复 @ObservedObject 绑定
private struct EditContentView: View {
    @Binding var content: String
    @Binding var isModified: Bool
    let onSave: () -> Void

    @ObservedObject private var settings = Settings.shared

    init(content: Binding<String>, isModified: Binding<Bool>, onSave: @escaping () -> Void) {
        self._content = content
        self._isModified = isModified
        self.onSave = onSave
    }

    var body: some View {
        EditorView(
            content: $content,
            isModified: $isModified,
            fontSize: settings.fontSize,
            fontName: settings.editorFont,
            showLineNumbers: settings.showLineNumbers,
            onSave: onSave
        )
    }
}

// MARK: - 自定义灰色圆形控制按钮组件 (替代系统红绿灯)
struct CircleControlButton: View {
    let iconName: String
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isButtonHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isButtonHovered ? Color.appText.opacity(0.18) : Color.appText.opacity(0.08))
                    .frame(width: 13, height: 13)
                
                Image(systemName: iconName)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color.appText.opacity(0.7))
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isButtonHovered = hovering
        }
    }
}