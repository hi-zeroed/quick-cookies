import Foundation

/// 文件变更事件类型
enum FileLiveChangeEvent: Equatable {
    /// 文件内容或属性发生修改（包含原子替换）
    case modified
    /// 文件被删除或移走
    case deleted
}

/// 基于 macOS 系统内核 DispatchSourceFileSystemObject (kqueue) 的单文件监听器
/// 
/// 核心特性：
/// 1. 0 轮询开销，完全由内核 kqueue 事件唤醒；
/// 2. 支持现代编辑器“原子保存”（Atomic Save：先写临时文件再 rename 覆盖原 inode）的自动重连（Re-arm）与内容刷新；
/// 3. 内置事件防抖（Debounce），避免连续高频写日志压垮主线程；
/// 4. 生命周期安全，停止监听时即刻释放内核文件描述符与 DispatchSource。
final class FileLiveWatcher {
    let filePath: String
    private let targetQueue: DispatchQueue
    private let debounceInterval: TimeInterval
    private let rearmDelay: TimeInterval

    private var fileDescriptor: CInt = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?
    private var rearmWorkItem: DispatchWorkItem?
    private var isStopped: Bool = false

    /// 变更回调
    var onEvent: ((FileLiveChangeEvent) -> Void)?

    /// 初始化监听器
    /// - Parameters:
    ///   - filePath: 目标文件路径
    ///   - targetQueue: 回调分发的目标队列（默认主队列）
    ///   - debounceInterval: 防抖时间间隔（默认 0.1s）
    ///   - rearmDelay: 原子保存替换 inode 后的重连等待间隔（默认 0.06s）
    init(
        filePath: String,
        targetQueue: DispatchQueue = .main,
        debounceInterval: TimeInterval = 0.1,
        rearmDelay: TimeInterval = 0.06
    ) {
        self.filePath = filePath
        self.targetQueue = targetQueue
        self.debounceInterval = debounceInterval
        self.rearmDelay = rearmDelay
    }

    deinit {
        stop()
    }

    /// 启动监听
    /// - Returns: 是否成功打开文件并建立内核监听
    @discardableResult
    func start() -> Bool {
        guard !isStopped else { return false }
        return setupDispatchSource()
    }

    /// 停止监听并释放内核句柄资源
    func stop() {
        guard !isStopped else { return }
        isStopped = true

        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        rearmWorkItem?.cancel()
        rearmWorkItem = nil

        cleanupCurrentSource()
    }

    // MARK: - 内部实现

    private func setupDispatchSource() -> Bool {
        cleanupCurrentSource()

        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else {
            return false
        }

        self.fileDescriptor = fd
        let eventMask: DispatchSource.FileSystemEvent = [.write, .extend, .delete, .rename, .attrib]
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: eventMask,
            queue: targetQueue
        )

        source.setEventHandler { [weak self] in
            guard let self = self, !self.isStopped else { return }
            let flags = source.data

            // 如果文件被删除或重命名（典型原子覆盖保存场景）
            if flags.contains(.delete) || flags.contains(.rename) {
                self.handlePotentialAtomicSave()
            } else if flags.contains(.write) || flags.contains(.extend) || flags.contains(.attrib) {
                self.scheduleDebouncedEvent(.modified)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        self.dispatchSource = source
        source.resume()
        return true
    }

    private func cleanupCurrentSource() {
        if let source = dispatchSource {
            source.cancel()
            self.dispatchSource = nil
            self.fileDescriptor = -1
        } else if fileDescriptor >= 0 {
            close(fileDescriptor)
            self.fileDescriptor = -1
        }
    }

    /// 处理编辑器原子保存（Atomic Save: unlink/rename 原 inode）
    private func handlePotentialAtomicSave() {
        // 先清理旧描述符
        cleanupCurrentSource()

        rearmWorkItem?.cancel()
        let rearmItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isStopped else { return }

            // 检查文件在短延迟后是否依然存在
            if FileManager.default.fileExists(atPath: self.filePath) {
                // 文件依然存在，说明是原子保存覆盖成功，重新绑定新 inode
                let restarted = self.setupDispatchSource()
                if restarted {
                    self.scheduleDebouncedEvent(.modified)
                } else {
                    self.notifyEvent(.deleted)
                }
            } else {
                // 文件真正被删除
                self.notifyEvent(.deleted)
            }
        }

        rearmWorkItem = rearmItem
        targetQueue.asyncAfter(deadline: .now() + rearmDelay, execute: rearmItem)
    }

    /// 防抖派发变更事件
    private func scheduleDebouncedEvent(_ event: FileLiveChangeEvent) {
        debounceWorkItem?.cancel()

        if debounceInterval <= 0 {
            notifyEvent(event)
            return
        }

        let item = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isStopped else { return }
            self.notifyEvent(event)
        }

        debounceWorkItem = item
        targetQueue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    private func notifyEvent(_ event: FileLiveChangeEvent) {
        onEvent?(event)
    }
}
