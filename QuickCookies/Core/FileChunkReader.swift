import Foundation

class FileChunkReader {
    private let fileURL: URL
    private var fileHandle: FileHandle?
    private(set) var totalSize: UInt64 = 0
    private(set) var currentOffset: UInt64 = 0
    private var isFirstChunk = true
    
    init(path: String) throws {
        self.fileURL = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw FileUtils.FileError.fileNotFound(path: path)
        }
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw FileUtils.FileError.permissionDenied(path: path)
        }
        
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        self.totalSize = (attributes[.size] as? UInt64) ?? 0
        
        self.fileHandle = try FileHandle(forReadingFrom: fileURL)
    }
    
    deinit {
        close()
    }
    
    func close() {
        try? fileHandle?.close()
        fileHandle = nil
    }
    
    /// 读取下一个分块
    func readNextChunk(limitBytes: Int) -> Result<(content: String, bytesRead: Int, hasMore: Bool), FileUtils.FileError> {
        guard let fileHandle = fileHandle else {
            return .failure(.readFailed(path: fileURL.path, reason: "File handle closed".localized()))
        }
        
        do {
            if #available(macOS 10.15, *) {
                try fileHandle.seek(toOffset: currentOffset)
            } else {
                fileHandle.seek(toFileOffset: currentOffset)
            }
            
            let data: Data
            if #available(macOS 10.15, *) {
                data = try fileHandle.read(upToCount: limitBytes) ?? Data()
            } else {
                data = fileHandle.readData(ofLength: limitBytes)
            }
            
            if data.isEmpty {
                return .success((content: "", bytesRead: 0, hasMore: false))
            }
            
            // 首次读取进行二进制文件校验
            if isFirstChunk {
                isFirstChunk = false
                if isBinaryFile(data) {
                    return .failure(.binaryFile(path: fileURL.path))
                }
            }
            
            let encoding = EncodingDetector.detect(data: data)
            
            // 如果还有后续数据且检测为 UTF-8，检查末尾是否被切断了多字节字符
            var validData = data
            if currentOffset + UInt64(data.count) < totalSize && encoding == .utf8 {
                let truncatedBytes = Self.trailingIncompleteUTF8Bytes(in: data)
                if truncatedBytes > 0 && truncatedBytes < data.count {
                    validData = data.prefix(data.count - truncatedBytes)
                }
            }
            
            let content: String
            if let decoded = String(data: validData, encoding: encoding) {
                content = decoded
            } else {
                // 兜底容错解码，防止个别异常字节导致读取失败阻断首屏
                content = String(decoding: validData, as: UTF8.self)
            }
            
            let bytesRead = validData.count
            currentOffset += UInt64(bytesRead)
            let hasMore = currentOffset < totalSize
            
            return .success((content: content, bytesRead: bytesRead, hasMore: hasMore))
        } catch {
            return .failure(.readFailed(path: fileURL.path, reason: error.localizedDescription))
        }
    }
    
    /// 一次性读完剩余所有内容（适用于切换编辑模式）
    func readRemaining() -> Result<String, FileUtils.FileError> {
        guard let fileHandle = fileHandle else {
            return .failure(.readFailed(path: fileURL.path, reason: "File handle closed".localized()))
        }
        
        do {
            if #available(macOS 10.15, *) {
                try fileHandle.seek(toOffset: currentOffset)
            } else {
                fileHandle.seek(toFileOffset: currentOffset)
            }
            
            let data: Data
            if #available(macOS 10.15, *) {
                data = try fileHandle.readToEnd() ?? Data()
            } else {
                data = fileHandle.readDataToEndOfFile()
            }
            
            if isFirstChunk {
                isFirstChunk = false
                if isBinaryFile(data) {
                    return .failure(.binaryFile(path: fileURL.path))
                }
            }
            
            let encoding = EncodingDetector.detect(data: data)
            let content: String
            if let decoded = String(data: data, encoding: encoding) {
                content = decoded
            } else {
                content = String(decoding: data, as: UTF8.self)
            }
            
            currentOffset += UInt64(data.count)
            close() // 读完自动关闭
            
            return .success(content)
        } catch {
            return .failure(.readFailed(path: fileURL.path, reason: error.localizedDescription))
        }
    }
    
    /// 检测数据末尾是否包含因分块读取而被截断的 UTF-8 多字节字符序列，返回需要从尾部截掉并回退的字节数 (0...3)
    static func trailingIncompleteUTF8Bytes(in data: Data) -> Int {
        let count = data.count
        guard count > 0 else { return 0 }
        
        let maxCheck = min(count, 4)
        for i in 1...maxCheck {
            let byte = data[count - i]
            if (byte & 0x80) == 0 {
                // 单字节 ASCII (0x00...0x7F)，说明在此之前的字符已闭合
                return 0
            }
            if (byte & 0xC0) == 0xC0 {
                // 找到了多字节前导字节
                let expectedLength: Int
                if (byte & 0xE0) == 0xC0 {
                    expectedLength = 2
                } else if (byte & 0xF0) == 0xE0 {
                    expectedLength = 3
                } else if (byte & 0xF8) == 0xF0 {
                    expectedLength = 4
                } else {
                    return 0
                }
                
                let actualLength = i // 当前前导字节到末尾的字节总数
                if actualLength < expectedLength {
                    // 该字符未闭合，截断了 actualLength 个字节
                    return actualLength
                } else {
                    // 该字符已闭合
                    return 0
                }
            }
        }
        return 0
    }

    private func isBinaryFile(_ data: Data) -> Bool {
        let checkSize = min(data.count, 8192)
        let sample = data.prefix(checkSize)
        return sample.contains(0x00)
    }
}
