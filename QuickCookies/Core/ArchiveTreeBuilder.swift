import Foundation

struct ArchiveTreeBuilder {
    /// 将扁平的 ArchiveEntry 列表构建为层级分明、排好序的树形节点列表
    static func buildTree(from entries: [ArchiveEntry]) -> [ArchiveTreeNode] {
        // 内部临时辅助节点结构，便于构建
        class TempNode {
            let name: String
            let fullPath: String
            var isDirectory: Bool
            var size: Int64
            var compressedSize: Int64?
            var date: Date?
            var childrenMap: [String: TempNode] = [:]

            init(name: String, fullPath: String, isDirectory: Bool, size: Int64 = 0, compressedSize: Int64? = nil, date: Date? = nil) {
                self.name = name
                self.fullPath = fullPath
                self.isDirectory = isDirectory
                self.size = size
                self.compressedSize = compressedSize
                self.date = date
            }

            func toArchiveTreeNode() -> ArchiveTreeNode {
                // 递归转换子节点并排序：文件夹排在前，随后按字母序
                let sortedChildren = childrenMap.values
                    .map { $0.toArchiveTreeNode() }
                    .sorted { (a, b) -> Bool in
                        if a.isDirectory != b.isDirectory {
                            return a.isDirectory && !b.isDirectory
                        }
                        return a.name.localizedStandardCompare(b.name) == .orderedAscending
                    }

                // 文件夹大小为其所有子项大小的总和
                let calculatedSize: Int64
                if isDirectory {
                    calculatedSize = sortedChildren.reduce(0) { $0 + $1.uncompressedSize }
                } else {
                    calculatedSize = size
                }

                return ArchiveTreeNode(
                    id: fullPath,
                    name: name,
                    fullPath: fullPath,
                    isDirectory: isDirectory,
                    uncompressedSize: calculatedSize,
                    compressedSize: compressedSize,
                    modificationDate: date,
                    children: sortedChildren,
                    isExpanded: false
                )
            }
        }

        let root = TempNode(name: "", fullPath: "", isDirectory: true)

        for entry in entries {
            // 清理路径中的首尾斜杠并按 '/' 切割
            let cleanPath = entry.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !cleanPath.isEmpty else { continue }

            let parts = cleanPath.split(separator: "/").map(String.init)
            var current = root

            for (index, part) in parts.enumerated() {
                let isLast = index == parts.count - 1
                let subPath = parts[0...index].joined(separator: "/")

                if isLast {
                    if let existing = current.childrenMap[part] {
                        existing.isDirectory = entry.isDirectory
                        existing.size = entry.uncompressedSize
                        existing.compressedSize = entry.compressedSize
                        existing.date = entry.modificationDate
                    } else {
                        let node = TempNode(
                            name: part,
                            fullPath: subPath + (entry.isDirectory ? "/" : ""),
                            isDirectory: entry.isDirectory,
                            size: entry.uncompressedSize,
                            compressedSize: entry.compressedSize,
                            date: entry.modificationDate
                        )
                        current.childrenMap[part] = node
                    }
                } else {
                    // 中间文件夹节点，若不存在则隐式创建
                    if let next = current.childrenMap[part] {
                        current = next
                    } else {
                        let dirNode = TempNode(
                            name: part,
                            fullPath: subPath + "/",
                            isDirectory: true
                        )
                        current.childrenMap[part] = dirNode
                        current = dirNode
                    }
                }
            }
        }

        // 顶层子节点转换并排序
        let topNodes = root.childrenMap.values
            .map { $0.toArchiveTreeNode() }
            .sorted { (a, b) -> Bool in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory && !b.isDirectory
                }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }

        return topNodes
    }

    /// 将树结构中当前可见的节点展平为一维线性列表，供 LazyVStack 100% 虚拟化复用
    static func flattenVisibleNodes(from nodes: [ArchiveTreeNode], depth: Int = 0) -> [FlattenedArchiveRow] {
        var result: [FlattenedArchiveRow] = []
        for node in nodes {
            let row = FlattenedArchiveRow(
                id: node.id,
                node: node,
                depth: depth,
                isDirectory: node.isDirectory,
                isExpanded: node.isExpanded,
                hasChildren: !node.children.isEmpty
            )
            result.append(row)
            if node.isDirectory && node.isExpanded && !node.children.isEmpty {
                result.append(contentsOf: flattenVisibleNodes(from: node.children, depth: depth + 1))
            }
        }
        return result
    }
}

/// 扁平化渲染行模型（纯结构体，轻量无状态，100% 激活 LazyVStack 虚拟化复用）
struct FlattenedArchiveRow: Identifiable, Equatable {
    let id: String
    let node: ArchiveTreeNode
    let depth: Int
    let isDirectory: Bool
    let isExpanded: Bool
    let hasChildren: Bool

    static func == (lhs: FlattenedArchiveRow, rhs: FlattenedArchiveRow) -> Bool {
        lhs.id == rhs.id &&
        lhs.depth == rhs.depth &&
        lhs.isDirectory == rhs.isDirectory &&
        lhs.isExpanded == rhs.isExpanded &&
        lhs.hasChildren == rhs.hasChildren
    }
}
