//
//  CSVGridView.swift
//  QuickCookies
//
//  Created by Antigravity on 2026-09-17.
//

import SwiftUI
import AppKit

/// 高性能虚拟化 CSV / TSV 数据网格组件
public struct CSVGridView: View {
    let rawText: String
    let onShowToast: (String, String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings = Settings.shared

    @State private var dataSet: CSVDataSet = .empty
    @State private var sortState = CSVSortState()
    @State private var sortedRows: [[String]] = []
    @State private var hoveredCell: (row: Int, col: Int)? = nil
    @State private var selectedCell: (row: Int, col: Int)? = nil

    public init(
        rawText: String,
        onShowToast: @escaping (String, String) -> Void
    ) {
        self.rawText = rawText
        self.onShowToast = onShowToast
    }

    private var effectiveFont: Font {
        Font(NSFont.editorFont(name: settings.editorFont, size: 12.0))
    }

    private var rowNumberFont: Font {
        Font(NSFont.editorFont(name: settings.editorFont, size: 10.5))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if dataSet.totalColumns == 0 {
                emptyView
            } else {
                tableContent
            }

            footerBar
        }
        .onAppear {
            loadData()
        }
        .onChange(of: rawText) { _ in
            loadData()
        }
    }

    // MARK: - 数据加载与排序

    private func loadData() {
        let parsed = CSVParser.parse(text: rawText)
        self.dataSet = parsed
        self.sortState = CSVSortState()
        self.sortedRows = parsed.rows
    }

    private func handleSort(at columnIndex: Int) {
        sortState.toggle(for: columnIndex)
        if let col = sortState.columnIndex {
            sortedRows = CSVParser.sort(rows: dataSet.rows, by: col, direction: sortState.direction)
        } else {
            sortedRows = dataSet.rows
        }
    }

    // MARK: - 表格主内容区

    private var tableContent: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // 表头行 (Sticky Header 风格)
                headerRow

                Divider()
                    .background(Color.appBorder.opacity(colorScheme == .dark ? 0.35 : 0.2))

                // 数据行虚拟列表
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<sortedRows.count, id: \.self) { rowIndex in
                        dataRowView(rowIndex: rowIndex)
                    }
                }
            }
        }
    }

    // MARK: - 表头视图

    private var headerRow: some View {
        HStack(spacing: 0) {
            // 行号角标标尺 (#)
            Text("#")
                .font(rowNumberFont)
                .foregroundColor(Color.appText.opacity(0.4))
                .frame(width: 44, height: 32)
                .background(headerBackground)
                .overlay(
                    Rectangle()
                        .frame(width: 0.5)
                        .foregroundColor(Color.appBorder.opacity(0.3)),
                    alignment: .trailing
                )

            // 各列名称与排序按钮
            ForEach(0..<dataSet.headers.count, id: \.self) { colIndex in
                let width = colIndex < dataSet.columnWidths.count ? dataSet.columnWidths[colIndex] : 100.0
                let headerTitle = dataSet.headers[colIndex]

                Button(action: {
                    handleSort(at: colIndex)
                }) {
                    HStack(spacing: 4) {
                        Text(headerTitle)
                            .font(effectiveFont.weight(.semibold))
                            .foregroundColor(Color.appText.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 0)

                        // 排序图标指示
                        if sortState.columnIndex == colIndex {
                            Image(systemName: sortState.direction == .ascending ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.accentColor)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(width: width, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(headerBackground)
                .overlay(
                    Rectangle()
                        .frame(width: 0.5)
                        .foregroundColor(Color.appBorder.opacity(0.3)),
                    alignment: .trailing
                )
                .contextMenu {
                    Button("Copy Column Header".localized()) {
                        copyToPasteboard(headerTitle, message: "Column name copied".localized())
                    }
                }
            }
        }
    }

    private var headerBackground: some View {
        colorScheme == .dark
            ? Color.black.opacity(0.45)
            : Color.white.opacity(0.65)
    }

    // MARK: - 数据单行视图

    private func dataRowView(rowIndex: Int) -> some View {
        let row = sortedRows[rowIndex]
        let isEven = rowIndex % 2 == 0
        let isRowSelected = selectedCell?.row == rowIndex

        return HStack(spacing: 0) {
            // 行号
            Text("\(rowIndex + 1)")
                .font(rowNumberFont)
                .foregroundColor(Color.appText.opacity(isRowSelected ? 0.8 : 0.35))
                .frame(width: 44, height: 28)
                .background(
                    isEven
                        ? Color.clear
                        : Color.appText.opacity(colorScheme == .dark ? 0.03 : 0.02)
                )
                .overlay(
                    Rectangle()
                        .frame(width: 0.5)
                        .foregroundColor(Color.appBorder.opacity(0.2)),
                    alignment: .trailing
                )

            // 各单元格
            ForEach(0..<dataSet.totalColumns, id: \.self) { colIndex in
                let cellValue = colIndex < row.count ? row[colIndex] : ""
                let width = colIndex < dataSet.columnWidths.count ? dataSet.columnWidths[colIndex] : 100.0
                let isHovered = hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex
                let isSelected = selectedCell?.row == rowIndex && selectedCell?.col == colIndex

                Text(cellValue)
                    .font(effectiveFont)
                    .foregroundColor(Color.appText.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 10)
                    .frame(width: width, height: 28, alignment: .leading)
                    .background(
                        cellBackground(isSelected: isSelected, isHovered: isHovered, isEven: isEven)
                    )
                    .overlay(
                        Rectangle()
                            .frame(width: 0.5)
                            .foregroundColor(Color.appBorder.opacity(0.18)),
                        alignment: .trailing
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            hoveredCell = (rowIndex, colIndex)
                        } else if hoveredCell?.row == rowIndex && hoveredCell?.col == colIndex {
                            hoveredCell = nil
                        }
                    }
                    .onTapGesture {
                        selectedCell = (rowIndex, colIndex)
                    }
                    .contextMenu {
                        Button("Copy Cell".localized()) {
                            copyToPasteboard(cellValue, message: "Cell copied".localized())
                        }
                        Button("Copy Row".localized()) {
                            let rowCSV = row.joined(separator: String(dataSet.delimiter))
                            copyToPasteboard(rowCSV, message: "Row copied".localized())
                        }
                        Button("Copy Table (TSV)".localized()) {
                            copyEntireTable()
                        }
                    }
            }
        }
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.appBorder.opacity(0.15)),
            alignment: .bottom
        )
    }

    private func cellBackground(isSelected: Bool, isHovered: Bool, isEven: Bool) -> some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.18)
            } else if isHovered {
                Color.appText.opacity(colorScheme == .dark ? 0.08 : 0.06)
            } else if !isEven {
                Color.appText.opacity(colorScheme == .dark ? 0.03 : 0.02)
            } else {
                Color.clear
            }
        }
    }

    // MARK: - 底部统计信息栏

    private var footerBar: some View {
        HStack(spacing: 8) {
            // 列数与行数胶囊
            HStack(spacing: 5) {
                Image(systemName: "tablecells")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.appText.opacity(0.55))

                Text(String(format: "%d columns · %d rows".localized(), dataSet.totalColumns, dataSet.totalRows))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appText.opacity(0.65))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.appText.opacity(colorScheme == .dark ? 0.08 : 0.05))
            )

            // 截断警告指示
            if dataSet.isTruncated {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)

                    Text(String(format: "Showing first %d rows".localized(), CSVParser.defaultMaxRows))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.orange.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                )
            }

            Spacer()

            // 拷贝整张表微按钮
            Button(action: {
                copyEntireTable()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .medium))
                    Text("Copy Table".localized())
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.appText.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.appText.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(Color.black.opacity(colorScheme == .dark ? 0.25 : 0.05))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.appBorder.opacity(0.25)),
                    alignment: .top
                )
        )
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 32))
                .foregroundColor(Color.appText.opacity(0.35))
            Text("Empty CSV / TSV File".localized())
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appText.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 剪贴板工具

    private func copyToPasteboard(_ string: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        onShowToast(message, "checkmark.circle.fill")
    }

    private func copyEntireTable() {
        var lines: [String] = []
        lines.append(dataSet.headers.joined(separator: "\t"))
        for row in sortedRows {
            lines.append(row.joined(separator: "\t"))
        }
        let tsvString = lines.joined(separator: "\n")
        copyToPasteboard(tsvString, message: "Entire table copied (TSV)".localized())
    }
}
