import SwiftUI
import Combine

public final class FindBarState: ObservableObject {
    @Published public var isPresented: Bool = false
    @Published public var query: String = ""
    @Published public var currentMatchIndex: Int = 0
    @Published public var totalMatches: Int = 0

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
