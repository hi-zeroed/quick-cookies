import SwiftUI
import UniformTypeIdentifiers

enum ContentMode {
    case preview    // 预览模式
    case edit       // 编辑模式
}

struct PreviewWindowActions {
    let closeOverlay: () -> Void
    let focusWindowForEdit: () -> Void
    let focusWindowForPreview: () -> Void
    let unfocusWindowToFinder: () -> Void
    let showToast: (_ message: String, _ icon: String?) -> Void
    let currentWindow: () -> NSWindow?
}

struct PreviewDisplayState: Equatable {
    let filePath: String?
    let displayName: String?
    let renderType: FileRenderType?
    let language: String?
    let mode: ContentMode
    let errorMessage: String?
    let isLoadingPath: Bool
    let isExpanded: Bool
}

enum PreviewPlaceholderPolicy {
    static func subtitle(for renderType: FileRenderType) -> String {
        "Loading content...".localized()
    }
}

enum HeavyPreviewVisibilityPolicy {
    static func shouldGateVisibility(for renderType: FileRenderType) -> Bool {
        renderType == .pdf
    }
}

enum PreviewFileIconAssetRegistry {
    static func assetName(for renderType: FileRenderType?) -> String? {
        // 文件类型图标必须来自产品提供的资产。资产未接入前不使用 SF Symbols 或系统文件图标兜底。
        nil
    }
}

struct ContentRenderCapability {
    let allowsEditing: Bool
    let allowsPDFExport: Bool
    let usesTextContentLoader: Bool
    let showsGenericLoading: Bool
}

enum ContentRenderCapabilityRegistry {
    static func capability(for renderType: FileRenderType?) -> ContentRenderCapability {
        switch renderType {
        case .markdown:
            return ContentRenderCapability(
                allowsEditing: true,
                allowsPDFExport: true,
                usesTextContentLoader: true,
                showsGenericLoading: false
            )
        case .code, .plainText:
            return ContentRenderCapability(
                allowsEditing: true,
                allowsPDFExport: false,
                usesTextContentLoader: true,
                showsGenericLoading: true
            )
        case .pdf, .image, .office, .unsupported, .none:
            return ContentRenderCapability(
                allowsEditing: false,
                allowsPDFExport: false,
                usesTextContentLoader: false,
                showsGenericLoading: false
            )
        }
    }

    static func allowsEditing(for renderType: FileRenderType?) -> Bool {
        capability(for: renderType).allowsEditing
    }

    static func allowsPDFExport(for renderType: FileRenderType?, mode: ContentMode) -> Bool {
        mode == .preview && capability(for: renderType).allowsPDFExport
    }

    static func usesTextContentLoader(for renderType: FileRenderType?) -> Bool {
        capability(for: renderType).usesTextContentLoader
    }

    static func showsGenericLoading(for renderType: FileRenderType?) -> Bool {
        capability(for: renderType).showsGenericLoading
    }
}

enum ContentLoadingPresentationPolicy {
    static func shouldShowGenericLoading(
        isLoading: Bool,
        renderType: FileRenderType?
    ) -> Bool {
        guard isLoading else { return false }
        return ContentRenderCapabilityRegistry.showsGenericLoading(for: renderType)
    }
}

enum PreviewContentVisibilityPolicy {
    static func canRenderLoadedContent(
        renderType: FileRenderType?,
        activePath: String?,
        loadedContentPath: String?
    ) -> Bool {
        guard let renderType else {
            return false
        }

        guard ContentRenderCapabilityRegistry.usesTextContentLoader(for: renderType) else {
            return true
        }

        guard let activePath, let loadedContentPath else {
            return false
        }

        return activePath == loadedContentPath
    }
}

enum PreviewIncrementalContentLoadPolicy {
    static func shouldApplyChunk(
        request: PreviewContentLoadRequest,
        activeRequest: PreviewContentLoadRequest?,
        activePath: String?,
        loadedContentPath: String?
    ) -> Bool {
        request == activeRequest && request.path == activePath && request.path == loadedContentPath
    }
}

enum PreviewEditPreparationPolicy {
    static func shouldApplyRemainingText(
        request: PreviewContentLoadRequest,
        activeRequest: PreviewContentLoadRequest?,
        activePath: String?,
        loadedContentPath: String?
    ) -> Bool {
        request == activeRequest && request.path == activePath && request.path == loadedContentPath
    }
}

enum PreviewAsyncRequestCleanupPolicy {
    static func shouldClearLoadingForRejectedResult(
        request: PreviewContentLoadRequest,
        activeRequest: PreviewContentLoadRequest?
    ) -> Bool {
        request == activeRequest
    }
}

enum ContentEditingPolicy {
    static func allowsEditing(for renderType: FileRenderType?) -> Bool {
        ContentRenderCapabilityRegistry.allowsEditing(for: renderType)
    }
}

enum PreviewDisplayStateResolver {
    static func resolve(sessionState: PreviewSessionState) -> PreviewDisplayState {
        return PreviewDisplayState(
            filePath: sessionState.target?.resolvedPath,
            displayName: sessionState.target?.displayName,
            renderType: sessionState.displayRenderType,
            language: sessionState.target?.language,
            mode: sessionState.mode == .edit ? .edit : .preview,
            errorMessage: sessionState.errorMessage,
            isLoadingPath: sessionState.readiness == .loading,
            isExpanded: sessionState.isExpanded
        )
    }
}

struct PreviewReadinessState: Equatable {
    let token: UUID
    let isReady: Bool
}

enum PreviewReadinessGate {
    static func resetState(
        for renderType: FileRenderType?,
        tokenFactory: () -> UUID = UUID.init
    ) -> PreviewReadinessState {
        PreviewReadinessState(
            token: tokenFactory(),
            isReady: !isHeavyRenderType(renderType)
        )
    }

    static func acceptingReady(
        from token: UUID,
        current: PreviewReadinessState
    ) -> PreviewReadinessState? {
        guard token == current.token, !current.isReady else {
            return nil
        }

        return PreviewReadinessState(token: current.token, isReady: true)
    }

    static func isHeavyRenderType(_ renderType: FileRenderType?) -> Bool {
        renderType == .image || renderType == .pdf || renderType == .office
    }
}

final class PreviewLoadState: ObservableObject {
    // 大文件分段增量读取状态
    @Published var hasMoreChunks: Bool = false
    @Published var isIncrementalLoading: Bool = false

    func reset() {
        hasMoreChunks = false
        isIncrementalLoading = false
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var loadState: PreviewLoadState
    @ObservedObject private var session: PreviewSession
    private let windowActions: PreviewWindowActions
    private let cardOuterPadding: CGFloat

    @State private var content: String = ""
    @State private var loadedContentPath: String? = nil
    @State private var isLoading: Bool = true
    @State private var isTruncated: Bool = false
    @State private var isModified: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var saveErrorMessage: String = ""
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
    @State private var markdownPreviewTimeline: MarkdownPreviewTimelineTracker? = nil
    @State private var markdownHasLoadedInitialContent: Bool = false
    // 头部顶栏 Hover 状态
    @State private var isHeaderHovered: Bool = false
    @State private var previewReadinessState = PreviewReadinessGate.resetState(for: nil)
    @State private var markdownBootstrapReady: Bool = false
    @State private var loadCoordinator = PreviewContentLoadCoordinator()
    @State private var contentReloadGeneration: Int = 0
    @State private var inflightLoadPath: String? = nil

    // NOTE: 不在 ContentView 根节点订阅 Settings.shared，
    //       避免任意设置变化触发整个视图树 invalidate + CodeView.updateNSView 冒餐调用。
    //       fontSize / editorFont 只在 previewView / editView 子节点内读取，训练范围最小化。

    init(
        session: PreviewSession,
        loadState: PreviewLoadState,
        windowActions: PreviewWindowActions,
        cardOuterPadding: CGFloat = 40
    ) {
        self.loadState = loadState
        self.session = session
        self.windowActions = windowActions
        self.cardOuterPadding = cardOuterPadding
    }

    private var sessionState: PreviewSessionState {
        session.state
    }

    private var displayState: PreviewDisplayState {
        PreviewDisplayStateResolver.resolve(sessionState: sessionState)
    }

    private var activePath: String? {
        displayState.filePath
    }

    private var activeRenderType: FileRenderType? {
        displayState.renderType
    }

    private var activeDisplayName: String? {
        displayState.displayName
    }

    private var activeLanguage: String? {
        displayState.language
    }

    private var activeMode: ContentMode {
        displayState.mode
    }

    private var activeErrorMessage: String? {
        displayState.errorMessage
    }

    private var allowsEditing: Bool {
        ContentEditingPolicy.allowsEditing(for: activeRenderType)
    }

    private var isLocatingSelection: Bool {
        displayState.isLoadingPath && activePath == nil
    }

    private var canRenderLoadedContent: Bool {
        PreviewContentVisibilityPolicy.canRenderLoadedContent(
            renderType: activeRenderType,
            activePath: activePath,
            loadedContentPath: loadedContentPath
        )
    }

    private var contentIdentityKey: String {
        let baseKey = PreviewContentIdentity.makeKey(
            path: activePath,
            renderType: activeRenderType,
            mode: activeMode
        )
        return "\(baseKey)#\(contentReloadGeneration)"
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
        .customAlert(
            isPresented: $showReloadAlert,
            title: "File Updated Externally".localized(),
            message: "This file has been modified by another editor. Reload the latest changes?".localized(),
            primaryButton: .primary("Reload".localized()) {
                if let path = activePath {
                    isLoading = true
                    Task {
                        let didApply = await loadFileAsync(path: path)
                        if didApply {
                            startWatchingFile(path: path)
                        }
                    }
                }
            },
            secondaryButton: .secondary("Ignore".localized())
        )
        .customAlert(
            isPresented: $showErrorAlert,
            title: "Save Failed".localized(),
            message: saveErrorMessage.localized(),
            primaryButton: .primary("OK".localized())
        )
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
        .padding(cardOuterPadding)
        .background(Color.clear) // 根容器背景必须是透明 clear，保持留白边缘穿透
        .toast(isShowing: $showLocalToast, message: localToastMessage, icon: localToastIcon)
        .onDisappear {
            fileWatcher?.stop()
            fileWatcher = nil
            chunkReader?.close()
            chunkReader = nil
            markdownPreviewTimeline = nil
            markdownHasLoadedInitialContent = false
            previewReadinessState = PreviewReadinessGate.resetState(for: nil)
            markdownBootstrapReady = false
            loadedContentPath = nil
        }
        .task {
            if let path = activePath {
                await triggerPathLoadIfNeeded(path: path)
            }
        }
        .onChange(of: activePath) { newPath in
            if let path = newPath {
                prepareForIncomingPath(path)
                Task {
                    await triggerPathLoadIfNeeded(path: path)
                }
            } else {
                loadCoordinator.reset()
                inflightLoadPath = nil
                fileWatcher?.stop()
                fileWatcher = nil
                chunkReader?.close()
                chunkReader = nil
                content = ""
                loadedContentPath = nil
                isModified = false
                showReloadAlert = false
                markdownPreviewTimeline = nil
                markdownHasLoadedInitialContent = false
                previewReadinessState = PreviewReadinessGate.resetState(for: nil)
                markdownBootstrapReady = false
            }
        }
        .onChange(of: activeRenderType) { newRenderType in
            resetHeavyPreviewState(for: newRenderType)
            markdownBootstrapReady = false
            if newRenderType != .markdown {
                markdownPreviewTimeline = nil
                markdownHasLoadedInitialContent = false
            }
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            // 左侧自定义关闭与展开按钮，控制在 72px 宽度中靠左对齐，替代系统红绿灯
            HStack(spacing: 8) {
                // 关闭按钮
                CircleControlButton(iconName: "xmark", isHovered: isHeaderHovered) {
                    windowActions.closeOverlay()
                }
                
                // 展开/收起按钮
                CircleControlButton(iconName: "arrow.left.and.right", isHovered: isHeaderHovered) {
                    session.toggleExpanded()
                }
            }
            .frame(width: 72, alignment: .leading)
            
            Spacer()

            // 中间文件名 + 文件类型小图标 + 状态修饰点
            HStack(spacing: 6) {
                if let displayName = activeDisplayName {
                    HStack(spacing: 5) {
                        previewFileIcon(for: activeRenderType)

                        Text(displayName)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.appText)
                    }
                } else if let path = activePath {
                    HStack(spacing: 5) {
                        previewFileIcon(for: activeRenderType)
                        
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.appText)
                    }
                } else if activeErrorMessage != nil {
                    Text("Failed to Get".localized())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                } else {
                    Text("Locating...".localized())
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.6))
                }
                
                // 状态修饰点
                Circle()
                    .fill(isModified ? Color.orange : (activePath == nil ? Color.gray.opacity(0.5) : Color.blue.opacity(0.8)))
                    .frame(width: 6, height: 6)
            }

            Spacer()

            // 右侧控制区域（模式切换与保存，右对齐固定 72px）
            HStack(spacing: 12) {
                if activePath != nil && activeErrorMessage == nil {
                    if ContentRenderCapabilityRegistry.allowsPDFExport(
                        for: activeRenderType,
                        mode: activeMode
                    ) {
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
                                .help("Export PDF".localized())
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isExportingPDF)
                    }
                    
                    if allowsEditing {
                        // 模式切换按钮
                        Button(action: toggleMode) {
                            Image(activeMode == .preview ? "ToolbarEdit" : "ToolbarPreview")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color.appText.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help(activeMode == .preview ? "Enter Edit (Cmd+E)".localized() : "Back to Preview".localized())

                        // 保存按钮
                        if activeMode == .edit && isModified {
                            Button(action: saveFile) {
                                Image("ToolbarSave")
                                   .renderingMode(.template)
                                   .resizable()
                                   .frame(width: 16, height: 16)
                                   .foregroundColor(.orange)
                            }
                            .buttonStyle(.plain)
                            .help("Save (Cmd+S)".localized())
                        }
                    }
                }
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onHover { hovering in
            isHeaderHovered = hovering
        }
    }

    @ViewBuilder
    private func previewFileIcon(for renderType: FileRenderType?) -> some View {
        if let assetName = PreviewFileIconAssetRegistry.assetName(for: renderType) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .frame(width: 12, height: 12)
                .foregroundColor(Color.appText.opacity(0.6))
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: .bottom) {
            let isImage = activeRenderType == .image
            mainContent
                .id(contentIdentityKey)
                .background(isImage ? Color.clear : Color.appBackground)
                .cornerRadius(15)
                .overlay(
                    Group {
                        if !isImage {
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.appBorder.opacity(colorScheme == .dark ? 0.25 : 0.12), lineWidth: 0.8)
                        }
                    }
                )
                .padding([.horizontal, .bottom], 5) // 调整内边距至 5pt

            if shouldShowLoadingOverlay {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.4)))
                    Text("Loading content...".localized())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground.opacity(0.98))
                .cornerRadius(15)
                .padding([.horizontal, .bottom], 5)
                .transition(.opacity)
            }
            
            // 增量加载悬浮条
            if loadState.isIncrementalLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
                        .scaleEffect(0.8)
                    Text("Loading remaining content...".localized())
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
        if activeRenderType == .unsupported {
            UnsupportedFileView(filePath: activePath, errorMessage: activeErrorMessage)
                .transition(.opacity)
        } else if isLocatingSelection {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(1.2)
                Text("Locating selected file in Finder...".localized())
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else if ContentLoadingPresentationPolicy.shouldShowGenericLoading(
            isLoading: isLoading || !canRenderLoadedContent,
            renderType: activeRenderType
        ) {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.4)))
                Text("Loading content...".localized())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        } else {
            Group {
                switch activeMode {
                case .preview:
                    if shouldRenderPreviewView {
                        previewView
                    }
                case .edit:
                    editView
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var previewView: some View {
        if let path = activePath, let renderType = activeRenderType {
            let isDark = colorScheme == .dark
            switch renderType {
            case .markdown:
                MarkdownView(
                    filePath: path,
                    markdownText: content,
                    previewTimeline: markdownPreviewTimeline,
                    onBootstrapReady: {
                        guard isLoading else { return }
                        withAnimation(.easeOut(duration: 0.16)) {
                            markdownBootstrapReady = true
                            isLoading = false
                        }
                    }
                )
            case .code:
                // NOTE: 将 settings 订阅下沉到 PreviewCodeView 内部，
                //       防止 Settings 变化导致 ContentView 根节点重绘触发 CodeView.updateNSView
                PreviewCodeView(
                    path: path,
                    content: content,
                    language: activeLanguage,
                    isDark: isDark,
                    loadState: loadState,
                    onLoadMore: {
                        Task { await loadNextChunkAsync(for: path) }
                    }
                )
            case .plainText:
                PreviewCodeView(
                    path: path,
                    content: content,
                    language: nil,
                    isDark: isDark,
                    loadState: loadState,
                    onLoadMore: {
                        Task { await loadNextChunkAsync(for: path) }
                    }
                )
            case .pdf, .image:
                heavyPreviewContainer(
                    title: URL(fileURLWithPath: path).lastPathComponent,
                    renderType: renderType
                ) {
                    MediaPreviewView(
                        filePath: path,
                        renderType: renderType,
                        readyToken: previewReadinessState.token,
                        onReady: markHeavyPreviewReady
                    )
                }
            case .office:
                heavyPreviewContainer(
                    title: activeDisplayName ?? URL(fileURLWithPath: path).lastPathComponent,
                    renderType: renderType
                ) {
                    OfficePreviewView(
                        fileURL: URL(fileURLWithPath: path),
                        readyToken: previewReadinessState.token,
                        onReady: markHeavyPreviewReady
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.appBorder.opacity(0.3), lineWidth: 1)
                    )
                }
            case .unsupported:
                UnsupportedFileView(filePath: path, errorMessage: activeErrorMessage)
            }
        }
    }

    @ViewBuilder
    private func heavyPreviewContainer<Content: View>(
        title: String,
        renderType: FileRenderType,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            content()
                .opacity(
                    HeavyPreviewVisibilityPolicy.shouldGateVisibility(for: renderType) && !previewReadinessState.isReady
                    ? 0.001
                    : 1.0
                )
            
            if HeavyPreviewVisibilityPolicy.shouldGateVisibility(for: renderType) && !previewReadinessState.isReady {
                PreviewPlaceholderView(title: title, renderType: renderType)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.16), value: previewReadinessState.isReady)
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
        if activeMode == .preview {
            guard allowsEditing else { return }

            // 准备进入编辑模式，确保后台一次性静默读完全文，以保证保存时内容的绝对完整性
            if loadState.hasMoreChunks, let reader = chunkReader {
                guard let request = loadCoordinator.activeRequest,
                      PreviewEditPreparationPolicy.shouldApplyRemainingText(
                        request: request,
                        activeRequest: loadCoordinator.activeRequest,
                        activePath: activePath,
                        loadedContentPath: loadedContentPath
                      ) else { return }

                isLoading = true
                Task {
                    let result = await Task.detached(priority: .userInitiated) { () -> Result<String, FileUtils.FileError> in
                        return reader.readRemaining()
                    }.value
                    
                    await MainActor.run {
                        guard PreviewEditPreparationPolicy.shouldApplyRemainingText(
                            request: request,
                            activeRequest: loadCoordinator.activeRequest,
                            activePath: activePath,
                            loadedContentPath: loadedContentPath
                        ) else {
                            if PreviewAsyncRequestCleanupPolicy.shouldClearLoadingForRejectedResult(
                                request: request,
                                activeRequest: loadCoordinator.activeRequest
                            ) {
                                self.isLoading = false
                            }
                            return
                        }

                        switch result {
                        case .success(let remainingText):
                            self.content += remainingText
                            self.loadState.hasMoreChunks = false
                            self.isLoading = false
                            self.transitionToEditMode()
                            // 模式改变后，使窗口获得焦点以便能够键盘打字输入
                            windowActions.focusWindowForEdit()
                        case .failure(let error):
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                self.saveErrorMessage = (error.errorDescription ?? "读取剩余文件失败").localized()
                                self.isLoading = false
                                self.showErrorAlert = true
                            }
                        }
                    }
                }
            } else {
                transitionToEditMode()
                // 模式改变后，使窗口获得焦点以便能够键盘打字输入
                windowActions.focusWindowForEdit()
            }
        } else {
            transitionToPreviewMode()
            // 返回预览模式后按来源策略决定焦点，保持 Finder 驱动预览不抢焦点。
            windowActions.focusWindowForPreview()
        }
    }

    private func saveFile() {
        guard let path = activePath else { return }
        isSaving = true
        let result = FileUtils.writeFile(at: path, content: content)

        switch result {
        case .success:
            isModified = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isSaving = false
            }
        case .failure(let error):
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                saveErrorMessage = error.errorDescription ?? "未知错误"
                showErrorAlert = true
                isSaving = false
            }
        }
    }

    /// 后台并发异步读取首段，保证窗口 0ms 秒开起跳弹出
    private func loadFileAsync(path: String) async -> Bool {
        let request = await MainActor.run { () -> PreviewContentLoadRequest in
            let previousPath = loadCoordinator.activeRequest?.path
            let isReloadingSamePath = previousPath == path
            let request = loadCoordinator.beginLoad(path: path)
            showReloadAlert = false
            fileWatcher?.stop()
            fileWatcher = nil
            chunkReader?.close()
            chunkReader = nil
            if !isReloadingSamePath {
                content = ""
            }
            isModified = false
            saveErrorMessage = ""
            loadState.hasMoreChunks = false
            loadState.isIncrementalLoading = false
            if PreviewContentReloadIdentityPolicy.shouldBumpGeneration(
                previousPath: previousPath,
                nextPath: path
            ) {
                contentReloadGeneration += 1
            }
            resetHeavyPreviewState(for: activeRenderType)
            return request
        }

        if activeRenderType == .markdown {
            await MainActor.run {
                markdownPreviewTimeline = MarkdownPreviewTimelineTracker(filePath: path)
                markdownHasLoadedInitialContent = false
            }
        } else {
            await MainActor.run {
                markdownPreviewTimeline = nil
                markdownHasLoadedInitialContent = false
            }
        }

        if !ContentRenderCapabilityRegistry.usesTextContentLoader(for: activeRenderType) {
            return await MainActor.run {
                guard loadCoordinator.shouldApplyResult(for: request, currentPath: activePath) else {
                    return false
                }
                self.session.markReady()
                self.isLoading = false
                return true
            }
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

        return await MainActor.run {
            guard loadCoordinator.shouldApplyResult(for: request, currentPath: activePath) else {
                if case .success(let payload) = result {
                    payload.0.close()
                }
                return false
            }

            withAnimation(.easeOut(duration: 0.2)) {
                switch result {
                case .success(let payload):
                    self.chunkReader = payload.0
                    self.content = payload.1
                    self.loadedContentPath = path
                    self.loadState.hasMoreChunks = payload.2
                    self.session.markReady()
                    if self.activeRenderType == .markdown {
                        self.markdownHasLoadedInitialContent = true
                        self.markdownPreviewTimeline?.mark(.firstChunkReady)
                        self.markdownBootstrapReady = false
                    } else {
                        self.isLoading = false
                    }
                case .failure(let error):
                    let runtimeErrorMessage = (error.errorDescription ?? "读取文件失败").localized()
                    self.loadedContentPath = nil
                    let renderTypeOverride: FileRenderType?
                    if case .binaryFile = error {
                        renderTypeOverride = .unsupported
                    } else {
                        renderTypeOverride = nil
                    }
                    self.session.applyRuntimeFailure(
                        message: runtimeErrorMessage,
                        renderTypeOverride: renderTypeOverride
                    )
                    self.isLoading = false
                }
            }
            return true
        }
    }

    /// 后台线程增量读取后续段落，并通过 loadState.isIncrementalLoading 提示加载中
    @MainActor
    private func loadNextChunkAsync(for requestPath: String) async {
        guard let request = loadCoordinator.activeRequest else { return }

        guard let reader = chunkReader,
              loadState.hasMoreChunks,
              !loadState.isIncrementalLoading,
              PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
                request: request,
                activeRequest: loadCoordinator.activeRequest,
                activePath: activePath,
                loadedContentPath: loadedContentPath
              ),
              request.path == requestPath else { return }

        loadState.isIncrementalLoading = true
        
        let result = await Task.detached(priority: .userInitiated) { () -> Result<(String, Bool), FileUtils.FileError> in
            let res = reader.readNextChunk(limitBytes: Constants.chunkSize)
            switch res {
            case .success(let payload):
                return .success((payload.content, payload.hasMore))
            case .failure(let error):
                return .failure(error)
            }
        }.value

        guard PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
            request: request,
            activeRequest: loadCoordinator.activeRequest,
            activePath: activePath,
            loadedContentPath: loadedContentPath
        ) else {
            if PreviewAsyncRequestCleanupPolicy.shouldClearLoadingForRejectedResult(
                request: request,
                activeRequest: loadCoordinator.activeRequest
            ) {
                loadState.isIncrementalLoading = false
            }
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            switch result {
            case .success(let payload):
                self.content += payload.0
                self.loadState.hasMoreChunks = payload.1
                self.loadState.isIncrementalLoading = false
            case .failure(let error):
                let runtimeErrorMessage = (error.errorDescription ?? "载入后续文本失败").localized()
                self.loadState.isIncrementalLoading = false
                windowActions.showToast(runtimeErrorMessage, "xmark.circle")
            }
        }
    }

    private func startWatchingFile(path: String) {
        fileWatcher?.stop()
        fileWatcher = nil
        
        let watcher = FileWatcher(url: URL(fileURLWithPath: path))
        watcher.onFileChanged = {
            if self.isSaving { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                self.showReloadAlert = true
            }
        }
        watcher.start()
        fileWatcher = watcher
    }

    @MainActor
    private func triggerPathLoadIfNeeded(path: String) async {
        guard inflightLoadPath != path else { return }

        inflightLoadPath = path
        prepareForIncomingPath(path)
        isLoading = true
        resetHeavyPreviewState(for: activeRenderType)
        markdownBootstrapReady = false

        let didApply = await loadFileAsync(path: path)
        if didApply {
            startWatchingFile(path: path)
        }

        if inflightLoadPath == path {
            inflightLoadPath = nil
        }
    }

    @MainActor
    private func prepareForIncomingPath(_ path: String) {
        guard loadedContentPath != path else {
            return
        }

        content = ""
        loadedContentPath = nil
        markdownHasLoadedInitialContent = false
        markdownBootstrapReady = false
        isLoading = true
    }

    private func resetHeavyPreviewState(for renderType: FileRenderType?) {
        previewReadinessState = PreviewReadinessGate.resetState(for: renderType)
    }

    private func transitionToEditMode() {
        session.enterEditMode()
    }

    private func transitionToPreviewMode() {
        session.returnToPreviewMode()
    }

    private func markHeavyPreviewReady(_ token: UUID) {
        guard let nextState = PreviewReadinessGate.acceptingReady(
            from: token,
            current: previewReadinessState
        ) else {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            previewReadinessState = nextState
        }
    }

    private func isHeavyRenderType(_ renderType: FileRenderType?) -> Bool {
        PreviewReadinessGate.isHeavyRenderType(renderType)
    }

    private var shouldShowLoadingOverlay: Bool {
        guard activeRenderType == .markdown, activeMode == .preview, activePath != nil else { return false }
        guard isLoading || !canRenderLoadedContent else { return false }
        return !canRenderLoadedContent || !markdownBootstrapReady
    }

    private var shouldRenderPreviewView: Bool {
        guard let renderType = activeRenderType else { return false }
        guard canRenderLoadedContent else { return false }
        return MarkdownPreviewDisplayPolicy.shouldMountPreview(
            renderType: renderType,
            isLoading: isLoading,
            hasLoadedInitialContent: markdownHasLoadedInitialContent,
            keepsPreviousPreviewMounted: renderType == .markdown &&
                activePath == loadedContentPath &&
                !content.isEmpty
        )
    }

    private func exportMarkdownToPDF() {
        guard let path = activePath,
              ContentRenderCapabilityRegistry.allowsPDFExport(
                for: activeRenderType,
                mode: activeMode
              ) else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        let fileURL = URL(fileURLWithPath: path)
        savePanel.directoryURL = fileURL.deletingLastPathComponent() // 默认导出路径保持与源文件一致
        savePanel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".pdf"
        savePanel.canCreateDirectories = true
        savePanel.prompt = "Export".localized()
        
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
                                self.localToastMessage = "PDF exported successfully".localized()
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
        
        if let window = windowActions.currentWindow() {
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
    let loadState: PreviewLoadState
    let onLoadMore: () -> Void

    // NOTE: 恢复 @ObservedObject 绑定，以实现设置修改时文本字号与字体的实时热联动
    @ObservedObject private var settings = Settings.shared

    init(path: String, content: String, language: String?, isDark: Bool, loadState: PreviewLoadState, onLoadMore: @escaping () -> Void) {
        self.path = path
        self.content = content
        self.language = language
        self.isDark = isDark
        self.loadState = loadState
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
            loadState: loadState,
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

private struct PreviewPlaceholderView: View {
    let title: String
    let renderType: FileRenderType

    private var subtitle: String {
        PreviewPlaceholderPolicy.subtitle(for: renderType)
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            if let assetName = PreviewFileIconAssetRegistry.assetName(for: renderType) {
                Image(assetName)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .foregroundColor(Color.appText.opacity(0.72))
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.appText)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.appText.opacity(0.5))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.opacity(0.92))
    }
}

// MARK: - 自定义灰色圆形控制按钮组件 (替代系统红绿灯)
struct CircleControlButton: View {
    @Environment(\.colorScheme) var colorScheme
    let iconName: String
    let isHovered: Bool
    let action: () -> Void
    
    @State private var isButtonHovered: Bool = false
    
    private var circleFillColor: Color {
        let isDark = colorScheme == .dark
        if isButtonHovered {
            if iconName == "xmark" {
                return isDark ? Color.red.opacity(0.8) : Color.red.opacity(0.75)
            } else {
                return isDark ? Color.white.opacity(0.32) : Color.black.opacity(0.22)
            }
        } else {
            return isDark ? Color.white.opacity(0.18) : Color.black.opacity(0.10)
        }
    }
    
    private var iconColor: Color {
        let isDark = colorScheme == .dark
        if isButtonHovered && iconName == "xmark" {
            return .white
        } else {
            return isDark ? Color.white.opacity(0.8) : Color.black.opacity(0.8)
        }
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(circleFillColor)
                    .frame(width: 13, height: 13)
                
                Image(systemName: iconName)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(iconColor)
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
