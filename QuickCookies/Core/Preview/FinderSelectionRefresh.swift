import Foundation

enum FinderSelectionRefreshDecision: Equatable {
    case noChange
    case request(PreviewLaunchRequest)
}

enum FinderSelectionRefresh {
    static func decide(
        previousSelectionPath: String?,
        detectedSelectionPath: String?
    ) -> FinderSelectionRefreshDecision {
        let resolvedSelectionPath = detectedSelectionPath.map { FileUtils.resolveSymlink(at: $0) }

        guard resolvedSelectionPath != previousSelectionPath else {
            return .noChange
        }

        guard let resolvedSelectionPath else {
            // Finder 切换选中项过程中会短暂返回 nil。
            // 预览已打开时应把它视作瞬时探测抖动，而不是立即把现有会话打成“获取失败”。
            if previousSelectionPath != nil {
                return .noChange
            }
            return .request(.refreshFinderSelection())
        }

        return .request(.openPath(resolvedSelectionPath, source: .finderSync))
    }
}
