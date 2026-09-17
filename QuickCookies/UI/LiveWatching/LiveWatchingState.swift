import Foundation
import SwiftUI
import Combine

/// 实时文件监听与日志追尾状态机
@MainActor
final class LiveWatchingState: ObservableObject {
    @Published var isWatching: Bool = false
    @Published var isLiveTailMode: Bool = false
    @Published var isFollowingTail: Bool = true
    @Published var hasUnreadAppendsWhilePaused: Bool = false
    @Published var isHotReloading: Bool = false

    /// 滚动至底部的触发事件（通知 CodeView 平滑触底）
    let scrollToBottomSubject = PassthroughSubject<Void, Never>()
    /// 普通代码/配置文件修改事件（通知 ContentView 保持滚动位置热重载）
    let fileModifiedSubject = PassthroughSubject<Void, Never>()
    /// 日志新增内容增量追加事件（通知 ContentView 增量追加文本）
    let logAppendedSubject = PassthroughSubject<String, Never>()
    /// 日志文件被清空截断事件（通知 ContentView 全量重载）
    let logTruncatedSubject = PassthroughSubject<Void, Never>()

    private var watcher: FileLiveWatcher?
    private var tailEngine: FileLiveTailEngine?
    private(set) var activePath: String?

    deinit {
        watcher?.stop()
    }

    /// 启动对当前预览文件的监听
    /// - Parameters:
    ///   - path: 文件绝对路径
    ///   - initialFileSize: 当前已读取或初始文件大小（用于初始化增量尾随偏移）
    func start(for path: String, initialFileSize: UInt64) {
        stop()

        self.activePath = path
        let isLog = FileLiveTailEngine.isLogFile(path: path)
        self.isLiveTailMode = isLog
        self.isFollowingTail = true
        self.hasUnreadAppendsWhilePaused = false

        if isLog {
            self.tailEngine = FileLiveTailEngine(initialOffset: initialFileSize)
        } else {
            self.tailEngine = nil
        }

        let watcher = FileLiveWatcher(filePath: path)
        watcher.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                self?.handleWatcherEvent(event)
            }
        }

        if watcher.start() {
            self.watcher = watcher
            self.isWatching = true
        } else {
            self.isWatching = false
        }
    }

    /// 停止监听并重置状态
    func stop() {
        watcher?.stop()
        watcher = nil
        tailEngine = nil
        activePath = nil
        isWatching = false
        isLiveTailMode = false
        isFollowingTail = true
        hasUnreadAppendsWhilePaused = false
        isHotReloading = false
    }

    /// 切换自动跟随状态
    func toggleFollowing() {
        guard isLiveTailMode else { return }
        isFollowingTail.toggle()
        if isFollowingTail {
            hasUnreadAppendsWhilePaused = false
            scrollToBottomSubject.send(())
        }
    }

    /// 用户在界面上手动滚动偏离底部
    func userScrolledAwayFromBottom() {
        guard isLiveTailMode, isFollowingTail else { return }
        isFollowingTail = false
    }

    /// 用户滚回触底
    func userScrolledToBottom() {
        guard isLiveTailMode else { return }
        if !isFollowingTail {
            isFollowingTail = true
        }
        hasUnreadAppendsWhilePaused = false
    }

    /// 外部同步已加载文本偏移量（比如首次增量分段读取后）
    func syncOffset(_ offset: UInt64) {
        tailEngine?.resetOffset(to: offset)
    }

    // MARK: - 内部事件分发

    private func handleWatcherEvent(_ event: FileLiveChangeEvent) {
        guard isWatching, let path = activePath else { return }

        switch event {
        case .deleted:
            // 文件被外部删除，停止监听
            stop()

        case .modified:
            if isLiveTailMode, let tailEngine = tailEngine {
                // 日志追尾增量读取
                let result = tailEngine.readAppendedText(at: path)
                switch result {
                case .appended(let newText, _):
                    if isFollowingTail {
                        hasUnreadAppendsWhilePaused = false
                    } else {
                        hasUnreadAppendsWhilePaused = true
                    }
                    logAppendedSubject.send(newText)
                    if isFollowingTail {
                        scrollToBottomSubject.send(())
                    }

                case .truncated:
                    hasUnreadAppendsWhilePaused = false
                    logTruncatedSubject.send(())

                case .noChange, .failure:
                    break
                }
            } else {
                // 普通代码/配置文件热重载
                isHotReloading = true
                fileModifiedSubject.send(())
                // 1 秒后解除微动画热重载指示
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.isHotReloading = false
                }
            }
        }
    }
}
