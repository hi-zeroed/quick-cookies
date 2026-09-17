import Foundation

/// 增量追加读取结果
enum LiveTailReadResult: Equatable {
    /// 成功读取到尾部新增文本
    case appended(text: String, newOffset: UInt64)
    /// 文件无新增数据
    case noChange
    /// 文件大小缩水（日志被清空、截断或轮转），需要重新全量重载
    case truncated(newSize: UInt64)
    /// 读取失败
    case failure(reason: String)
}

/// 日志文件实时追尾 (Tail -f) 增量读取引擎
///
/// 核心特性：
/// 1. 0 全量重读开销：基于 offset 精确切入文件尾部，只读取新增追加字节；
/// 2. 多字节安全解码：自动检测并回退末尾截断的 UTF-8 多字节字符；
/// 3. 截断自愈：精确捕捉文件被清空（truncate / logrotate）行为并通知上层重置。
final class FileLiveTailEngine {
    private(set) var currentOffset: UInt64 = 0

    init(initialOffset: UInt64 = 0) {
        self.currentOffset = initialOffset
    }

    /// 识别文件是否为日志文件
    static func isLogFile(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return url.pathExtension.lowercased() == "log"
    }

    /// 重置或同步当前偏移量
    func resetOffset(to offset: UInt64) {
        self.currentOffset = offset
    }

    /// 读取自上次偏移量之后所有追加的新文本
    func readAppendedText(at path: String) -> LiveTailReadResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(reason: "File not found".localized())
        }

        let fileURL = URL(fileURLWithPath: path)
        let totalSize: UInt64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            totalSize = (attributes[.size] as? UInt64) ?? 0
        } catch {
            return .failure(reason: error.localizedDescription)
        }

        // 1. 如果文件变小了，判定为被截断或重新生成
        if totalSize < currentOffset {
            self.currentOffset = totalSize
            return .truncated(newSize: totalSize)
        }

        // 2. 如果大小无变化，无需读取
        if totalSize == currentOffset {
            return .noChange
        }

        // 3. 增量读取区间 [currentOffset, totalSize]
        let bytesToRead = Int(totalSize - currentOffset)
        guard bytesToRead > 0 else {
            return .noChange
        }

        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? handle.close()
            }

            if #available(macOS 10.15, *) {
                try handle.seek(toOffset: currentOffset)
            } else {
                handle.seek(toFileOffset: currentOffset)
            }

            let data: Data
            if #available(macOS 10.15, *) {
                data = try handle.read(upToCount: bytesToRead) ?? Data()
            } else {
                data = handle.readData(ofLength: bytesToRead)
            }

            guard !data.isEmpty else {
                return .noChange
            }

            // 检查末尾是否有切断的多字节 UTF-8 字符
            var validData = data
            let truncatedBytes = FileChunkReader.trailingIncompleteUTF8Bytes(in: data)
            if truncatedBytes > 0 && truncatedBytes < data.count {
                validData = data.prefix(data.count - truncatedBytes)
            }

            let encoding = EncodingDetector.detect(data: validData)
            let text: String
            if let decoded = String(data: validData, encoding: encoding) {
                text = decoded
            } else {
                text = String(decoding: validData, as: UTF8.self)
            }

            let consumedBytes = UInt64(validData.count)
            self.currentOffset += consumedBytes

            return .appended(text: text, newOffset: self.currentOffset)
        } catch {
            return .failure(reason: error.localizedDescription)
        }
    }
}
