import Foundation

/// Git 仓库位置与相对文件路径
struct GitRepoLocation: Equatable {
    let repoRootURL: URL
    let relativePath: String
}

/// 纯 Swift 极速 Git 仓库定位器
///
/// 核心特性：
/// 1. 0 进程与 0 外部调用开销，直接沿文件系统目录树向上层层探测 `.git` 目录或文件；
/// 2. 完美支持 Git Submodule、Git Worktree 与标准 Git 仓库；
/// 3. 若文件不在 Git 仓库内，瞬间返回 nil，绝不拖慢文件预览首屏。
final class GitRepositoryLocator {
    /// 向上查找包含目标文件的 Git 仓库根目录与相对路径
    /// - Parameter filePath: 目标文件绝对路径
    /// - Returns: 仓库根 URL 及相对路径，若不在 Git 仓库中则返回 nil
    static func locateRepository(for filePath: String) -> GitRepoLocation? {
        let fileURL = URL(fileURLWithPath: filePath).standardized
        var currentDir = fileURL.deletingLastPathComponent()

        var depth = 0
        let maxDepth = 25

        while depth < maxDepth {
            let gitPath = currentDir.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitPath.path) {
                // 找到 .git（无论是目录还是 worktree 文本文件指针）
                let rootPath = currentDir.path
                let fullPath = fileURL.path
                if fullPath.hasPrefix(rootPath) {
                    var relative = String(fullPath.dropFirst(rootPath.count))
                    if relative.hasPrefix("/") {
                        relative.removeFirst()
                    }
                    return GitRepoLocation(repoRootURL: currentDir, relativePath: relative)
                }
                return nil
            }

            let parent = currentDir.deletingLastPathComponent()
            if parent.path == currentDir.path {
                // 已到达根目录 /
                break
            }
            currentDir = parent
            depth += 1
        }

        return nil
    }

    /// 查找包含目标文件的 .git 目录或指针文件 URL
    static func findGitDirectory(for filePath: String) -> URL? {
        let fileURL = URL(fileURLWithPath: filePath).standardized
        var currentDir = fileURL.deletingLastPathComponent()
        var depth = 0
        let maxDepth = 25

        while depth < maxDepth {
            let gitPath = currentDir.appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: gitPath.path) {
                return gitPath
            }
            let parent = currentDir.deletingLastPathComponent()
            if parent.path == currentDir.path {
                break
            }
            currentDir = parent
            depth += 1
        }
        return nil
    }

    /// 解析仓库上下文（根 URL 及相对路径）
    static func resolveContext(for filePath: String) -> GitRepoLocation? {
        locateRepository(for: filePath)
    }
}
