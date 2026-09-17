import Foundation

/// Git 文件变更状态
enum GitFileStatus: Equatable {
    /// 干净、无任何未提交改动
    case clean
    /// 有未提交改动（修改、暂存或未暂存）
    case modified
    /// 全新未跟踪文件
    case untracked
    /// 不在 Git 仓库内
    case notInRepo
}

/// 差异行类型
enum GitDiffLineType: Equatable {
    /// 新增行（绿色）
    case added
    /// 修改行（橙色）
    case modified
    /// 删除行（红色标示）
    case deleted
}

/// 差异代码块（Hunk）
struct GitDiffHunk: Equatable {
    let type: GitDiffLineType
    /// 新文件中的起始行（1-indexed）
    let startLine: Int
    /// 影响的行数（若纯删除则为 0）
    let lineCount: Int
    /// 旧文件中的起始行
    let oldStartLine: Int
    /// 旧文件中影响的行数
    let oldLineCount: Int

    /// 目标行号范围
    var lineRange: ClosedRange<Int> {
        if lineCount <= 1 {
            return startLine...startLine
        }
        return startLine...(startLine + lineCount - 1)
    }
}

/// 单个文件的完整 Git 差异报告
struct GitDiffReport: Equatable {
    let status: GitFileStatus
    let additions: Int
    let deletions: Int
    let hunks: [GitDiffHunk]
    let changedLines: [Int: GitDiffLineType]

    static let empty = GitDiffReport(
        status: .clean,
        additions: 0,
        deletions: 0,
        hunks: [],
        changedLines: [:]
    )

    static let notInRepo = GitDiffReport(
        status: .notInRepo,
        additions: 0,
        deletions: 0,
        hunks: [],
        changedLines: [:]
    )

    /// 徽章单行摘要文本
    var summaryBadgeText: String {
        switch status {
        case .notInRepo, .clean:
            return ""
        case .untracked:
            return "UNTRACKED"
        case .modified:
            var parts: [String] = []
            if additions > 0 {
                parts.append("+\(additions)")
            }
            if deletions > 0 {
                parts.append("-\(deletions)")
            }
            return parts.joined(separator: " ")
        }
    }

    /// 查找当前行号之后的下一个改动块（循环跳转）
    func nextHunk(after currentLine: Int) -> GitDiffHunk? {
        guard !hunks.isEmpty else { return nil }
        // 先找 startLine 大于 currentLine 的第一个
        if let next = hunks.first(where: { $0.startLine > currentLine }) {
            return next
        }
        // 循环回第一个
        return hunks.first
    }

    /// 查找当前行号之前的上一个改动块（循环跳转）
    func previousHunk(before currentLine: Int) -> GitDiffHunk? {
        guard !hunks.isEmpty else { return nil }
        if let prev = hunks.last(where: { $0.startLine < currentLine }) {
            return prev
        }
        // 循环到最后一个
        return hunks.last
    }
}
