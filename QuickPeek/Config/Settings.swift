import Foundation
import Combine
import AppKit

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "亮色"
        case .dark: return "暗色"
        case .system: return "自适应"
        }
    }
}

class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    // 快捷键配置
    @Published var hotkeyModifiers: NSEvent.ModifierFlags
    @Published var hotkeyKeyCode: UInt16

    // 外观配置
    @Published var fontSize: CGFloat
    @Published var showLineNumbers: Bool
    @Published var themeMode: ThemeMode {
        didSet {
            defaults.set(themeMode.rawValue, forKey: Keys.themeMode)
            // 实时通知已打开窗口更新外观模式
            DispatchQueue.main.async {
                QuickLookOverlay.shared.updateAppearance()
            }
        }
    }

    private init() {
        // 先初始化所有 stored properties（使用默认值）
        hotkeyModifiers = Constants.defaultHotkeyModifiers
        hotkeyKeyCode = Constants.defaultHotkeyKeyCode
        fontSize = 14
        showLineNumbers = true
        themeMode = .system

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

        if let savedTheme = defaults.string(forKey: Keys.themeMode),
           let mode = ThemeMode(rawValue: savedTheme) {
            themeMode = mode
        } else {
            themeMode = .system
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
        static let themeMode = "themeMode"
    }
}

extension UserDefaults {
    func hasKey(_ key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

import SwiftUI

extension NSColor {
    /// 整体背景色：暗色下为极深灰色，亮色下为优雅淡灰白
    static let appBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        } else {
            return NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        }
    })
    
    /// 正文文本颜色
    static let appText = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(white: 0.85, alpha: 1.0)
        } else {
            return NSColor(white: 0.15, alpha: 1.0)
        }
    })
    
    /// 工具栏背景色
    static let toolbarBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)
        } else {
            return NSColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        }
    })
}

extension Color {
    static let appBackground = Color(NSColor.appBackground)
    static let appText = Color(NSColor.appText)
    static let toolbarBackground = Color(NSColor.toolbarBackground)
}