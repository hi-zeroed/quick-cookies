import Foundation

/// 深度工程元数据展示单项
struct TelemetryItem: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let tooltip: String?

    init(id: String, label: String, value: String, tooltip: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.tooltip = tooltip
    }
}

/// 深度工程元数据报告
struct TelemetryReport: Equatable {
    let items: [TelemetryItem]

    init(items: [TelemetryItem]) {
        self.items = items
    }

    /// 格式化为单行极简文本，供复制到剪贴板
    var summaryText: String {
        items.map { "\($0.label): \($0.value)" }.joined(separator: " · ")
    }

    var isEmpty: Bool {
        items.isEmpty
    }
}
