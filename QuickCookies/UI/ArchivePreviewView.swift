import SwiftUI
import AppKit

struct ArchivePreviewView: View {
    let archivePath: String
    var onClose: (() -> Void)? = nil
    var onShowToast: ((String, String?) -> Void)? = nil

    @State private var summary: ArchiveSummary?
    @State private var rootNodes: [ArchiveTreeNode] = []
    @State private var visibleRows: [FlattenedArchiveRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedNodeId: String?
    @State private var hoveredNodeId: String?
    @State private var loadTask: Task<Void, Never>?

    private var isLocalFolder: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: archivePath, isDirectory: &isDir) && isDir.boolValue
    }

    private var rootFolderURL: URL {
        URL(fileURLWithPath: archivePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                // 1. 标准轻量表头栏（28pt 高度，20pt 边距）
                tableHeaderView

                insetDivider

                // 2. 舒展通透的一维扁平高性能树状列表（100% 虚拟化复用，120fps 丝滑滚动）
                if visibleRows.isEmpty {
                    emptyStateView
                } else {
                    treeContentView
                }

                // 3. 底部极简微光状态栏（28pt 高度，20pt 边距）
                if let summary = summary {
                    insetDivider

                    footerStatusBar(summary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .onAppear {
            loadArchiveContents()
        }
        .onChange(of: archivePath) { _ in
            loadArchiveContents()
        }
        .onDisappear {
            loadTask?.cancel()
        }
    }

    // MARK: - 精致内嵌分割线（20pt 边距，0.75pt 清晰 Retina 细线）

    private var insetDivider: some View {
        Rectangle()
            .fill(Color.appBorder.opacity(0.75))
            .frame(height: 0.75)
            .padding(.horizontal, 20)
    }

    // MARK: - 标准轻量表头栏

    private var tableHeaderView: some View {
        HStack(spacing: 0) {
            // 左侧：名称列标题（左对齐，预留箭头+缩进起始位）
            Text("Name".localized())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
                .padding(.leading, 32) // 与下方文件名图标起点完美对齐

            Spacer()

            // 右侧：大小列标题（右对齐）
            Text("Size".localized())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
        .background(Color.appBackground.opacity(0.65))
    }

    // MARK: - 高性能一维主内容区（LazyVStack 纯虚拟化）

    private var treeContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(visibleRows) { row in
                    ArchiveTreeRowView(
                        row: row,
                        rootURL: rootFolderURL,
                        isLocalFolder: isLocalFolder,
                        isSelected: selectedNodeId == row.id,
                        isHovered: hoveredNodeId == row.id,
                        onToggleExpand: {
                            toggleExpand(for: row.node)
                        },
                        onSelect: {
                            selectedNodeId = row.node.id
                        },
                        onHover: { isHover in
                            if isHover {
                                hoveredNodeId = row.id
                            } else if hoveredNodeId == row.id {
                                hoveredNodeId = nil
                            }
                        },
                        onClose: onClose,
                        onShowToast: onShowToast
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
    }

    // MARK: - 展开 / 折叠切换

    private func toggleExpand(for node: ArchiveTreeNode) {
        guard node.isDirectory else { return }
        node.isExpanded.toggle()
        refreshVisibleRows()
    }

    private func refreshVisibleRows() {
        self.visibleRows = ArchiveTreeBuilder.flattenVisibleNodes(from: rootNodes)
    }

    // MARK: - 底部极简微光状态栏

    private func footerSummaryText(_ summary: ArchiveSummary) -> String {
        var parts: [String] = []
        if summary.directoryCount > 0 {
            let countText = "\(summary.fileCount) " + "files".localized() + "，" + "\(summary.directoryCount) " + "folders".localized()
            parts.append(countText)
        } else {
            parts.append("\(summary.fileCount) " + "files".localized())
        }
        parts.append(summary.formattedUncompressedSize)
        if let ratio = summary.compressionRatioPercentage, ratio > 0 {
            let ratioText = String(format: "%@ %d%%".localized(), "Compression Ratio".localized(), ratio)
            parts.append(ratioText)
        }
        return parts.joined(separator: " · ")
    }

    private func footerStatusBar(_ summary: ArchiveSummary) -> some View {
        HStack(spacing: 8) {
            Text(footerSummaryText(summary))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(Color.appText.opacity(0.7))

            Spacer()

            // 格式小胶囊
            Text(summary.formatName)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.accentColor.opacity(0.9))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(5)
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
        .background(Color.appBackground.opacity(0.65))
    }

    // MARK: - 状态占位

    private var loadingText: String {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: archivePath, isDirectory: &isDir), isDir.boolValue {
            return "Scanning folder contents...".localized()
        } else {
            return "Analyzing archive contents...".localized()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
            Text(loadingText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundColor(.orange.opacity(0.8))
            Text(error)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.zipper")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.4))
            Text("Empty Archive".localized())
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
        }
    }

    // MARK: - 异步数据加载

    private func loadArchiveContents() {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            do {
                var resSummary: ArchiveSummary
                var resTree: [ArchiveTreeNode]

                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: archivePath, isDirectory: &isDir)

                if exists && isDir.boolValue {
                    (resSummary, _, resTree) = try await FolderReader.readFolder(at: archivePath)
                } else {
                    (resSummary, _, resTree) = try await ArchiveReader.readArchive(at: archivePath)
                }

                try Task.checkCancellation()

                await MainActor.run {
                    self.summary = resSummary
                    self.rootNodes = resTree
                    self.refreshVisibleRows()
                    self.isLoading = false
                }
            } catch is CancellationError {
                // 忽略被取消的任务
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - 轻量扁平行组件（无多余 State，完全受控，定高防抖，极速复用）

struct ArchiveTreeRowView: View {
    let row: FlattenedArchiveRow
    let rootURL: URL
    let isLocalFolder: Bool
    let isSelected: Bool
    let isHovered: Bool
    let onToggleExpand: () -> Void
    let onSelect: () -> Void
    let onHover: (Bool) -> Void
    let onClose: (() -> Void)?
    let onShowToast: ((String, String?) -> Void)?

    private var itemURL: URL? {
        guard isLocalFolder else { return nil }
        return rootURL.appendingPathComponent(row.node.fullPath)
    }

    var body: some View {
        HStack(spacing: 4) {
            // 层级缩进（16pt 阶梯）
            if row.depth > 0 {
                Spacer()
                    .frame(width: CGFloat(row.depth * 16))
            }

            // 文件夹展开折叠指示箭头（物理隔离，0 毫秒即时响应）
            if row.isDirectory {
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray.opacity(0.75))
                        .frame(width: 18, height: 22)
                        .contentShape(Rectangle())
                        .rotationEffect(.degrees(row.isExpanded ? 90 : 0))
                        .animation(.spring(response: 0.18, dampingFraction: 0.8), value: row.isExpanded)
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 18)
            }

            // 右侧主体区域（图标 + 名称 + 大小），独立处理选中与双击
            HStack(spacing: 6) {
                // 文件格式图标
                fileIcon(for: row.node)
                    .frame(width: 14)

                // 文件/目录名称
                Text(row.node.name)
                    .font(.system(size: 12.5, weight: row.isDirectory ? .medium : .regular, design: .monospaced))
                    .foregroundColor(Color.appText)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // 右侧指标：目录显示子项数与聚合大小；文件显示单文件大小
                if row.isDirectory {
                    HStack(spacing: 6) {
                        Text("\(row.node.children.count)")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.65))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())

                        Text(row.node.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                } else {
                    Text(row.node.formattedSize)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if let subURL = itemURL {
                    if row.isDirectory {
                        ExternalAppRelay.shared.revealInFinder(fileURL: subURL)
                    } else {
                        ExternalAppRelay.shared.openWithDefault(fileURL: subURL)
                    }
                    onClose?()
                }
            }
            .onTapGesture(count: 1) {
                onSelect()
            }
        }
        .frame(height: 26) // 恒定 26pt 行高，彻底杜绝任何抖动
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hover in
            onHover(hover)
        }
        .contextMenu {
            if let subURL = itemURL {
                Button(action: {
                    ExternalAppRelay.shared.revealInFinder(fileURL: subURL)
                    onClose?()
                }) {
                    Label("Reveal in Finder".localized(), systemImage: "folder")
                }

                if row.isDirectory {
                    Button(action: {
                        ExternalAppRelay.shared.openInTerminal(directoryURL: subURL)
                        onClose?()
                    }) {
                        Label("Open in Terminal".localized(), systemImage: "terminal")
                    }
                }

                Button(action: {
                    ExternalAppRelay.shared.openWithDefault(fileURL: subURL)
                    onClose?()
                }) {
                    Label("Open".localized(), systemImage: "arrow.up.forward.square")
                }

                Divider()

                Button(action: {
                    ExternalAppRelay.shared.copyPathToClipboard(fileURL: subURL)
                    onShowToast?("Path Copied".localized(), "doc.on.doc")
                }) {
                    Label("Copy Path".localized(), systemImage: "doc.on.doc")
                }

                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(row.node.fullPath, forType: .string)
                    onShowToast?("Path Copied".localized(), "text.quote")
                }) {
                    Label("Copy Relative Path".localized(), systemImage: "text.quote")
                }
            } else {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(row.node.fullPath, forType: .string)
                    onShowToast?("Path Copied".localized(), "doc.on.doc")
                }) {
                    Label("Copy Path".localized(), systemImage: "doc.on.doc")
                }
            }
        }
    }

    // MARK: - 文件类型多彩原生 SF Symbol 图标

    @ViewBuilder
    private func fileIcon(for node: ArchiveTreeNode) -> some View {
        if node.isDirectory {
            Image(systemName: node.isExpanded ? "folder.fill" : "folder")
                .foregroundColor(.blue.opacity(0.85))
                .font(.system(size: 12))
        } else {
            let ext = (node.name as NSString).pathExtension.lowercased()
            let cat = ArchiveCategory.category(for: ext)

            switch cat {
            case .code:
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundColor(.cyan.opacity(0.9))
                    .font(.system(size: 11))
            case .image:
                Image(systemName: "photo")
                    .foregroundColor(.purple.opacity(0.9))
                    .font(.system(size: 11.5))
            case .document:
                Image(systemName: "doc.text")
                    .foregroundColor(.blue.opacity(0.8))
                    .font(.system(size: 11.5))
            case .config:
                Image(systemName: "gearshape.2")
                    .foregroundColor(.yellow.opacity(0.9))
                    .font(.system(size: 11.5))
            case .other:
                Image(systemName: "doc")
                    .foregroundColor(.gray.opacity(0.7))
                    .font(.system(size: 11.5))
            }
        }
    }
}
