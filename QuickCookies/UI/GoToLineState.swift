import SwiftUI
import Combine

public final class GoToLineState: ObservableObject {
    @Published public var isPresented: Bool = false
    @Published public var inputLine: String = ""
    @Published public var totalLines: Int = 1
    @Published public var errorMessage: String? = nil

    /// 发送跳转目标行号（1-indexed）
    public let jumpToLineTrigger = PassthroughSubject<Int, Never>()

    public init() {}

    /// 安全更新总行数，如果数值未改变则不触发 objectWillChange 重新渲染
    public func updateTotalLines(_ lines: Int) {
        let clamped = max(1, lines)
        guard totalLines != clamped else { return }
        totalLines = clamped
    }

    public func present(totalLines: Int? = nil) {
        if let totalLines = totalLines {
            updateTotalLines(totalLines)
        }
        self.inputLine = ""
        self.errorMessage = nil
        self.isPresented = true
    }

    public func dismiss() {
        isPresented = false
        inputLine = ""
        errorMessage = nil
    }

    public func submit() {
        let trimmed = inputLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line = Int(trimmed), line > 0 else {
            errorMessage = "Invalid line number".localized()
            return
        }

        // 安全限制在合法行号区间内
        let clampedLine = min(line, totalLines)
        jumpToLineTrigger.send(clampedLine)
        dismiss()
    }
}
