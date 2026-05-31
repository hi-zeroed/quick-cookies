import Foundation

enum FileUtils {
    enum FileError: Error, LocalizedError {
        case fileNotFound(path: String)
        case permissionDenied(path: String)
        case readFailed(path: String, reason: String)
        case writeFailed(path: String, reason: String)
        case binaryFile(path: String)
        case fileTooLarge(path: String, size: Int)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "文件不存在: \(path)"
            case .permissionDenied(let path):
                return "权限不足，无法访问: \(path)"
            case .readFailed(let path, let reason):
                return "读取失败: \(path) - \(reason)"
            case .writeFailed(let path, let reason):
                return "保存失败: \(path) - \(reason)"
            case .binaryFile(let path):
                return "不支持二进制文件: \(path)"
            case .fileTooLarge(let path, let size):
                return "文件较大 (\(size / 1024 / 1024)MB): \(path)"
            }
        }
    }

    /// 读取文件内容
    static func readFile(at path: String) -> Result<(content: String, encoding: String.Encoding), FileError> {
        let url = URL(fileURLWithPath: path)

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }

        // 检查是否可读
        guard FileManager.default.isReadableFile(atPath: path) else {
            return .failure(.permissionDenied(path: path))
        }

        // 读取数据
        guard let data = try? Data(contentsOf: url) else {
            return .failure(.readFailed(path: path, reason: "无法读取数据"))
        }

        // 检查文件大小
        if data.count > Constants.largeFileThreshold {
            return .failure(.fileTooLarge(path: path, size: data.count))
        }

        // 检查是否为二进制文件
        if isBinaryFile(data) {
            return .failure(.binaryFile(path: path))
        }

        // 检测编码并解码
        let encoding = EncodingDetector.detect(data: data)
        guard let content = String(data: data, encoding: encoding) else {
            return .failure(.readFailed(path: path, reason: "编码解码失败"))
        }

        return .success((content: content, encoding: encoding))
    }

    /// 高性能分段读取文件（仅读取前 limitBytes 字节，支持超大文件秒开）
    static func readLimitFile(at path: String, limitBytes: Int = 128 * 1024) -> Result<(content: String, isTruncated: Bool), FileError> {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            return .failure(.permissionDenied(path: path))
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let fileSize = (attributes[.size] as? UInt64) ?? 0
            let isTruncated = fileSize > UInt64(limitBytes)

            let fileHandle = try FileHandle(forReadingFrom: url)
            
            // 物理限制只读取 limitBytes 字节，瞬间返回
            let data: Data
            if #available(macOS 10.15, *) {
                data = try fileHandle.read(upToCount: limitBytes) ?? Data()
            } else {
                data = fileHandle.readData(ofLength: limitBytes)
            }
            try? fileHandle.close()

            if isBinaryFile(data) {
                return .failure(.binaryFile(path: path))
            }

            let encoding = EncodingDetector.detect(data: data)
            guard let content = String(data: data, encoding: encoding) else {
                return .failure(.readFailed(path: path, reason: "编码解码失败"))
            }

            return .success((content: content, isTruncated: isTruncated))
        } catch {
            return .failure(.readFailed(path: path, reason: error.localizedDescription))
        }
    }

    /// 写入文件
    static func writeFile(at path: String, content: String, encoding: String.Encoding = .utf8) -> Result<Void, FileError> {
        let url = URL(fileURLWithPath: path)

        // 检查是否可写
        guard FileManager.default.isWritableFile(atPath: path) else {
            return .failure(.permissionDenied(path: path))
        }

        // 写入数据
        guard let data = content.data(using: encoding) else {
            return .failure(.writeFailed(path: path, reason: "编码转换失败"))
        }

        do {
            try data.write(to: url, options: .atomic)
            return .success(())
        } catch {
            return .failure(.writeFailed(path: path, reason: error.localizedDescription))
        }
    }

    /// 检测是否为二进制文件（通过检查 null 字节）
    private static func isBinaryFile(_ data: Data) -> Bool {
        // 检查前 8KB 是否包含 null 字节
        let checkSize = min(data.count, 8192)
        let sample = data.prefix(checkSize)
        return sample.contains(0x00)
    }

    /// 解析符号链接的真实路径
    static func resolveSymlink(at path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let resolved = url.resolvingSymlinksInPath()
        return resolved.path
    }

    /// 获取文件最后修改时间
    static func getModificationDate(at path: String) -> Date {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return (attributes?[.modificationDate] as? Date) ?? Date()
    }
}