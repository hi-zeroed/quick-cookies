import Foundation
import AppKit

enum PreviewOverlayHistoryNavigationDirection: Equatable {
    case back
    case forward
}

enum PreviewOverlayHistoryNavigationKeyPolicy {
    static func direction(
        isVisible: Bool,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags
    ) -> PreviewOverlayHistoryNavigationDirection? {
        guard isVisible else { return nil }

        let relevantModifiers = modifierFlags.intersection([.command, .option, .control, .shift])
        guard relevantModifiers == .command else { return nil }

        switch keyCode {
        case 33: // [ (kVK_ANSI_LeftBracket)
            return .back
        case 30: // ] (kVK_ANSI_RightBracket)
            return .forward
        default:
            return nil
        }
    }
}
