import Foundation
import Combine

/// 轻量级会话历史导航器，负责管理多文件往复回溯栈（⌘[ / ⌘]）
@MainActor
final class SessionHistoryNavigator: ObservableObject {
    static let shared = SessionHistoryNavigator()

    struct Entry: Equatable {
        let path: String
        let timestamp: Date
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var currentIndex: Int = -1
    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canGoForward: Bool = false

    private var isNavigatingInternally: Bool = false
    private let maxCapacity: Int

    init(maxCapacity: Int = 30) {
        self.maxCapacity = maxCapacity
    }

    var currentPath: String? {
        guard currentIndex >= 0, currentIndex < entries.count else { return nil }
        return entries[currentIndex].path
    }

    /// 记录一次文件预览
    func record(path: String) {
        guard !isNavigatingInternally else { return }

        // 如果与当前栈顶路径一致，不重复压栈
        if let current = currentPath, current == path {
            return
        }

        // 截断当前游标之后的前进历史分支
        if currentIndex >= 0 && currentIndex < entries.count - 1 {
            entries = Array(entries[0...currentIndex])
        }

        entries.append(Entry(path: path, timestamp: Date()))

        // 超出容量 FIFO 淘汰
        if entries.count > maxCapacity {
            entries.removeFirst(entries.count - maxCapacity)
        }

        currentIndex = entries.count - 1
        updateFlags()
    }

    /// 后退到上一个预览文件
    func goBack() -> String? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        updateFlags()
        return entries[currentIndex].path
    }

    /// 前进到下一个预览文件
    func goForward() -> String? {
        guard canGoForward else { return nil }
        currentIndex += 1
        updateFlags()
        return entries[currentIndex].path
    }

    /// 在内部导航时执行操作，避免内部回溯被重复压栈
    func performInternalNavigation<T>(_ block: () throws -> T) rethrows -> T {
        isNavigatingInternally = true
        defer { isNavigatingInternally = false }
        return try block()
    }

    /// 清空会话历史
    func clear() {
        entries.removeAll()
        currentIndex = -1
        updateFlags()
    }

    private func updateFlags() {
        canGoBack = currentIndex > 0
        canGoForward = currentIndex >= 0 && currentIndex < entries.count - 1
    }
}
