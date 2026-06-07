import Foundation

enum MarkdownFileStreamReader {
    private static let readChunkSize = 256 * 1024

    static func readEntireFile(path: String) -> Result<String, FileUtils.FileError> {
        let fileURL = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }

        guard FileManager.default.isReadableFile(atPath: path) else {
            return .failure(.permissionDenied(path: path))
        }

        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? handle.close()
            }

            var accumulated = Data()
            var isFirstChunk = true

            while true {
                let chunk: Data
                if #available(macOS 10.15, *) {
                    chunk = try handle.read(upToCount: readChunkSize) ?? Data()
                } else {
                    chunk = handle.readData(ofLength: readChunkSize)
                }

                if chunk.isEmpty {
                    break
                }

                if isFirstChunk {
                    isFirstChunk = false
                    if isBinaryFile(chunk) {
                        return .failure(.binaryFile(path: path))
                    }
                }

                accumulated.append(chunk)
            }

            if accumulated.isEmpty {
                return .success("")
            }

            let encoding = EncodingDetector.detect(data: accumulated)
            guard let content = String(data: accumulated, encoding: encoding) else {
                return .failure(.readFailed(path: path, reason: "编码解码失败"))
            }

            return .success(content)
        } catch {
            return .failure(.readFailed(path: path, reason: error.localizedDescription))
        }
    }

    static func fileSize(path: String) -> UInt64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return 0
        }
        return (attributes[.size] as? UInt64) ?? 0
    }

    private static func isBinaryFile(_ data: Data) -> Bool {
        let checkSize = min(data.count, 8192)
        let sample = data.prefix(checkSize)
        return sample.contains(0x00)
    }
}
