import Foundation

/// 归档中的单个文件或目录条目
struct ArchiveEntry: Equatable, Hashable {
    let path: String              // 完整相对路径，例如 "src/index.ts" 或 "dist/"
    let uncompressedSize: Int64   // 原始解压后大小
    let compressedSize: Int64?    // 压缩后大小（若有）
    let isDirectory: Bool         // 是否为目录
    let modificationDate: Date?   // 修改日期

    var fileName: String {
        let trimmed = isDirectory && path.hasSuffix("/") ? String(path.dropLast()) : path
        return (trimmed as NSString).lastPathComponent
    }

    var fileExtension: String {
        return (path as NSString).pathExtension.lowercased()
    }
}

/// 文件内容分类
enum ArchiveCategory: String, CaseIterable, Equatable {
    case code
    case document
    case image
    case config
    case other

    var displayName: String {
        switch self {
        case .code: return "Code".localized()
        case .document: return "Documents".localized()
        case .image: return "Images".localized()
        case .config: return "Config".localized()
        case .other: return "Other".localized()
        }
    }

    static func category(for extensionString: String) -> ArchiveCategory {
        let ext = extensionString.lowercased()
        if [
            "swift", "ts", "tsx", "js", "jsx", "py", "rs", "go", "c", "cpp", "h", "hpp",
            "java", "kt", "rb", "php", "sh", "zsh", "bash", "html", "css", "scss", "less",
            "vue", "svelte", "dart", "lua", "m", "mm", "scala", "sql", "graphql"
        ].contains(ext) {
            return .code
        }
        if ["md", "markdown", "txt", "pdf", "doc", "docx", "rtf", "pages", "tex", "csv"].contains(ext) {
            return .document
        }
        if ["png", "jpg", "jpeg", "webp", "gif", "svg", "ico", "bmp", "tiff", "heic", "ai", "psd"].contains(ext) {
            return .image
        }
        if ["json", "yaml", "yml", "toml", "xml", "plist", "ini", "env", "config", "lock", "properties"].contains(ext) {
            return .config
        }
        return .other
    }
}

/// 类别聚合统计项
struct ArchiveCategoryStat: Equatable, Identifiable {
    var id: String { category.rawValue }
    let category: ArchiveCategory
    let fileCount: Int
    let totalSize: Int64
    let percentage: Double // 0.0 ~ 1.0

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var percentageString: String {
        let pct = max(1, Int(round(percentage * 100)))
        return "\(pct)%"
    }
}

/// 归档汇总统计信息
struct ArchiveSummary: Equatable {
    let totalEntries: Int
    let fileCount: Int
    let directoryCount: Int
    let totalUncompressedSize: Int64
    let totalCompressedSize: Int64
    let formatName: String
    let categoryBreakdowns: [ArchiveCategoryStat]

    var formattedUncompressedSize: String {
        ByteCountFormatter.string(fromByteCount: totalUncompressedSize, countStyle: .file)
    }

    var formattedCompressedSize: String {
        ByteCountFormatter.string(fromByteCount: totalCompressedSize, countStyle: .file)
    }

    var compressionRatioPercentage: Int? {
        guard totalUncompressedSize > 0 && totalCompressedSize > 0 else { return nil }
        if totalCompressedSize >= totalUncompressedSize { return nil }
        let saved = totalUncompressedSize - totalCompressedSize
        return Int(round(Double(saved) / Double(totalUncompressedSize) * 100))
    }
}

/// 归档目录树节点（支持多层级嵌套、文件夹优先排序与展开折叠）
final class ArchiveTreeNode: Identifiable, ObservableObject, Equatable {
    let id: String                // 节点唯一标识（即 fullPath）
    let name: String              // 当前层级名称，例如 "index.ts" 或 "src"
    let fullPath: String          // 归档内的完整路径
    let isDirectory: Bool
    let uncompressedSize: Int64   // 文件自身大小或文件夹聚合大小
    let compressedSize: Int64?
    let modificationDate: Date?
    var children: [ArchiveTreeNode]
    @Published var isExpanded: Bool

    init(
        id: String,
        name: String,
        fullPath: String,
        isDirectory: Bool,
        uncompressedSize: Int64,
        compressedSize: Int64? = nil,
        modificationDate: Date? = nil,
        children: [ArchiveTreeNode] = [],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.fullPath = fullPath
        self.isDirectory = isDirectory
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.modificationDate = modificationDate
        self.children = children
        self.isExpanded = isExpanded
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: uncompressedSize, countStyle: .file)
    }

    var fileExtension: String {
        return (fullPath as NSString).pathExtension.lowercased()
    }

    static func == (lhs: ArchiveTreeNode, rhs: ArchiveTreeNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.fullPath == rhs.fullPath &&
        lhs.isDirectory == rhs.isDirectory &&
        lhs.uncompressedSize == rhs.uncompressedSize &&
        lhs.children == rhs.children &&
        lhs.isExpanded == rhs.isExpanded
    }
}
