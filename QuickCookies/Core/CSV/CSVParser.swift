//
//  CSVParser.swift
//  QuickCookies
//
//  Created by Antigravity on 2026-09-17.
//

import Foundation

/// CSV / TSV 解析结果数据模型
public struct CSVDataSet: Equatable, Sendable {
    /// 表头列名
    public let headers: [String]
    /// 数据行矩阵（每行长度严格与 headers 对齐）
    public let rows: [[String]]
    /// 原始数据总行数（不含表头）
    public let totalRows: Int
    /// 总列数
    public let totalColumns: Int
    /// 实际使用的分隔符（逗号或制表符）
    public let delimiter: Character
    /// 是否发生了大文件行数截断
    public let isTruncated: Bool
    /// 每列建议显示的宽度（像素点）
    public let columnWidths: [CGFloat]

    public init(
        headers: [String],
        rows: [[String]],
        totalRows: Int,
        totalColumns: Int,
        delimiter: Character,
        isTruncated: Bool,
        columnWidths: [CGFloat]
    ) {
        self.headers = headers
        self.rows = rows
        self.totalRows = totalRows
        self.totalColumns = totalColumns
        self.delimiter = delimiter
        self.isTruncated = isTruncated
        self.columnWidths = columnWidths
    }

    /// 空白默认数据集
    public static var empty: CSVDataSet {
        CSVDataSet(
            headers: [],
            rows: [],
            totalRows: 0,
            totalColumns: 0,
            delimiter: ",",
            isTruncated: false,
            columnWidths: []
        )
    }
}

/// 排序方向
public enum CSVSortDirection: Equatable, Sendable {
    case ascending
    case descending
}

/// 排序状态
public struct CSVSortState: Equatable, Sendable {
    public var columnIndex: Int?
    public var direction: CSVSortDirection

    public init(columnIndex: Int? = nil, direction: CSVSortDirection = .ascending) {
        self.columnIndex = columnIndex
        self.direction = direction
    }

    public mutating func toggle(for columnIndex: Int) {
        if self.columnIndex == columnIndex {
            if direction == .ascending {
                direction = .descending
            } else {
                self.columnIndex = nil
                direction = .ascending
            }
        } else {
            self.columnIndex = columnIndex
            direction = .ascending
        }
    }
}

/// 纯 Swift RFC 4180 兼容的流式 CSV/TSV 解析引擎
public enum CSVParser {
    /// 默认最大解析行数保护（防止超大几百兆 CSV 造成 UI 渲染假死）
    public static let defaultMaxRows: Int = 5000

    /// 从字符串解析 CSV/TSV
    /// - Parameters:
    ///   - text: 原始内容文本
    ///   - delimiterHint: 显式指定分隔符（若为 nil 则自动嗅探）
    ///   - maxRows: 最大行数限制
    /// - Returns: 解析后的 CSVDataSet
    public static func parse(
        text: String,
        delimiterHint: Character? = nil,
        maxRows: Int = defaultMaxRows
    ) -> CSVDataSet {
        guard !text.isEmpty else {
            return .empty
        }

        let delimiter = delimiterHint ?? sniffDelimiter(text: text)
        var rawRows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var isTruncated = false

        let chars = Array(text)
        let totalLen = chars.count
        var index = 0

        while index < totalLen {
            let char = chars[index]

            if inQuotes {
                if char == "\"" {
                    // 检查是否为双重转义引号 `""`
                    if index + 1 < totalLen && chars[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 2
                        continue
                    } else {
                        // 引号字段闭合
                        inQuotes = false
                        index += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    index += 1
                    continue
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                    index += 1
                    continue
                } else if char == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                    index += 1
                    continue
                } else if char == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    rawRows.append(currentRow)
                    currentRow = []

                    // 步进跳过随后的 `\n`
                    if index + 1 < totalLen && chars[index + 1] == "\n" {
                        index += 2
                    } else {
                        index += 1
                    }

                    if rawRows.count > maxRows {
                        isTruncated = true
                        break
                    }
                    continue
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rawRows.append(currentRow)
                    currentRow = []
                    index += 1

                    if rawRows.count > maxRows {
                        isTruncated = true
                        break
                    }
                    continue
                } else {
                    currentField.append(char)
                    index += 1
                    continue
                }
            }
        }

        // 处理文件末尾未闭合的字段和行
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rawRows.append(currentRow)
        }

        // 过滤末尾纯空白行
        while let last = rawRows.last, last.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rawRows.removeLast()
        }

        guard !rawRows.isEmpty else {
            return .empty
        }

        // 首行作为表头提取
        var headers = rawRows[0]
        var dataRows = Array(rawRows.dropFirst())

        // 计算最大列数
        let dataMaxCols = dataRows.map { $0.count }.max() ?? 0
        let totalCols = max(headers.count, dataMaxCols)

        // 补齐表头
        if headers.count < totalCols {
            for i in headers.count..<totalCols {
                headers.append(columnLetter(for: i))
            }
        }

        // 补齐数据行单元格
        for r in 0..<dataRows.count {
            if dataRows[r].count < totalCols {
                dataRows[r].append(contentsOf: Array(repeating: "", count: totalCols - dataRows[r].count))
            }
        }

        // 计算建议列宽
        let widths = calculateColumnWidths(headers: headers, rows: dataRows)

        return CSVDataSet(
            headers: headers,
            rows: dataRows,
            totalRows: dataRows.count,
            totalColumns: totalCols,
            delimiter: delimiter,
            isTruncated: isTruncated,
            columnWidths: widths
        )
    }

    /// 对数据行按指定列进行智能自然数与文本排序
    public static func sort(
        rows: [[String]],
        by columnIndex: Int,
        direction: CSVSortDirection
    ) -> [[String]] {
        guard columnIndex >= 0 else { return rows }

        return rows.sorted { rowA, rowB in
            let valA = columnIndex < rowA.count ? rowA[columnIndex].trimmingCharacters(in: .whitespaces) : ""
            let valB = columnIndex < rowB.count ? rowB[columnIndex].trimmingCharacters(in: .whitespaces) : ""

            // 尝试转数值比较
            if let numA = Double(valA), let numB = Double(valB) {
                return direction == .ascending ? numA < numB : numA > numB
            }

            // 文本智能自然字母比对（如 file2 优先于 file10）
            let comparison = valA.localizedStandardCompare(valB)
            return direction == .ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }

    /// 自动嗅探分隔符（逗号 vs 制表符）
    public static func sniffDelimiter(text: String) -> Character {
        // 读取首行或前 1024 个字符进行投票
        let firstChunk = text.prefix(1024)
        var commaCount = 0
        var tabCount = 0
        var inQuotes = false

        for char in firstChunk {
            if char == "\"" {
                inQuotes.toggle()
            } else if !inQuotes {
                if char == "," {
                    commaCount += 1
                } else if char == "\t" {
                    tabCount += 1
                } else if char == "\n" || char == "\r" {
                    break
                }
            }
        }

        return tabCount > commaCount ? "\t" : ","
    }

    /// 启发式计算每列的自适应展示宽度
    public static func calculateColumnWidths(
        headers: [String],
        rows: [[String]],
        sampleLimit: Int = 100
    ) -> [CGFloat] {
        let minWidth: CGFloat = 72.0
        let maxWidth: CGFloat = 340.0
        let charWidth: CGFloat = 8.2
        let padding: CGFloat = 32.0

        var widths: [CGFloat] = []

        for colIndex in 0..<headers.count {
            var maxLen = headers[colIndex].count

            // 抽取前 sampleLimit 行采样计算
            let sampleRows = rows.prefix(sampleLimit)
            for row in sampleRows {
                if colIndex < row.count {
                    let len = row[colIndex].count
                    if len > maxLen {
                        maxLen = len
                    }
                }
            }

            let computed = CGFloat(maxLen) * charWidth + padding
            let clamped = max(minWidth, min(maxWidth, computed))
            widths.append(clamped)
        }

        return widths
    }

    /// 产生类似 Excel 的列名字母标尺（A, B, ..., Z, AA, AB...）
    public static func columnLetter(for index: Int) -> String {
        var result = ""
        var num = index
        while num >= 0 {
            let remainder = num % 26
            if let scalar = UnicodeScalar(65 + remainder) {
                result = String(Character(scalar)) + result
            }
            num = (num / 26) - 1
        }
        return result
    }
}
