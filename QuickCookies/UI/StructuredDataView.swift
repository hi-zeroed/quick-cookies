import SwiftUI

enum StructuredDataDisplayMode: String, CaseIterable {
    case code
    case tree

    var displayName: String {
        switch self {
        case .code: return "Code".localized()
        case .tree: return "Tree".localized()
        }
    }

    var iconName: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .tree: return "list.bullet.indent"
        }
    }
}

struct StructuredDataView: View {
    let path: String
    let content: String
    let language: String
    let isDark: Bool
    let loadState: PreviewLoadState
    let onLoadMore: () -> Void
    var findBarState: FindBarState? = nil

    @State private var displayMode: StructuredDataDisplayMode = .code
    @State private var rootNode: StructuredDataNode?
    @State private var formattedContent: String = ""
    @State private var isParsed: Bool = false
    @State private var copyToastText: String?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 模式切换表头栏
            headerToolbar

            insetDivider

            // MARK: - 主视图区
            if displayMode == .tree, let root = rootNode {
                treeContentView(root: root)
            } else {
                codeContentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .onAppear {
            parseContent()
        }
        .onChange(of: content) {
            parseContent()
        }
    }

    // MARK: - 精致内嵌分割线（20pt 边距，0.75pt 清晰细线）

    private var insetDivider: some View {
        Rectangle()
            .fill(Color.appBorder.opacity(0.75))
            .frame(height: 0.75)
            .padding(.horizontal, 20)
    }

    // MARK: - 顶部工具栏

    private var headerToolbar: some View {
        HStack(spacing: 12) {
            Text("Structure".localized())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.appText.opacity(0.5))

            Spacer()

            if isParsed {
                HStack(spacing: 2) {
                    ForEach(StructuredDataDisplayMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                displayMode = mode
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode.iconName)
                                    .font(.system(size: 10))
                                Text(mode.displayName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                displayMode == mode
                                ? Color.primary.opacity(0.12)
                                : Color.clear
                            )
                            .cornerRadius(5)
                            .foregroundColor(
                                displayMode == mode
                                ? Color.appText
                                : Color.appText.opacity(0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(7)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 32)
        .background(Color.appBackground.opacity(0.65))
    }

    // MARK: - 结构树视图

    private func treeContentView(root: StructuredDataNode) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 如果根节点有子项，展示子项；否则展示根节点本身
                if !root.children.isEmpty {
                    ForEach(root.children) { child in
                        StructuredDataNodeRow(node: child, depth: 0)
                    }
                } else {
                    StructuredDataNodeRow(node: root, depth: 0)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
        }
    }

    // MARK: - 代码高亮视图

    private var codeContentView: some View {
        PreviewCodeView(
            path: path,
            content: formattedContent.isEmpty ? content : formattedContent,
            language: language,
            isDark: isDark,
            loadState: loadState,
            onLoadMore: onLoadMore,
            findBarState: findBarState
        )
    }

    // MARK: - 异步解析

    private func parseContent() {
        let ext = (path as NSString).pathExtension.lowercased()
        if let result = StructuredDataParser.parse(content: content, fileExtension: ext) {
            self.rootNode = result.root
            self.formattedContent = result.formattedText
            self.isParsed = true
        } else {
            self.isParsed = false
            self.displayMode = .code
        }
    }
}

// MARK: - 树节点行组件

struct StructuredDataNodeRow: View {
    @ObservedObject var node: StructuredDataNode
    let depth: Int
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // 缩进占位
                if depth > 0 {
                    Spacer()
                        .frame(width: CGFloat(depth * 16))
                }

                // 展开/折叠箭头
                if !node.children.isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.appText.opacity(0.5))
                        .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                node.isExpanded.toggle()
                            }
                        }
                } else {
                    Spacer().frame(width: 12)
                }

                // 键名 Key
                if let key = node.key {
                    Text(key)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color.accentColor.opacity(0.9))
                    Text(":")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.appText.opacity(0.4))
                }

                // 类型 Badge 胶囊
                badgeView(for: node.valueType)

                // 值 Value 展示
                valueView(for: node)

                Spacer(minLength: 8)

                // 悬停时的一键复制按钮
                if isHovered {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(node.rawValue, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appText.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Value".localized())
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5.5)
            .frame(height: 26)
            .background(
                isHovered
                ? Color.primary.opacity(0.04)
                : Color.clear
            )
            .cornerRadius(4)
            .onHover { hovering in
                isHovered = hovering
            }

            // 递归渲染子项
            if node.isExpanded && !node.children.isEmpty {
                ForEach(node.children) { child in
                    StructuredDataNodeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    @ViewBuilder
    private func badgeView(for type: StructuredDataValueType) -> some View {
        switch type {
        case .object, .array:
            Text(type.badgeText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(3)
                .foregroundColor(Color.appText.opacity(0.6))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func valueView(for node: StructuredDataNode) -> some View {
        switch node.valueType {
        case .object, .array:
            EmptyView()
        case .string:
            Text(node.displayValue)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.green.opacity(0.85))
                .lineLimit(1)
        case .number:
            Text(node.displayValue)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.purple.opacity(0.85))
                .lineLimit(1)
        case .boolean:
            Text(node.displayValue)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.blue.opacity(0.85))
                .lineLimit(1)
        case .null:
            Text(node.displayValue)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
                .lineLimit(1)
        }
    }
}
