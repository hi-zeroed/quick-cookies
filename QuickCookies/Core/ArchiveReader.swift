import Foundation

enum ArchiveError: LocalizedError, Equatable {
    case fileNotFound
    case unsupportedFormat
    case encryptedOrCorrupted
    case subfileNotFound(String)
    case subfileTooLarge(Int64)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Archive file not found".localized()
        case .unsupportedFormat:
            return "Unsupported archive format".localized()
        case .encryptedOrCorrupted:
            return "Encrypted or corrupted archive".localized()
        case .subfileNotFound(let path):
            return String(format: "File '%@' not found in archive".localized(), path)
        case .subfileTooLarge(let size):
            let formatted = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            return String(format: "Subfile too large (%@)".localized(), formatted)
        case .readFailed(let msg):
            return msg
        }
    }
}

struct ArchiveReader {
    /// 异步读取归档文件目录树与元数据
    static func readArchive(at path: String) async throws -> (summary: ArchiveSummary, entries: [ArchiveEntry], tree: [ArchiveTreeNode]) {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ArchiveError.fileNotFound
        }

        let ext = (path as NSString).pathExtension.lowercased()
        let isZipKind = ["zip", "jar", "war", "ear"].contains(ext)
        let isTarKind = ["tar", "gz", "tgz", "bz2", "tbz2", "xz", "txz"].contains(ext)

        guard isZipKind || isTarKind else {
            throw ArchiveError.unsupportedFormat
        }

        let formatName: String
        if isZipKind {
            formatName = "ZIP Archive"
        } else if ext == "gz" || ext == "tgz" {
            formatName = "TAR.GZ Archive"
        } else if ext == "bz2" || ext == "tbz2" {
            formatName = "TAR.BZ2 Archive"
        } else if ext == "xz" || ext == "txz" {
            formatName = "TAR.XZ Archive"
        } else {
            formatName = ext.uppercased() + " Archive"
        }

        let entries = try await parseArchiveEntries(path: path)

        guard !entries.isEmpty else {
            // 空压缩包
            let summary = ArchiveSummary(
                totalEntries: 0,
                fileCount: 0,
                directoryCount: 0,
                totalUncompressedSize: 0,
                totalCompressedSize: (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0,
                formatName: formatName,
                categoryBreakdowns: []
            )
            return (summary, [], [])
        }

        var totalUncompressed: Int64 = 0
        var files = 0
        var dirs = 0
        var categorySizes: [ArchiveCategory: Int64] = [:]
        var categoryCounts: [ArchiveCategory: Int] = [:]

        for entry in entries {
            totalUncompressed += entry.uncompressedSize
            if entry.isDirectory {
                dirs += 1
            } else {
                files += 1
                let cat = ArchiveCategory.category(for: entry.fileExtension)
                categorySizes[cat, default: 0] += entry.uncompressedSize
                categoryCounts[cat, default: 0] += 1
            }
        }

        var breakdowns: [ArchiveCategoryStat] = []
        for cat in ArchiveCategory.allCases {
            let size = categorySizes[cat] ?? 0
            let count = categoryCounts[cat] ?? 0
            guard count > 0 else { continue }
            let pct = totalUncompressed > 0 ? Double(size) / Double(totalUncompressed) : (files > 0 ? Double(count) / Double(files) : 0)
            breakdowns.append(ArchiveCategoryStat(
                category: cat,
                fileCount: count,
                totalSize: size,
                percentage: pct
            ))
        }
        breakdowns.sort { $0.totalSize > $1.totalSize }

        let archiveFileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? totalUncompressed

        let summary = ArchiveSummary(
            totalEntries: entries.count,
            fileCount: files,
            directoryCount: dirs,
            totalUncompressedSize: totalUncompressed,
            totalCompressedSize: archiveFileSize,
            formatName: formatName,
            categoryBreakdowns: breakdowns
        )

        let tree = ArchiveTreeBuilder.buildTree(from: entries)
        return (summary, entries, tree)
    }

    /// 内存管道流式提取单个子文件内容
    static func readSubfileData(archivePath: String, entryPath: String, maxBytes: Int = 10 * 1024 * 1024) async throws -> Data {
        guard FileManager.default.fileExists(atPath: archivePath) else {
            throw ArchiveError.fileNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()

                // macOS 内置 BSD tar (基于 libarchive) 统一支持 zip, tar, gz, bz2, xz
                // 且原生支持 UTF-8 编码，杜绝非 ASCII 问号乱码
                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-xOf", archivePath, entryPath]
                process.environment = [
                    "LC_ALL": "en_US.UTF-8",
                    "LANG": "en_US.UTF-8",
                    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"
                ]

                process.standardOutput = pipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if process.terminationStatus == 0 {
                        if data.count > maxBytes {
                            continuation.resume(throwing: ArchiveError.subfileTooLarge(Int64(data.count)))
                        } else {
                            continuation.resume(returning: data)
                        }
                    } else {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? "Extraction failed"
                        continuation.resume(throwing: ArchiveError.readFailed(errMsg))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 判断是否为系统隐藏垃圾文件（如 __MACOSX 目录、.DS_Store、AppleDouble 影子文件等）
    static func isSystemJunkEntry(path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return true }

        // 1. __MACOSX 目录及内部所有文件
        if trimmed == "__MACOSX" || trimmed.hasPrefix("__MACOSX/") || trimmed.contains("/__MACOSX/") {
            return true
        }

        // 2. 获取路径最末端的独立文件名
        let components = trimmed.split(separator: "/")
        guard let lastComponent = components.last else { return true }
        let filename = String(lastComponent)

        // 3. 常见系统垃圾文件：.DS_Store, AppleDouble (._*), Windows 缩略图缓存等
        if filename == ".DS_Store" ||
           filename.hasPrefix("._") ||
           filename == "Thumbs.db" ||
           filename == "desktop.ini" ||
           filename == "__MACOSX" {
            return true
        }

        return false
    }

    // MARK: - Private Parser

    private static func parseArchiveEntries(path: String) async throws -> [ArchiveEntry] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
                process.arguments = ["-tvf", path]
                process.environment = [
                    "LC_ALL": "en_US.UTF-8",
                    "LANG": "en_US.UTF-8",
                    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"
                ]
                process.standardOutput = pipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errMsg = String(data: errData, encoding: .utf8) ?? ""
                        if errMsg.contains("Empty archive") || errMsg.contains("empty") {
                            continuation.resume(returning: [])
                            return
                        }
                        continuation.resume(throwing: ArchiveError.encryptedOrCorrupted)
                        return
                    }

                    guard let output = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                        continuation.resume(returning: [])
                        return
                    }

                    let entries = parseTarOutput(output)
                    continuation.resume(returning: entries)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func parseTarOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let lines = output.components(separatedBy: .newlines)
        let months: Set<String> = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true)
            guard tokens.count >= 6 else { continue }

            let permissions = String(tokens[0])
            let isDir = permissions.hasPrefix("d") || trimmed.hasSuffix("/")

            var foundSize: Int64?
            var foundPath: String?

            // 智能探测时间戳与文件名分界线
            for i in 0..<(tokens.count - 1) {
                let tok = String(tokens[i])

                // 情况 1: 标准 BSD 格式: [Month] [Day] [Time/Year] [FilePath...]
                if months.contains(tok), i > 0, i + 2 < tokens.count {
                    if let size = Int64(tokens[i - 1]) {
                        foundSize = size
                        foundPath = tokens[(i + 3)...].joined(separator: " ")
                        break
                    }
                }
                // 情况 2: ISO 日期格式: [yyyy-MM-dd] [HH:mm] [FilePath...]
                else if tok.count == 10, tok.filter({ $0 == "-" }).count == 2, i > 0, i + 1 < tokens.count {
                    if let size = Int64(tokens[i - 1]) {
                        foundSize = size
                        foundPath = tokens[(i + 2)...].joined(separator: " ")
                        break
                    }
                }
            }

            guard let entryPath = foundPath, !entryPath.isEmpty else {
                continue
            }

            // 过滤系统垃圾文件
            if isSystemJunkEntry(path: entryPath) {
                continue
            }

            entries.append(ArchiveEntry(
                path: entryPath,
                uncompressedSize: foundSize ?? 0,
                compressedSize: nil,
                isDirectory: isDir || entryPath.hasSuffix("/"),
                modificationDate: nil
            ))
        }

        return entries
    }
}
