import Foundation
import Combine
import AppKit

class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    // 快捷键配置
    @Published var hotkeyModifiers: NSEvent.ModifierFlags
    @Published var hotkeyKeyCode: UInt16

    // 外观配置
    @Published var fontSize: CGFloat
    @Published var showLineNumbers: Bool

    private init() {
        // 先初始化所有 stored properties（使用默认值）
        hotkeyModifiers = Constants.defaultHotkeyModifiers
        hotkeyKeyCode = Constants.defaultHotkeyKeyCode
        fontSize = 14
        showLineNumbers = true

        // 然后从 UserDefaults 加载实际值
        loadFromUserDefaults()
    }

    private func loadFromUserDefaults() {
        // 快捷键
        let savedModifiers = NSEvent.ModifierFlags(
            rawValue: UInt(defaults.integer(forKey: Keys.hotkeyModifiers))
        )
        if savedModifiers.rawValue != 0 {
            hotkeyModifiers = savedModifiers
        }

        let savedKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
        if savedKeyCode != 0 {
            hotkeyKeyCode = savedKeyCode
        }

        // 外观
        let savedFontSize = CGFloat(defaults.float(forKey: Keys.fontSize))
        if savedFontSize != 0 {
            fontSize = savedFontSize
        }

        if defaults.hasKey(Keys.showLineNumbers) {
            showLineNumbers = defaults.bool(forKey: Keys.showLineNumbers)
        }
    }

    func saveHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        hotkeyModifiers = modifiers
        hotkeyKeyCode = keyCode
        defaults.set(modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        defaults.set(Int(keyCode), forKey: Keys.hotkeyKeyCode)
    }

    func saveFontSize(_ size: CGFloat) {
        fontSize = size
        defaults.set(Float(size), forKey: Keys.fontSize)
    }

    private enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let fontSize = "fontSize"
        static let showLineNumbers = "showLineNumbers"
    }
}

extension UserDefaults {
    func hasKey(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }
}