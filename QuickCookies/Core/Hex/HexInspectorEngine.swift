import Foundation

/// 十六进制单行渲染模型（固定承载最多 16 字节）
public struct HexRow: Identifiable, Equatable {
    public var id: UInt64 { offset }
    public let offset: UInt64
    public let offsetString: String
    public let hexPart1: String // 前 8 字节十六进制（形如 "7F 45 4C 46 02 01 01 00"）
    public let hexPart2: String // 后 8 字节十六进制（形如 "00 00 00 00 00 00 00 00"）
    public let asciiDump: String // 对应 16 字符 ASCII 解码字符串（不可打印字符以 '.' 呈现）
    public let byteCount: Int

    public init(offset: UInt64, offsetString: String, hexPart1: String, hexPart2: String, asciiDump: String, byteCount: Int) {
        self.offset = offset
        self.offsetString = offsetString
        self.hexPart1 = hexPart1
        self.hexPart2 = hexPart2
        self.asciiDump = asciiDump
        self.byteCount = byteCount
    }
}

/// 十六进制探查结果模型
public struct HexInspectorResult: Equatable {
    public let rows: [HexRow]
    public let totalFileSize: UInt64
    public let loadedByteCount: Int
    public let hasMore: Bool

    public init(rows: [HexRow], totalFileSize: UInt64, loadedByteCount: Int, hasMore: Bool) {
        self.rows = rows
        self.totalFileSize = totalFileSize
        self.loadedByteCount = loadedByteCount
        self.hasMore = hasMore
    }
}

/// 纯 Swift 极速十六进制探查与字节格式化引擎
public enum HexInspectorEngine {
    /// 默认单次分块读取上限：64 KB（对应 4,096 行，秒开无任何感知卡顿）
    public static let defaultChunkSize: Int = 64 * 1024

    /// 将二进制 Data 格式化为等宽对齐的 HexRow 数组
    /// - Parameters:
    ///   - data: 待转换字节数据
    ///   - baseOffset: 起始物理偏移量
    /// - Returns: 格式化后的 HexRow 列表
    public static func formatData(_ data: Data, baseOffset: UInt64 = 0) -> [HexRow] {
        guard !data.isEmpty else { return [] }

        var rows: [HexRow] = []
        let totalBytes = data.count
        rows.reserveCapacity((totalBytes + 15) / 16)

        data.withUnsafeBytes { rawBuffer in
            guard let ptr = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }

            var index = 0
            while index < totalBytes {
                let currentOffset = baseOffset + UInt64(index)
                let remaining = totalBytes - index
                let chunkSize = min(16, remaining)

                let offsetStr = String(format: "%08X", currentOffset)

                // 拆分为左右两组（每组最多 8 字节）
                var hexPart1Components: [String] = []
                var hexPart2Components: [String] = []
                var asciiChars: [Character] = []

                for i in 0..<chunkSize {
                    let byte = ptr[index + i]
                    let hexStr = String(format: "%02X", byte)

                    if i < 8 {
                        hexPart1Components.append(hexStr)
                    } else {
                        hexPart2Components.append(hexStr)
                    }

                    // ASCII 可打印字符范围：0x20 (空格) ~ 0x7E (~)
                    if byte >= 0x20 && byte <= 0x7E {
                        asciiChars.append(Character(UnicodeScalar(byte)))
                    } else {
                        asciiChars.append(".")
                    }
                }

                let hexPart1 = hexPart1Components.joined(separator: " ")
                let hexPart2 = hexPart2Components.joined(separator: " ")
                let asciiDump = String(asciiChars)

                let row = HexRow(
                    offset: currentOffset,
                    offsetString: offsetStr,
                    hexPart1: hexPart1,
                    hexPart2: hexPart2,
                    asciiDump: asciiDump,
                    byteCount: chunkSize
                )
                rows.append(row)

                index += chunkSize
            }
        }

        return rows
    }

    /// 从指定物理路径分块读取并格式化为 HexInspectorResult
    /// - Parameters:
    ///   - path: 文件绝对路径
    ///   - offset: 起始字节偏移量
    ///   - limit: 最大读取字节数
    /// - Returns: 探查结果；若文件不存在或读取失败则返回 nil
    public static func inspectFile(at path: String, offset: UInt64 = 0, limit: Int = defaultChunkSize) -> HexInspectorResult? {
        let fileURL = URL(fileURLWithPath: path)

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? UInt64 else {
            return nil
        }

        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }

        defer {
            try? fileHandle.close()
        }

        do {
            try fileHandle.seek(toOffset: offset)
            let data: Data
            if #available(macOS 10.15, *) {
                data = (try fileHandle.read(upToCount: limit)) ?? Data()
            } else {
                data = fileHandle.readData(ofLength: limit)
            }

            let rows = formatData(data, baseOffset: offset)
            let loadedBytes = data.count
            let hasMore = (offset + UInt64(loadedBytes)) < fileSize

            return HexInspectorResult(
                rows: rows,
                totalFileSize: fileSize,
                loadedByteCount: loadedBytes,
                hasMore: hasMore
            )
        } catch {
            return nil
        }
    }
}
