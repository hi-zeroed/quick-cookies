import SwiftUI
import UniformTypeIdentifiers
import Combine

struct PreviewWindowActions {
    let closeOverlay: () -> Void
    let showToast: (_ message: String, _ icon: String?) -> Void
    let currentWindow: () -> NSWindow?
    var onSearchStateChanged: ((Bool) -> Void)? = nil
    var triggerSearchSubject: PassthroughSubject<Void, Never>? = nil
    var triggerGoToLineSubject: PassthroughSubject<Void, Never>? = nil
    var triggerTelemetrySubject: PassthroughSubject<Void, Never>? = nil
    var openPath: ((String, PreviewLaunchSource) -> Void)? = nil
}

struct PreviewDisplayState: Equatable {
    let filePath: String?
    let displayName: String?
    let renderType: FileRenderType?
    let language: String?
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

enum PreviewCardChromePolicy {
    enum LightBorderSource {
        case systemSeparator
    }

    static let cornerRadius: CGFloat = 20
    static let borderLineWidth: CGFloat = 0.75
    static let lightBorderOpacity: Double = 0.08
    static let lightBorderSource: LightBorderSource = .systemSeparator
    static let darkBorderOpacity: Double = 0.26
    static let innerHighlightLineWidth: CGFloat = 0.5
    static let lightInnerHighlightOpacity: Double = 0.35
    static let darkInnerHighlightOpacity: Double = 0.10
    static let ambientShadowRadius: CGFloat = 0
    static let contactShadowRadius: CGFloat = 0

    static var lightBorderColor: Color {
        switch lightBorderSource {
        case .systemSeparator:
            return Color(NSColor.separatorColor).opacity(lightBorderOpacity)
        }
    }
}

/// 兼容性别名，直接映射至统一插件注册中心 PreviewProviderRegistry
typealias ContentRenderCapabilityRegistry = PreviewProviderRegistry

enum ContentLoadingPresentationPolicy {
    static func shouldShowGenericLoading(
        isLoading: Bool,
        renderType: FileRenderType?
    ) -> Bool {
        guard isLoading else { return false }
        return PreviewProviderRegistry.showsGenericLoading(for: renderType)
    }
}

enum PreviewContentAreaChrome {
    public enum BackgroundStyle: Equatable {
        case appBackground
        case transparent
    }

    public enum BorderStyle: Equatable {
        case appBorder
        case none
    }

    static func backgroundStyle(for renderType: FileRenderType?, isSVGSourceMode: Bool = false) -> BackgroundStyle {
        if isSVGSourceMode {
            return .appBackground
        }
        switch renderType {
        case .image, .unsupported:
            return .transparent
        case .markdown, .code, .plainText, .pdf, .office, .archive, .folder, .audio, .video, .font, .hex, .csv, .none:
            return .appBackground
        }
    }

    static func borderStyle(for renderType: FileRenderType?, isSVGSourceMode: Bool = false) -> BorderStyle {
        if isSVGSourceMode {
            return .appBorder
        }
        switch renderType {
        case .image, .unsupported:
            return .none
        case .markdown, .code, .plainText, .pdf, .office, .archive, .folder, .audio, .video, .font, .hex, .csv, .none:
            return .appBorder
        }
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

        guard PreviewProviderRegistry.usesTextContentLoader(for: renderType, path: activePath) else {
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

enum PreviewAsyncRequestCleanupPolicy {
    static func shouldClearLoadingForRejectedResult(
        request: PreviewContentLoadRequest,
        activeRequest: PreviewContentLoadRequest?
    ) -> Bool {
        request == activeRequest
    }
}

enum PreviewDisplayStateResolver {
    static func resolve(sessionState: PreviewSessionState) -> PreviewDisplayState {
        let errorMessage = sessionState.errorMessage
        let renderType = sessionState.displayRenderType ?? (errorMessage == nil ? nil : .unsupported)

        return PreviewDisplayState(
            filePath: sessionState.target?.resolvedPath,
            displayName: sessionState.target?.displayName,
            renderType: renderType,
            language: sessionState.target?.language,
            errorMessage: errorMessage,
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
    @ObservedObject private var historyNavigator = SessionHistoryNavigator.shared
    private let windowActions: PreviewWindowActions
    private let cardOuterPadding: CGFloat

    @State private var content: String = ""
    @State private var loadedContentPath: String? = nil
    @State private var isLoading: Bool = true
    @State private var isTruncated: Bool = false
    // Markdown 导出 PDF 状态与本地 Toast 提示
    @State private var isExportingPDFActive: Bool = false
    @State private var isExportingPDF: Bool = false
    @State private var showLocalToast: Bool = false
    @State private var localToastMessage: String = ""
    @State private var localToastIcon: String? = nil
    
    // 全文搜索、行号跳转、工程元数据洞察、实时追尾监听与 SVG 双模预览状态
    @StateObject private var findBarState = FindBarState()
    @StateObject private var goToLineState = GoToLineState()
    @StateObject private var telemetryState = TelemetryInspectorState()
    @StateObject private var liveWatchingState = LiveWatchingState()
    @State private var isSVGSourceMode: Bool = false
    @State private var isCSVSourceMode: Bool = false
    @State private var isShareCardPresented: Bool
    @State private var isDirectShareCardMode: Bool
    
    // 状态化分段文件读取器
    @State private var chunkReader: FileChunkReader? = nil
    @State private var markdownPreviewTimeline: MarkdownPreviewTimelineTracker? = nil
    @State private var markdownHasLoadedInitialContent: Bool = false
    @State private var previewReadinessState = PreviewReadinessGate.resetState(for: nil)
    @State private var markdownBootstrapReady: Bool = false
    @State private var loadCoordinator = PreviewContentLoadCoordinator()
    @State private var inflightLoadPath: String? = nil

    // NOTE: 不在 ContentView 根节点订阅 Settings.shared，
    //       避免任意设置变化触发整个视图树 invalidate + CodeView.updateNSView 冒餐调用。
    //       fontSize / editorFont 只在 previewView 子节点内读取，训练范围最小化。

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
        let initialDirectCard = session.state.initialShareCardMode
        _isShareCardPresented = State(initialValue: initialDirectCard)
        _isDirectShareCardMode = State(initialValue: initialDirectCard)
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

    private var activeErrorMessage: String? {
        displayState.errorMessage
    }

    private var isExpanded: Bool {
        displayState.isExpanded
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

    var body: some View {
        ZStack {
            if isShareCardPresented {
                CodeCardExportModalView(
                    title: activeDisplayName ?? (activePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Snippet"),
                    code: content,
                    language: activeLanguage,
                    initialMode: (activeRenderType == .markdown || activeRenderType == .plainText) ? .quote : .code,
                    onDismiss: {
                        if isDirectShareCardMode {
                            windowActions.closeOverlay()
                        } else {
                            isShareCardPresented = false
                        }
                    },
                    onShowToast: { msg, icon in
                        localToastMessage = msg
                        localToastIcon = icon
                        showLocalToast = true
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(100)
            } else {
                VStack(spacing: 0) {
                    // 工具栏
                    PreviewHeaderView(
                        activePath: activePath,
                        activeDisplayName: activeDisplayName,
                        activeRenderType: activeRenderType,
                        activeErrorMessage: activeErrorMessage,
                        isExpanded: isExpanded,
                        onClose: { windowActions.closeOverlay() },
                        onToggleExpanded: { session.toggleExpanded() },
                        findBarState: findBarState,
                        isSVGSourceMode: $isSVGSourceMode,
                        svgContent: content,
                        onShowToast: { msg, icon in
                            localToastMessage = msg
                            localToastIcon = icon
                            showLocalToast = true
                        },
                        isCSVSourceMode: $isCSVSourceMode,
                        isExportingPDF: isExportingPDF,
                        onExportPDF: exportMarkdownToPDF,
                        onShareCard: {
                            isDirectShareCardMode = false
                            isShareCardPresented = true
                        },
                        liveWatchingState: liveWatchingState,
                        canGoBack: historyNavigator.canGoBack,
                        canGoForward: historyNavigator.canGoForward,
                        onGoBack: {
                            if let path = historyNavigator.goBack() {
                                historyNavigator.performInternalNavigation {
                                    windowActions.openPath?(path, .internalNavigation)
                                }
                            }
                        },
                        onGoForward: {
                            if let path = historyNavigator.goForward() {
                                historyNavigator.performInternalNavigation {
                                    windowActions.openPath?(path, .internalNavigation)
                                }
                            }
                        }
                    )
                    .zIndex(1) // 锁定层级，确保工具栏处于最前，防止 MarkdownView 的 ScrollView 穿透遮挡

                    // 内容区域
                    PreviewContentContainer(
                        activeRenderType: activeRenderType,
                        isSVGSourceMode: isSVGSourceMode,
                        findBarState: findBarState,
                        goToLineState: goToLineState,
                        telemetryState: telemetryState,
                        loadState: loadState,
                        shouldShowLoadingOverlay: shouldShowLoadingOverlay,
                        isLocatingSelection: isLocatingSelection
                    ) {
                        mainContent
                    }
                    .zIndex(0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .top)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                )
                .clipShape(RoundedRectangle(cornerRadius: PreviewCardChromePolicy.cornerRadius, style: .continuous))
                .overlay {
                    cardChromeBorder
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isShareCardPresented)
        .padding(isShareCardPresented ? 0 : cardOuterPadding)
        .background(Color.clear) // 根容器背景必须是透明 clear，保持留白边缘穿透
        .toast(isShowing: $showLocalToast, message: localToastMessage, icon: localToastIcon)
        .onChange(of: isShareCardPresented) { isPresented in
            if let window = windowActions.currentWindow() {
                window.hasShadow = !isPresented && PreviewOverlayWindowChromePolicy.usesSystemWindowShadow
                window.invalidateShadow()
            }
        }
        .onAppear {
            if isShareCardPresented, let window = windowActions.currentWindow() {
                window.hasShadow = false
                window.invalidateShadow()
            }
        }
        .onDisappear {
            if let window = windowActions.currentWindow() {
                window.hasShadow = PreviewOverlayWindowChromePolicy.usesSystemWindowShadow
                window.invalidateShadow()
            }
            findBarState.dismiss()
            isSVGSourceMode = false
            isCSVSourceMode = false
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
            findBarState.dismiss()
            isSVGSourceMode = false
            isCSVSourceMode = false
            if let path = newPath {
                prepareForIncomingPath(path)
                telemetryState.reloadIfPresented(path: path, renderType: activeRenderType ?? .plainText, content: content)
                Task {
                    await triggerPathLoadIfNeeded(path: path)
                }
            } else {
                liveWatchingState.stop()
                telemetryState.dismiss()
                loadCoordinator.reset()
                inflightLoadPath = nil
                chunkReader?.close()
                chunkReader = nil
                content = ""
                loadedContentPath = nil
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
        .onChange(of: goToLineState.isPresented) { isPresented in
            windowActions.onSearchStateChanged?(isPresented || findBarState.isPresented)
            if isPresented && findBarState.isPresented {
                findBarState.dismiss()
            }
        }
        .onChange(of: findBarState.isPresented) { isPresented in
            windowActions.onSearchStateChanged?(isPresented || goToLineState.isPresented)
            if isPresented {
                if goToLineState.isPresented {
                    goToLineState.dismiss()
                }
                triggerFullLoadForSearchIfNeeded()
            }
        }
        .onChange(of: findBarState.query) { newQuery in
            if !newQuery.isEmpty && findBarState.isPresented {
                triggerFullLoadForSearchIfNeeded()
            }
        }
        .onReceive(windowActions.triggerSearchSubject ?? PassthroughSubject<Void, Never>()) {
            withAnimation(.easeInOut(duration: 0.15)) {
                if goToLineState.isPresented {
                    goToLineState.dismiss()
                }
                if !findBarState.isPresented {
                    findBarState.present()
                }
            }
        }
        .onReceive(windowActions.triggerGoToLineSubject ?? PassthroughSubject<Void, Never>()) {
            withAnimation(.easeInOut(duration: 0.15)) {
                if findBarState.isPresented {
                    findBarState.dismiss()
                }
                if !goToLineState.isPresented {
                    goToLineState.present(totalLines: goToLineState.totalLines)
                }
            }
        }
        .onReceive(windowActions.triggerTelemetrySubject ?? PassthroughSubject<Void, Never>()) {
            if let path = activePath, let renderType = activeRenderType {
                telemetryState.toggle(path: path, renderType: renderType, content: content)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .previewPresentShareCardDirectly)) { _ in
            withAnimation(.easeInOut(duration: 0.18)) {
                isDirectShareCardMode = true
                isShareCardPresented = true
            }
        }
        .onReceive(liveWatchingState.fileModifiedSubject) {
            guard let path = activePath else { return }
            Task {
                _ = await loadFileAsync(path: path)
            }
        }
        .onReceive(liveWatchingState.logAppendedSubject) { appendedText in
            guard !appendedText.isEmpty else { return }
            self.content += appendedText
        }
        .onReceive(liveWatchingState.logTruncatedSubject) {
            guard let path = activePath else { return }
            self.content = ""
            Task {
                _ = await loadFileAsync(path: path)
            }
        }
    }

    private var cardChromeBorder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: PreviewCardChromePolicy.cornerRadius, style: .continuous)
                .stroke(cardBorderGradient, lineWidth: PreviewCardChromePolicy.borderLineWidth)

            if PreviewCardChromePolicy.innerHighlightLineWidth > 0 {
                RoundedRectangle(cornerRadius: PreviewCardChromePolicy.cornerRadius, style: .continuous)
                    .inset(by: PreviewCardChromePolicy.borderLineWidth)
                    .stroke(cardInnerHighlightGradient, lineWidth: PreviewCardChromePolicy.innerHighlightLineWidth)
            }
        }
    }

    private var cardBorderGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(PreviewCardChromePolicy.darkBorderOpacity),
                    Color.white.opacity(PreviewCardChromePolicy.darkBorderOpacity * 0.4)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.65),
                    PreviewCardChromePolicy.lightBorderColor
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var cardInnerHighlightGradient: LinearGradient {
        let topOpacity = colorScheme == .dark
            ? PreviewCardChromePolicy.darkInnerHighlightOpacity
            : PreviewCardChromePolicy.lightInnerHighlightOpacity
        return LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(topOpacity),
                Color.clear
            ]),
            startPoint: .top,
            endPoint: .center
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        if activePath == nil {
            PreviewReadyStateView(
                errorMessage: activeErrorMessage,
                onInspectClipboard: {
                    AppDelegate.shared?.inspectClipboard()
                }
            )
            .transition(.opacity)
        } else if activeRenderType == .unsupported {
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
                if shouldRenderPreviewView {
                    previewView
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
                    },
                    findBarState: findBarState
                )
            case .code:
                if StructuredDataCategoryRegistry.isStructuredData(path: path) {
                    let ext = (path as NSString).pathExtension.lowercased()
                    StructuredDataView(
                        path: path,
                        content: content,
                        language: activeLanguage ?? ext,
                        isDark: isDark,
                        loadState: loadState,
                        onLoadMore: {
                            Task { await loadNextChunkAsync(for: path) }
                        },
                        findBarState: findBarState
                    )
                } else {
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
                        },
                        findBarState: findBarState,
                        goToLineState: goToLineState,
                        liveWatchingState: liveWatchingState,
                        initialTargetLine: session.state.initialTargetLine,
                        onInitialTargetLineConsumed: {
                            session.clearInitialTargetLine()
                        }
                    )
                }
            case .plainText:
                PreviewCodeView(
                    path: path,
                    content: content,
                    language: nil,
                    isDark: isDark,
                    loadState: loadState,
                    onLoadMore: {
                        Task { await loadNextChunkAsync(for: path) }
                    },
                    findBarState: findBarState,
                    goToLineState: goToLineState,
                    liveWatchingState: liveWatchingState,
                    initialTargetLine: session.state.initialTargetLine,
                    onInitialTargetLineConsumed: {
                        session.clearInitialTargetLine()
                    }
                )
            case .image:
                let isSVG = path.lowercased().hasSuffix(".svg")
                if isSVG && isSVGSourceMode {
                    PreviewCodeView(
                        path: path,
                        content: content,
                        language: "xml",
                        isDark: isDark,
                        loadState: loadState,
                        onLoadMore: {
                            Task { await loadNextChunkAsync(for: path) }
                        },
                        findBarState: findBarState,
                        goToLineState: goToLineState,
                        liveWatchingState: liveWatchingState,
                        initialTargetLine: session.state.initialTargetLine,
                        onInitialTargetLineConsumed: {
                            session.clearInitialTargetLine()
                        }
                    )
                } else {
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
                }
            case .pdf:
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
            case .archive, .folder:
                ArchivePreviewView(
                    archivePath: path,
                    onClose: {
                        windowActions.closeOverlay()
                    },
                    onShowToast: { message, icon in
                        windowActions.showToast(message, icon)
                    }
                )
                .id(path)
            case .audio:
                AudioPreviewView(filePath: path)
            case .video:
                VideoPreviewView(filePath: path)
            case .font:
                FontPreviewView(filePath: path)
            case .hex:
                HexPreviewView(path: path, isDark: isDark) { message, icon in
                    localToastMessage = message
                    localToastIcon = icon
                    showLocalToast = true
                }
            case .csv:
                if isCSVSourceMode {
                    PreviewCodeView(
                        path: path,
                        content: content,
                        language: "csv",
                        isDark: isDark,
                        loadState: loadState,
                        onLoadMore: {
                            Task { await loadNextChunkAsync(for: path) }
                        },
                        findBarState: findBarState,
                        goToLineState: goToLineState,
                        liveWatchingState: liveWatchingState,
                        initialTargetLine: session.state.initialTargetLine,
                        onInitialTargetLineConsumed: {
                            session.clearInitialTargetLine()
                        }
                    )
                } else {
                    CSVGridView(rawText: content) { message, icon in
                        localToastMessage = message
                        localToastIcon = icon
                        showLocalToast = true
                    }
                }
            case .unsupported:
                UnsupportedFileView(filePath: path, errorMessage: activeErrorMessage) { message, icon in
                    localToastMessage = message
                    localToastIcon = icon
                    showLocalToast = true
                }
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

    /// 后台并发异步读取首段，保证窗口 0ms 秒开起跳弹出
    private func loadFileAsync(path: String) async -> Bool {
        let request = await MainActor.run { () -> PreviewContentLoadRequest in
            let previousPath = loadCoordinator.activeRequest?.path
            let isReloadingSamePath = previousPath == path
            let request = loadCoordinator.beginLoad(path: path)
            chunkReader?.close()
            chunkReader = nil
            if !isReloadingSamePath {
                content = ""
            }
            loadState.hasMoreChunks = false
            loadState.isIncrementalLoading = false
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

        if !PreviewProviderRegistry.usesTextContentLoader(for: activeRenderType, path: path) {
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
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64) ?? UInt64(payload.1.utf8.count)
                    if self.liveWatchingState.activePath != path {
                        self.liveWatchingState.start(for: path, initialFileSize: fileSize)
                    } else {
                        self.liveWatchingState.syncOffset(fileSize)
                    }
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
                self.liveWatchingState.syncOffset(reader.currentOffset)
            case .failure(let error):
                let runtimeErrorMessage = (error.errorDescription ?? "载入后续文本失败").localized()
                self.loadState.isIncrementalLoading = false
                windowActions.showToast(runtimeErrorMessage, "xmark.circle")
            }
        }
    }

    /// 当用户呼出搜索框或在搜索框输入关键词时，如果当前文件还有剩余未加载分块，
    /// 自动在后台快速连续读取剩余所有分块，实现 100% 全文覆盖检索
    private func triggerFullLoadForSearchIfNeeded() {
        guard let path = activePath,
              loadState.hasMoreChunks,
              !loadState.isIncrementalLoading else { return }
        Task {
            await loadAllRemainingChunksForSearchAsync(for: path)
        }
    }

    /// 在大文本搜索时，一次性将剩余所有分段快速读取完毕，使得搜索能 100% 覆盖整个大文件
    @MainActor
    private func loadAllRemainingChunksForSearchAsync(for requestPath: String) async {
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

        let result = await Task.detached(priority: .userInitiated) { () -> Result<String, FileUtils.FileError> in
            var accumulated = ""
            var hasMore = true
            while hasMore {
                let res = reader.readNextChunk(limitBytes: Constants.chunkSize * 2)
                switch res {
                case .success(let payload):
                    accumulated += payload.content
                    hasMore = payload.hasMore
                case .failure(let error):
                    return .failure(error)
                }
            }
            return .success(accumulated)
        }.value

        guard PreviewIncrementalContentLoadPolicy.shouldApplyChunk(
            request: request,
            activeRequest: loadCoordinator.activeRequest,
            activePath: activePath,
            loadedContentPath: loadedContentPath
        ) else {
            loadState.isIncrementalLoading = false
            return
        }

        switch result {
        case .success(let remainingContent):
            self.content += remainingContent
            self.loadState.hasMoreChunks = false
            self.loadState.isIncrementalLoading = false
            self.liveWatchingState.syncOffset(reader.currentOffset)
        case .failure:
            self.loadState.isIncrementalLoading = false
        }
    }

    @MainActor
    private func triggerPathLoadIfNeeded(path: String) async {
        guard inflightLoadPath != path else { return }

        inflightLoadPath = path
        prepareForIncomingPath(path)
        isLoading = true
        resetHeavyPreviewState(for: activeRenderType)
        markdownBootstrapReady = false

        _ = await loadFileAsync(path: path)

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
        findBarState.dismiss()
        isSVGSourceMode = false
        isCSVSourceMode = false
    }

    private func resetHeavyPreviewState(for renderType: FileRenderType?) {
        previewReadinessState = PreviewReadinessGate.resetState(for: renderType)
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
        guard activeRenderType == .markdown, activePath != nil else { return false }
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
              PreviewProviderRegistry.allowsPDFExport(for: activeRenderType) else { return }
        
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
struct PreviewCodeView: View {
    let path: String
    let content: String
    let language: String?
    let isDark: Bool
    let loadState: PreviewLoadState
    let onLoadMore: () -> Void
    var findBarState: FindBarState? = nil
    var goToLineState: GoToLineState? = nil
    var liveWatchingState: LiveWatchingState? = nil
    var initialTargetLine: Int? = nil
    var onInitialTargetLineConsumed: (() -> Void)? = nil

    // NOTE: 恢复 @ObservedObject 绑定，以实现设置修改时文本字号与字体的实时热联动
    @ObservedObject private var settings = Settings.shared

    init(
        path: String,
        content: String,
        language: String?,
        isDark: Bool,
        loadState: PreviewLoadState,
        onLoadMore: @escaping () -> Void,
        findBarState: FindBarState? = nil,
        goToLineState: GoToLineState? = nil,
        liveWatchingState: LiveWatchingState? = nil,
        initialTargetLine: Int? = nil,
        onInitialTargetLineConsumed: (() -> Void)? = nil
    ) {
        self.path = path
        self.content = content
        self.language = language
        self.isDark = isDark
        self.loadState = loadState
        self.onLoadMore = onLoadMore
        self.findBarState = findBarState
        self.goToLineState = goToLineState
        self.liveWatchingState = liveWatchingState
        self.initialTargetLine = initialTargetLine
        self.onInitialTargetLineConsumed = onInitialTargetLineConsumed
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
            onLoadMore: onLoadMore,
            findBarState: findBarState,
            goToLineState: goToLineState,
            liveWatchingState: liveWatchingState,
            initialTargetLine: initialTargetLine,
            onInitialTargetLineConsumed: onInitialTargetLineConsumed
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
