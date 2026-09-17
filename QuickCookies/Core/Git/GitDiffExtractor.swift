import Foundation

/// Git 差异提取与解析引擎
final class GitDiffExtractor {
    /// 异步获取目标文件的 Git 未提交改动报告
    static func extractDiff(for filePath: String, totalLines: Int = 0) async -> GitDiffReport {
        guard let location = GitRepositoryLocator.locateRepository(for: filePath) else {
            return .notInRepo
        }

        return await Task.detached(priority: .userInitiated) { () -> GitDiffReport in
            // 1. 检查 status 是否为未跟踪（Untracked）
            let statusOutput = runGitCommand(
                args: ["status", "--porcelain=v1", "-z", "--", location.relativePath],
                workingDir: location.repoRootURL
            )

            if let status = statusOutput, status.hasPrefix("??") {
                // 全新未跟踪文件：全部视作新增
                var changed: [Int: GitDiffLineType] = [:]
                let count = max(1, totalLines)
                for line in 1...count {
                    changed[line] = .added
                }
                let hunk = GitDiffHunk(
                    type: .added,
                    startLine: 1,
                    lineCount: count,
                    oldStartLine: 0,
                    oldLineCount: 0
                )
                return GitDiffReport(
                    status: .untracked,
                    additions: count,
                    deletions: 0,
                    hunks: [hunk],
                    changedLines: changed
                )
            }

            // 2. 执行 git diff -U0 HEAD，对比工作区与 HEAD（同时囊括 staged 与 unstaged 改动）
            let diffOutput = runGitCommand(
                args: ["diff", "--no-color", "-U0", "HEAD", "--", location.relativePath],
                workingDir: location.repoRootURL
            ) ?? ""

            return parseUnifiedDiff(output: diffOutput, isUntracked: false, totalLines: totalLines)
        }.value
    }

    /// 便捷重载：根据文件状态与 Unified Diff 文本解析报告
    static func parseUnifiedDiff(_ output: String, fileStatus: GitFileStatus = .modified, totalLines: Int = 0) -> GitDiffReport {
        if fileStatus == .untracked {
            return parseUnifiedDiff(output: output, isUntracked: true, totalLines: totalLines)
        }
        if fileStatus == .clean && output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .empty
        }
        return parseUnifiedDiff(output: output, isUntracked: false, totalLines: totalLines)
    }

    /// 纯函数解析 Unified Diff (-U0) 文本输出
    static func parseUnifiedDiff(output: String, isUntracked: Bool, totalLines: Int) -> GitDiffReport {
        if isUntracked {
            var changed: [Int: GitDiffLineType] = [:]
            let count = max(1, totalLines)
            for line in 1...count {
                changed[line] = .added
            }
            let hunk = GitDiffHunk(
                type: .added,
                startLine: 1,
                lineCount: count,
                oldStartLine: 0,
                oldLineCount: 0
            )
            return GitDiffReport(
                status: .untracked,
                additions: count,
                deletions: 0,
                hunks: [hunk],
                changedLines: changed
            )
        }

        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .empty
        }

        var additions = 0
        var deletions = 0
        var hunks: [GitDiffHunk] = []
        var changedLines: [Int: GitDiffLineType] = [:]

        let lines = output.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // 匹配 @@ -oldStart,oldCount +newStart,newCount @@
            if line.hasPrefix("@@ ") {
                if let hunk = parseHunkHeader(line) {
                    hunks.append(hunk)

                    switch hunk.type {
                    case .added:
                        let count = max(1, hunk.lineCount)
                        for l in hunk.startLine..<(hunk.startLine + count) {
                            changedLines[l] = .added
                        }
                    case .modified:
                        let count = max(1, hunk.lineCount)
                        for l in hunk.startLine..<(hunk.startLine + count) {
                            changedLines[l] = .modified
                        }
                    case .deleted:
                        // 删除行在目标文件中位于 startLine 或其前
                        let targetLine = max(1, hunk.startLine)
                        changedLines[targetLine] = .deleted
                    }
                }
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                additions += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                deletions += 1
            }

            i += 1
        }

        let status: GitFileStatus = (additions > 0 || deletions > 0 || !hunks.isEmpty) ? .modified : .clean

        return GitDiffReport(
            status: status,
            additions: additions,
            deletions: deletions,
            hunks: hunks,
            changedLines: changedLines
        )
    }

    /// 解析 @@ -a,b +c,d @@ 块头
    private static func parseHunkHeader(_ header: String) -> GitDiffHunk? {
        // 查找两个 @@ 之间的内容
        guard let firstRange = header.range(of: "@@ -"),
              let secondIndex = header.range(of: " @@", range: firstRange.upperBound..<header.endIndex) else {
            return nil
        }

        let rangeContent = String(header[firstRange.upperBound..<secondIndex.lowerBound])
        let parts = rangeContent.components(separatedBy: " +")
        guard parts.count == 2 else { return nil }

        let oldPart = parts[0] // e.g. "14,3" or "10"
        let newPart = parts[1] // e.g. "15,2" or "11"

        let oldComponents = oldPart.components(separatedBy: ",")
        let oldStart = Int(oldComponents[0]) ?? 0
        let oldLen = oldComponents.count > 1 ? (Int(oldComponents[1]) ?? 1) : 1

        let newComponents = newPart.components(separatedBy: ",")
        let newStart = Int(newComponents[0]) ?? 0
        let newLen = newComponents.count > 1 ? (Int(newComponents[1]) ?? 1) : 1

        let type: GitDiffLineType
        if oldLen == 0 && newLen > 0 {
            type = .added
        } else if oldLen > 0 && newLen == 0 {
            type = .deleted
        } else {
            type = .modified
        }

        return GitDiffHunk(
            type: type,
            startLine: newStart,
            lineCount: newLen,
            oldStartLine: oldStart,
            oldLineCount: oldLen
        )
    }

    /// 执行只读 git 子命令（超时 800ms 兜底）
    private static func runGitCommand(args: [String], workingDir: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = workingDir

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            
            // 800ms 超时保护
            let deadline = DispatchTime.now() + .milliseconds(800)
            while process.isRunning {
                if DispatchTime.now() > deadline {
                    process.terminate()
                    return nil
                }
                usleep(5000) // 5ms
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
