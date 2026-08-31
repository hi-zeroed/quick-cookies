import SwiftUI
import AppKit

struct ArchivePreviewView: View {
    let archivePath: String

    @State private var summary: ArchiveSummary?
    @State private var rootNodes: [ArchiveTreeNode] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedNodeId: String?

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

                // 2. 舒展通透的层级树状主列表（26pt 标准行高，12pt 上下留白）
                if rootNodes.isEmpty {
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
            loadArchive()
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

    // MARK: - 树状主内容区

    private var treeContentView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 1) {
                ForEach(rootNodes) { node in
                    ArchiveTreeNodeRow(
                        node: node,
                        depth: 0,
                        selectedId: selectedNodeId,
                        onSelect: { selected in
                            selectedNodeId = selected.id
                        }
                    )
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
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
                .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .frame(height: 28)
        .background(Color.appBackground.opacity(0.45))
    }

    // MARK: - 状态占位

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
            Text("Analyzing archive contents...".localized())
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
                .foregroundColor(Color.appText.opacity(0.8))
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

    // MARK: - 数据加载

    private func loadArchive() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let (resSummary, _, resTree) = try await ArchiveReader.readArchive(at: archivePath)
                await MainActor.run {
                    self.summary = resSummary
                    self.rootNodes = resTree
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - 目录树行组件

struct ArchiveTreeNodeRow: View {
    @ObservedObject var node: ArchiveTreeNode
    let depth: Int
    let selectedId: String?
    let onSelect: (ArchiveTreeNode) -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        selectedId == node.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if node.isDirectory {
                    withAnimation(.easeInOut(duration: 0.14)) {
                        node.isExpanded.toggle()
                    }
                }
                onSelect(node)
            }) {
                HStack(spacing: 6) {
                    // 层级缩进（16pt 阶梯）
                    if depth > 0 {
                        Spacer()
                            .frame(width: CGFloat(depth * 16))
                    }

                    // 文件夹展开折叠指示箭头
                    if node.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray.opacity(0.7))
                            .frame(width: 12)
                            .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                    } else {
                        Spacer()
                            .frame(width: 12)
                    }

                    // 文件格式图标
                    fileIcon(for: node)
                        .frame(width: 14)

                    // 文件/目录名称
                    Text(node.name)
                        .font(.system(size: 12.5, weight: node.isDirectory ? .medium : .regular, design: .monospaced))
                        .foregroundColor(Color.appText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    // 右侧指标：目录显示子项数与聚合大小；文件显示单文件大小
                    if node.isDirectory {
                        HStack(spacing: 6) {
                            Text("\(node.children.count)")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.65))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())

                            Text(node.formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    } else {
                        Text(node.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                .padding(.vertical, 5.5)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : (isHovered ? Color.white.opacity(0.06) : Color.clear))
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }

            // 子节点递归展开
            if node.isDirectory && node.isExpanded {
                ForEach(node.children) { child in
                    ArchiveTreeNodeRow(
                        node: child,
                        depth: depth + 1,
                        selectedId: selectedId,
                        onSelect: onSelect
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func fileIcon(for node: ArchiveTreeNode) -> some View {
        if node.isDirectory {
            Image(systemName: node.isExpanded ? "folder.fill" : "folder")
                .font(.system(size: 13))
                .foregroundColor(Color.blue.opacity(0.85))
        } else {
            let cat = ArchiveCategory.category(for: node.fileExtension)
            switch cat {
            case .code:
                Image(systemName: "curlybraces")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            case .document:
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
            case .image:
                Image(systemName: "photo")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            case .config:
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            case .other:
                Image(systemName: "doc")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appText.opacity(0.6))
            }
        }
    }
}
