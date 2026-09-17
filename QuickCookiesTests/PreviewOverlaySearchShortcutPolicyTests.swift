import XCTest
import AppKit
@testable import QuickCookies

final class PreviewOverlaySearchShortcutPolicyTests: XCTestCase {
    func test_optionF_triggersSearch_regardlessOfKeyWindow() {
        // Option + F (keyCode 3) 无论是否为 Key Window (例如 Finder 前台时) 均触发
        let triggersWhenNotKey = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: .option,
            isKeyWindow: false
        )
        XCTAssertTrue(triggersWhenNotKey)

        let triggersWhenKey = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: .option,
            isKeyWindow: true
        )
        XCTAssertTrue(triggersWhenKey)
    }

    func test_commandF_triggersSearch_onlyWhenKeyWindow() {
        // Command + F 仅在自身已获得焦点 (Key Window) 时宽容兼容触发，避免在 Finder 前台时与 Finder 菜单冲突
        let triggersWhenNotKey = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: .command,
            isKeyWindow: false
        )
        XCTAssertFalse(triggersWhenNotKey)

        let triggersWhenKey = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: .command,
            isKeyWindow: true
        )
        XCTAssertTrue(triggersWhenKey)
    }

    func test_otherKeyCodes_doNotTriggerSearch() {
        // 非 'F' 键 (keyCode != 3) 即使带修饰键也不应触发
        let arrowDownWithOption = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 125,
            modifierFlags: .option,
            isKeyWindow: true
        )
        XCTAssertFalse(arrowDownWithOption)

        let arrowUpWithCommand = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 126,
            modifierFlags: .command,
            isKeyWindow: true
        )
        XCTAssertFalse(arrowUpWithCommand)
    }

    func test_additionalModifiers_doNotTriggerSearch() {
        // 含有其他无关修饰键时不触发 (例如 Option+Command+F, Control+Option+F 等)
        let optionCommandF = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: [.option, .command],
            isKeyWindow: true
        )
        XCTAssertFalse(optionCommandF)

        let controlOptionF = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: [.control, .option],
            isKeyWindow: true
        )
        XCTAssertFalse(controlOptionF)

        let shiftOptionF = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: [.shift, .option],
            isKeyWindow: true
        )
        XCTAssertFalse(shiftOptionF)
    }

    func test_noModifiers_doesNotTriggerSearch() {
        // 纯字母按键不触发
        let plainF = PreviewOverlaySearchShortcutPolicy.shouldTriggerSearch(
            keyCode: 3,
            modifierFlags: [],
            isKeyWindow: true
        )
        XCTAssertFalse(plainF)
    }

    func test_keybindings_localization_coversAllShortcuts() {
        let keysToCheck = [
            "KEYBINDINGS",
            "Global Preview",
            "Click keys on the right to record custom hotkey",
            "Press new shortcut keys...",
            "Find in File",
            "Search in text, code and Markdown",
            "Previous / Next Match",
            "Jump between search results",
            "Open with Default App",
            "Open current file in external editor",
            "Reveal in Finder",
            "Locate and highlight current file in Finder",
            "Copy File Path",
            "Copy full physical path to clipboard",
            "Navigate Files in Finder",
            "Switch to previous or next file seamlessly",
            "Navigate History",
            "Switch to previously previewed files",
            "Dismiss Window",
            "Close overlay and return focus to Finder",
            "General",
            "Appearance",
            "Keybindings",
            "About",
            "LANGUAGE",
            "GLOBAL HOTKEY",
            "WORKFLOW SHORTCUTS",
            "Typography Preview",
            "Global Preview Hotkey",
            "Toggle overlay instantly when files are selected in Finder",
            "Reset Hotkey",
            "Workflow Shortcuts",
            "Frequently used keystrokes in preview overlay",
            "Instant Card Preview for macOS",
            "Zero-Accessibility Architecture",
            "0ms Instant Streaming Highlight",
            "External App Seamless Handoff",
            "Re-open Onboarding",
            "View on GitHub",
            "Released under the MIT License",
            "Released under the GNU GPL v3 License"
        ]

        for key in keysToCheck {
            let enTranslation = Localization.translate(key, lang: .en)
            let zhTranslation = Localization.translate(key, lang: .zhHans)

            XCTAssertFalse(enTranslation.isEmpty, "Missing English translation for: \(key)")
            XCTAssertFalse(zhTranslation.isEmpty, "Missing Chinese translation for: \(key)")
            // 确保中文翻译不是直接回退为英文 key 原文
            XCTAssertNotEqual(zhTranslation, key, "Chinese translation missing or falling back to key for: \(key)")
        }
    }
}
