import Foundation

enum FolderError: LocalizedError, Equatable {
    case folderNotFound
    case accessDenied
    case scanFailed(String)

    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Folder not found".localized()
        case .accessDenied:
            return "Access denied to folder".localized()
        case .scanFailed(let msg):
            return msg
        }
    }
}

struct FolderReader {
    /// 全生态依赖、构建产物、虚拟环境与缓存目录（覆盖 Node, Python, Rust, Go, Java, Apple, Android, Flutter, C++, IDE 等）
    static let heavyDirectoryNames: Set<String> = [
        // Node / JavaScript / TypeScript / Frontend
        "node_modules", ".pnpm", ".pnpm-store", ".yarn", ".npm", "bower_components", "jspm_packages",
        "dist", "out", ".next", ".nuxt", ".output", ".astro", ".svelte-kit", ".docusaurus", "storybook-static",
        ".parcel-cache", ".turbo", ".eslintcache",
        // Python
        "site-packages", ".venv", "venv", "env", ".env", "ENV", ".tox", ".nox", ".pipenv", "__pypackages__",
        "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".coverage", ".hypothesis", "eggs", ".eggs",
        // Rust / Cargo
        "target", ".cargo",
        // Go
        "vendor", "pkg",
        // Java / Kotlin / Gradle / Maven
        ".gradle", ".m2", ".mvn",
        // Apple (Swift / Xcode / CocoaPods)
        "Pods", "Carthage", ".swiftpm", "SourcePackages", "checkouts",
        "DerivedData", ".build", "Products", "Intermediates.noindex", "Index.noindex",
        // Android / Mobile
        ".cxx", "captures",
        // Flutter / Dart
        ".dart_tool", ".pub-cache", ".pub", ".fvm",
        // C / C++ / CMake
        "vcpkg_installed", "CMakeFiles", "cmake-build-debug", "cmake-build-release",
        // 版本控制 (VCS)
        ".git", ".svn", ".hg", ".bzr", "CVS", ".repo",
        // IDE 与编辑器
        ".idea", ".vscode", ".fleet", ".vs",
        // 缓存与通用临时目录
        ".cache", ".temp", ".tmp", "coverage"
    ]

    /// 异步读取本地文件夹目录树与元数据（采用广度优先与直接子项 100% 保障策略）
    static func readFolder(
        at folderPath: String,
        maxDirectItems: Int = 1000,
        maxDescendantsPerSubdir: Int = 150
    ) async throws -> (summary: ArchiveSummary, entries: [ArchiveEntry], tree: [ArchiveTreeNode]) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir), isDir.boolValue else {
            throw FolderError.folderNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager.default
                let standardizedBase = URL(fileURLWithPath: (folderPath as NSString).resolvingSymlinksInPath).standardizedFileURL
                let folderBasePath = standardizedBase.path

                // 阶段一：100% 获取直接一级子项（保证同级工程/文件一个不漏）
                guard let directContents = try? fileManager.contentsOfDirectory(
                    at: standardizedBase,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                    options: []
                ) else {
                    continuation.resume(throwing: FolderError.scanFailed("Failed to list folder contents"))
                    return
                }

                var entries: [ArchiveEntry] = []
                var totalBytes: Int64 = 0
                var files = 0
                var dirs = 0
                var categorySizes: [ArchiveCategory: Int64] = [:]
                var categoryCounts: [ArchiveCategory: Int] = [:]

                // 排序一级子项：文件夹在前，按字母序排列
                let sortedDirect = directContents.sorted { urlA, urlB in
                    let isDirA = (try? urlA.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let isDirB = (try? urlB.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDirA != isDirB {
                        return isDirA && !isDirB
                    }
                    return urlA.lastPathComponent.localizedStandardCompare(urlB.lastPathComponent) == .orderedAscending
                }

                let directSlice = sortedDirect.prefix(maxDirectItems)

                for directURL in directSlice {
                    let directName = directURL.lastPathComponent
                    guard !ArchiveReader.isSystemJunkEntry(path: directName) else { continue }

                    let resourceValues = try? directURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                    let isDirectory = resourceValues?.isDirectory ?? false
                    let fileSize = Int64(resourceValues?.fileSize ?? 0)
                    let modDate = resourceValues?.contentModificationDate

                    let directRelPath = isDirectory ? "\(directName)/" : directName

                    if isDirectory {
                        dirs += 1
                    } else {
                        files += 1
                        totalBytes += fileSize
                        let cat = ArchiveCategory.category(for: directURL.pathExtension)
                        categorySizes[cat, default: 0] += fileSize
                        categoryCounts[cat, default: 0] += 1
                    }

                    entries.append(ArchiveEntry(
                        path: directRelPath,
                        uncompressedSize: fileSize,
                        compressedSize: nil,
                        isDirectory: isDirectory,
                        modificationDate: modDate
                    ))

                    // 阶段二：对每个一级子文件夹进行浅层受控探测（深度 ≤ 2，单目录上限受控，跳过重型依赖）
                    if isDirectory && !Self.isHeavyDirectory(name: directName) {
                        guard let subEnumerator = fileManager.enumerator(
                            at: directURL,
                            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                            options: [.skipsPackageDescendants]
                        ) else { continue }

                        var subScanned = 0
                        while let subURL = subEnumerator.nextObject() as? URL {
                            subScanned += 1
                            if subScanned > maxDescendantsPerSubdir {
                                break
                            }

                            let subName = subURL.lastPathComponent
                            let subIsDirectory = (try? subURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

                            if subIsDirectory && Self.isHeavyDirectory(name: subName) {
                                subEnumerator.skipDescendants()
                            }

                            guard !ArchiveReader.isSystemJunkEntry(path: subName) else { continue }

                            let subResolvedPath = (subURL.path as NSString).resolvingSymlinksInPath
                            var relFromBase = subResolvedPath
                            if relFromBase.hasPrefix(folderBasePath + "/") {
                                relFromBase = String(relFromBase.dropFirst(folderBasePath.count + 1))
                            } else if relFromBase.hasPrefix(folderBasePath) {
                                relFromBase = String(relFromBase.dropFirst(folderBasePath.count))
                            }
                            guard !relFromBase.isEmpty, relFromBase != directRelPath else { continue }

                            let subValues = try? subURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                            let subSize = Int64(subValues?.fileSize ?? 0)
                            let subDate = subValues?.contentModificationDate

                            let entryPath = subIsDirectory && !relFromBase.hasSuffix("/") ? relFromBase + "/" : relFromBase

                            if subIsDirectory {
                                dirs += 1
                            } else {
                                files += 1
                                totalBytes += subSize
                                let cat = ArchiveCategory.category(for: subURL.pathExtension)
                                categorySizes[cat, default: 0] += subSize
                                categoryCounts[cat, default: 0] += 1
                            }

                            entries.append(ArchiveEntry(
                                path: entryPath,
                                uncompressedSize: subSize,
                                compressedSize: nil,
                                exposesDirectory: subIsDirectory,
                                isDirectory: subIsDirectory,
                                modificationDate: subDate
                            ))
                        }
                    }
                }

                // 类别 breakdown
                var breakdowns: [ArchiveCategoryStat] = []
                for cat in ArchiveCategory.allCases {
                    let size = categorySizes[cat] ?? 0
                    let count = categoryCounts[cat] ?? 0
                    guard count > 0 else { continue }
                    let pct = totalBytes > 0 ? Double(size) / Double(totalBytes) : (files > 0 ? Double(count) / Double(files) : 0)
                    breakdowns.append(ArchiveCategoryStat(
                        category: cat,
                        fileCount: count,
                        totalSize: size,
                        percentage: pct
                    ))
                }
                breakdowns.sort { $0.totalSize > $1.totalSize }

                let summary = ArchiveSummary(
                    totalEntries: entries.count,
                    fileCount: files,
                    directoryCount: dirs,
                    totalUncompressedSize: totalBytes,
                    totalCompressedSize: totalBytes,
                    formatName: "Folder".localized(),
                    categoryBreakdowns: breakdowns
                )

                let tree = ArchiveTreeBuilder.buildTree(from: entries)
                continuation.resume(returning: (summary, entries, tree))
            }
        }
    }

    /// 判断是否为重型依赖、编译产物或虚拟环境目录
    static func isHeavyDirectory(name: String) -> Bool {
        if heavyDirectoryNames.contains(name) {
            return true
        }
        if name.hasSuffix(".egg-info") || name.hasSuffix(".xcarchive") {
            return true
        }
        return false
    }
}

// 辅助扩展
private extension ArchiveEntry {
    init(path: String, uncompressedSize: Int64, compressedSize: Int64?, exposesDirectory: Bool, isDirectory: Bool, modificationDate: Date?) {
        self.init(path: path, uncompressedSize: uncompressedSize, compressedSize: compressedSize, isDirectory: isDirectory, modificationDate: modificationDate)
    }
}
