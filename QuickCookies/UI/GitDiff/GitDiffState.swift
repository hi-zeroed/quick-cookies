import Foundation
import SwiftUI
import Combine

/// 仓库未提交改动状态机，负责异步提取差异、管理当前激活的 hunk 以及发布跳转事件
@MainActor
final class GitDiffState: ObservableObject {
    @Published var report: GitDiffReport = .empty
    @Published var isLoading: Bool = false
    @Published var currentHunkIndex: Int = 0

    /// 跳转到指定行的事件发布（通知 CodeView 平滑居中并脉冲高亮）
    let jumpToLineSubject = PassthroughSubject<Int, Never>()

    private(set) var activePath: String?
    private var loadTask: Task<Void, Never>?

    /// 加载指定文件的 Git 差异报告
    func loadDiff(for path: String) {
        self.activePath = path
        loadTask?.cancel()
        currentHunkIndex = 0

        loadTask = Task {
            // 先在主线程通过纯 Swift 检查是否存在 .git 目录，避免非 Git 仓库文件发生无谓的任务开销
            let gitDir = GitRepositoryLocator.findGitDirectory(for: path)
            guard gitDir != nil else {
                if !Task.isCancelled {
                    self.report = .notInRepo
                    self.isLoading = false
                }
                return
            }

            self.isLoading = true
            let diffReport = await GitDiffExtractor.extractDiff(for: path)

            guard !Task.isCancelled, self.activePath == path else { return }
            self.report = diffReport
            self.isLoading = false
            self.currentHunkIndex = 0
        }
    }

    /// 重置状态为初始空白
    func reset() {
        loadTask?.cancel()
        loadTask = nil
        activePath = nil
        report = .empty
        isLoading = false
        currentHunkIndex = 0
    }

    /// 循环跳转到下一个改动块
    func jumpToNextHunk() {
        guard !report.hunks.isEmpty else { return }
        let nextIndex = (currentHunkIndex + 1) % report.hunks.count
        currentHunkIndex = nextIndex
        let hunk = report.hunks[nextIndex]
        jumpToLineSubject.send(hunk.startLine)
    }

    /// 循环跳转到上一个改动块
    func jumpToPreviousHunk() {
        guard !report.hunks.isEmpty else { return }
        let prevIndex = (currentHunkIndex - 1 + report.hunks.count) % report.hunks.count
        currentHunkIndex = prevIndex
        let hunk = report.hunks[prevIndex]
        jumpToLineSubject.send(hunk.startLine)
    }
}
