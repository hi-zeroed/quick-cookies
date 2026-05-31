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
            return .failure(.readFailed(path: fileURL.path, reason: "文件句柄已关闭"))
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
            guard let content = String(data: data, encoding: encoding) else {
                return .failure(.readFailed(path: fileURL.path, reason: "编码解码失败"))
            }
            
            let bytesRead = data.count
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
            return .failure(.readFailed(path: fileURL.path, reason: "文件句柄已关闭"))
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
            guard let content = String(data: data, encoding: encoding) else {
                return .failure(.readFailed(path: fileURL.path, reason: "编码解码失败"))
            }
            
            currentOffset += UInt64(data.count)
            close() // 读完自动关闭
            
            return .success(content)
        } catch {
            return .failure(.readFailed(path: fileURL.path, reason: error.localizedDescription))
        }
    }
    
    private func isBinaryFile(_ data: Data) -> Bool {
        let checkSize = min(data.count, 8192)
        let sample = data.prefix(checkSize)
        return sample.contains(0x00)
    }
}
