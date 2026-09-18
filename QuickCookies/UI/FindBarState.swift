import SwiftUI
import Combine

/// 全文搜索条状态机
/// NOTE: FindBarState 深度服务于 CodeView 与 MarkdownView 的 Combine 防抖流 ($query.debounce, $isPresented)，
/// 保持 ObservableObject 契约以维持底层 AppKit / WebKit 的 Coordinator 订阅与防抖生命周期稳定。
public final class FindBarState: ObservableObject {
    @Published public var isPresented: Bool = false
    @Published public var query: String = ""
    @Published public var currentMatchIndex: Int = 0
    @Published public var totalMatches: Int = 0

    /// NOTE: 保留 Combine PassthroughSubject 用于向 AppKit NSTextView 派发瞬时搜索指令
    public let findNextTrigger = PassthroughSubject<Void, Never>()
    public let findPreviousTrigger = PassthroughSubject<Void, Never>()

    public init() {}

    public func present() {
        isPresented = true
    }

    public func dismiss() {
        isPresented = false
        query = ""
        currentMatchIndex = 0
        totalMatches = 0
    }

    public func next() {
        findNextTrigger.send()
    }

    public func previous() {
        findPreviousTrigger.send()
    }

    public var matchCountText: String {
        guard !query.isEmpty else { return "" }
        if totalMatches == 0 {
            return "0 / 0"
        }
        return "\(currentMatchIndex) / \(totalMatches)"
    }
}
