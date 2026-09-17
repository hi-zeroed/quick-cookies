import SwiftUI
import AppKit

/// 十六进制探查视图（支持等宽排版、列对齐、分块加载与高对比度渲染）
public struct HexPreviewView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var settings = Settings.shared

    let path: String
    let isDark: Bool
    var onShowToast: ((String, String?) -> Void)? = nil

    @State private var rows: [HexRow] = []
    @State private var totalFileSize: UInt64 = 0
    @State private var loadedByteCount: Int = 0
    @State private var hasMore: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var selectedRowOffset: UInt64? = nil
    @State private var copyToast: String? = nil

    public init(
        path: String,
        isDark: Bool,
        onShowToast: ((String, String?) -> Void)? = nil
    ) {
        self.path = path
        self.isDark = isDark
        self.onShowToast = onShowToast
    }

    private var currentFont: Font {
        Font(NSFont.editorFont(name: settings.editorFont, size: CGFloat(settings.fontSize)))
    }

    private var headerFont: Font {
        Font(NSFont.editorFont(name: settings.editorFont, size: max(10, CGFloat(settings.fontSize - 2))))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 表头列标尺
            columnHeaderView
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.appText.opacity(colorScheme == .dark ? 0.04 : 0.03))

            Divider()
                .opacity(colorScheme == .dark ? 0.15 : 0.08)

            // MARK: - 主数据虚拟滚动区
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(rows) { row in
                        hexRowView(row: row)
                            .onTapGesture {
                                selectedRowOffset = row.offset
                            }
                            .contextMenu {
                                Button("Copy Hex String".localized()) {
                                    copyToClipboard(row.hexPart1 + (row.hexPart2.isEmpty ? "" : " " + row.hexPart2))
                                }
                                Button("Copy Decoded Text".localized()) {
                                    copyToClipboard(row.asciiDump)
                                }
                                Button("Copy Full Row".localized()) {
                                    let full = "\(row.offsetString): \(row.hexPart1)  \(row.hexPart2)  |\(row.asciiDump)|"
                                    copyToClipboard(full)
                                }
                            }
                    }

                    // 加载更多指示器
                    if hasMore {
                        HStack {
                            Spacer()
                            Button(action: loadNextChunk) {
                                HStack(spacing: 6) {
                                    if isLoadingMore {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text("Load More Bytes".localized())
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(Color.appText.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.appText.opacity(colorScheme == .dark ? 0.08 : 0.05))
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoadingMore)
                            .padding(.vertical, 10)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()
                .opacity(colorScheme == .dark ? 0.15 : 0.08)

            // MARK: - 底部状态栏
            bottomStatusBar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appText.opacity(colorScheme == .dark ? 0.03 : 0.02))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .onAppear {
            loadInitialChunk()
        }
    }

    // MARK: - 表头
    private var columnHeaderView: some View {
        HStack(spacing: 18) {
            Text("OFFSET".localized())
                .frame(width: 82, alignment: .leading)

            Text("00 01 02 03 04 05 06 07   08 09 0A 0B 0C 0D 0E 0F")
                .frame(width: 375, alignment: .leading)

            Text("DECODED TEXT".localized())
                .frame(width: 140, alignment: .leading)

            Spacer()
        }
        .font(headerFont.weight(.semibold))
        .foregroundColor(Color.appText.opacity(0.45))
    }

    // MARK: - 单行渲染
    private func hexRowView(row: HexRow) -> some View {
        let isSelected = selectedRowOffset == row.offset

        return HStack(spacing: 18) {
            // 物理偏移量
            Text(row.offsetString)
                .foregroundColor(Color.accentColor.opacity(0.85))
                .frame(width: 82, alignment: .leading)

            // 十六进制数据（左右两段）
            HStack(spacing: 12) {
                Text(row.hexPart1)
                    .frame(width: 180, alignment: .leading)

                Text(row.hexPart2)
                    .frame(width: 180, alignment: .leading)
            }
            .foregroundColor(Color.appText.opacity(0.9))

            // ASCII 解码字符串
            Text(row.asciiDump)
                .foregroundColor(Color.appText.opacity(0.75))
                .frame(width: 140, alignment: .leading)

            Spacer()
        }
        .font(currentFont)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        )
    }

    // MARK: - 底部状态栏
    private var bottomStatusBar: some View {
        HStack {
            let loadedSize = ByteCountFormatter.string(fromByteCount: Int64(loadedByteCount), countStyle: .file)
            let totalSize = ByteCountFormatter.string(fromByteCount: Int64(totalFileSize), countStyle: .file)

            Text("\(loadedSize) / \(totalSize)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.appText.opacity(0.6))

            Spacer()

            if let selected = selectedRowOffset {
                Text("Selected: 0x\(String(format: "%08X", selected))".localized())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.appText.opacity(0.75))
            }
        }
    }

    // MARK: - 数据加载
    private func loadInitialChunk() {
        guard let result = HexInspectorEngine.inspectFile(at: path, offset: 0, limit: HexInspectorEngine.defaultChunkSize) else {
            return
        }

        self.rows = result.rows
        self.totalFileSize = result.totalFileSize
        self.loadedByteCount = result.loadedByteCount
        self.hasMore = result.hasMore
    }

    private func loadNextChunk() {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true

        let nextOffset = UInt64(loadedByteCount)
        DispatchQueue.global(qos: .userInitiated).async {
            let result = HexInspectorEngine.inspectFile(at: self.path, offset: nextOffset, limit: HexInspectorEngine.defaultChunkSize)
            DispatchQueue.main.async {
                self.isLoadingMore = false
                guard let result = result else { return }

                self.rows.append(contentsOf: result.rows)
                self.loadedByteCount += result.loadedByteCount
                self.hasMore = result.hasMore
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        onShowToast?("Copied to clipboard".localized(), "doc.on.doc")
    }
}
