import Foundation
import Combine
import AppKit
import ServiceManagement

enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .light: return "亮色".localized()
        case .dark: return "暗色".localized()
        case .system: return "自适应".localized()
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case en = "en"
    case zhHans = "zhHans"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .en: return "English"
        case .zhHans: return "简体中文"
        }
    }
}

class Settings: ObservableObject {
    static let shared = Settings()
    
    // 备份当前语言以供本地化无警报访问
    static var currentLanguage: Language = .en

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
                SettingsWindowController.shared.updateAppearance()
            }
        }
    }
    
    // 多语言配置
    @Published var language: Language {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            Settings.currentLanguage = language
            DispatchQueue.main.async {
                SettingsWindowController.shared.updateTitle()
            }
        }
    }

    // 编辑器字体
    @Published var editorFont: String {
        didSet {
            defaults.set(editorFont, forKey: Keys.editorFont)
        }
    }

    // 开机自启动
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            syncLaunchAtLogin()
        }
    }

    private init() {
        // 先初始化所有 stored properties（使用默认值）
        hotkeyModifiers = Constants.defaultHotkeyModifiers
        hotkeyKeyCode = Constants.defaultHotkeyKeyCode
        fontSize = 14
        showLineNumbers = true
        themeMode = .system
        language = .en
        Settings.currentLanguage = .en
        editorFont = "System Default (Inter)"
        launchAtLogin = false

        // 然后从 UserDefaults 加载实际值
        loadFromUserDefaults()
    }

    private func loadFromUserDefaults() {
        // 快捷键
        if defaults.hasKey(Keys.hotkeyModifiers) {
            hotkeyModifiers = NSEvent.ModifierFlags(
                rawValue: UInt(defaults.integer(forKey: Keys.hotkeyModifiers))
            )
        }

        if defaults.hasKey(Keys.hotkeyKeyCode) {
            hotkeyKeyCode = UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode))
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
        
        // 语言加载与自适应
        if let savedLang = defaults.string(forKey: Keys.language),
           let lang = Language(rawValue: savedLang) {
            language = lang
        } else {
            let preferredLanguage = Locale.preferredLanguages.first ?? ""
            if preferredLanguage.hasPrefix("zh") {
                language = .zhHans
            } else {
                language = .en
            }
        }
        Settings.currentLanguage = language

        // 编辑器字体
        if let savedFont = defaults.string(forKey: Keys.editorFont) {
            editorFont = savedFont
        }

        // 自启动
        if defaults.hasKey(Keys.launchAtLogin) {
            launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
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

    private func syncLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled {
                    try service.register()
                    print("Quick Cookies registered to launch at login successfully.")
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                    print("Quick Cookies unregistered from launch at login successfully.")
                }
            }
        } catch {
            print("Failed to sync launch at login status: \(error)")
        }
    }

    private enum Keys {
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let fontSize = "fontSize"
        static let showLineNumbers = "showLineNumbers"
        static let themeMode = "themeMode"
        static let language = "language"
        static let editorFont = "editorFont"
        static let launchAtLogin = "launchAtLogin"
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

    /// 卡片背景色：暗色下为暗灰，亮色下为纯白
    static let cardBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        } else {
            return NSColor(white: 1.0, alpha: 1.0)
        }
    })

    /// 边框细线颜色
    static let appBorder = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(white: 0.20, alpha: 1.0)
        } else {
            return NSColor(white: 0.88, alpha: 1.0)
        }
    })

    /// 键帽/按钮背景色
    static let kbdBackground = NSColor(name: nil, dynamicProvider: { appearance in
        if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
        } else {
            return NSColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1.0)
        }
    })
}

extension Color {
    static let appBackground = Color(NSColor.appBackground)
    static let appText = Color(NSColor.appText)
    static let toolbarBackground = Color(NSColor.toolbarBackground)
    static let cardBackground = Color(NSColor.cardBackground)
    static let appBorder = Color(NSColor.appBorder)
    static let kbdBackground = Color(NSColor.kbdBackground)
}

struct Localization {
    static func translate(_ key: String, lang: Language) -> String {
        let dict: [String: [Language: String]] = [
            // Onboarding
            "新手向导": [.en: "Onboarding", .zhHans: "新手向导"],
            "下一步": [.en: "Next", .zhHans: "下一步"],
            "上一步": [.en: "Back", .zhHans: "上一步"],
            "开启 Quick Cookies": [.en: "Start Using Quick Cookies", .zhHans: "开启 Quick Cookies"],
            "跳过": [.en: "Skip", .zhHans: "跳过"],
            "秒级代码与文档预览": [.en: "Instant Code & Document Preview", .zhHans: "秒级代码与文档预览"],
            "简单三步，开启效率之旅": [.en: "Three simple steps to start", .zhHans: "简单三步，开启效率之旅"],
            "1. 在 Finder 中选中任意代码或 Markdown 文件": [.en: "1. Select any code or Markdown file in Finder", .zhHans: "1. 在 Finder 中选中任意代码或 Markdown 文件"],
            "2. 在键盘上快速双击 Option 键（或右键选择预览）": [.en: "2. Double-press Option key (or right-click to preview)", .zhHans: "2. 在键盘上快速双击 Option 键（或右键选择预览）"],
            "3. 预览窗口瞬间飞出，支持行号与即时编辑！": [.en: "3. The preview panel flies out with line numbers & live edit!", .zhHans: "3. 预览窗口瞬间飞出，支持行号与即时编辑！"],
            "偏好配置": [.en: "Preferences", .zhHans: "偏好配置"],
            "在正式使用前，您可以进行一些基础的个性化定制：": [.en: "You can customize basic settings before we start:", .zhHans: "在正式使用前，您可以进行一些基础 of 个性化定制："],
            "默认触发快捷键": [.en: "Default Hotkey", .zhHans: "默认触发快捷键"],
            "系统权限授权": [.en: "System Permissions", .zhHans: "系统权限授权"],
            "请授予辅助功能权限，以便能够通过快捷键触发预览。": [.en: "Please grant accessibility permission to enable the global hotkey trigger.", .zhHans: "请授予辅助功能权限，以便能够通过快捷键触发预览。"],
            "（选填）若不授予，您仍可通过 Finder 右键菜单及 Services 菜单直接预览文件。": [.en: "(Optional) If not granted, you can still preview files via Finder right-click and Services menu.", .zhHans: "（选填）若不授予，您仍可通过 Finder 右键菜单及 Services 菜单直接预览文件。"],
            "去授予权限": [.en: "Grant Permission", .zhHans: "去授予权限"],
            "已获得授权": [.en: "Permission Granted", .zhHans: "已获得授权"],
            "授权成功！🎉": [.en: "Successfully Authorized! 🎉", .zhHans: "授权成功！🎉"],
            "免授权降级": [.en: "Permissionless Fallback", .zhHans: "免授权降级"],

            // Appearance
            "APPEARANCE": [.en: "APPEARANCE", .zhHans: "外观"],
            "外观主题": [.en: "Theme Mode", .zhHans: "外观主题"],
            "选择您偏好的界面显示模式": [.en: "Choose your preferred display mode", .zhHans: "选择您偏好的界面显示模式"],
            "亮色": [.en: "Light", .zhHans: "亮色"],
            "暗色": [.en: "Dark", .zhHans: "暗色"],
            "自适应": [.en: "System", .zhHans: "自适应"],
            
            // Typography
            "TYPOGRAPHY": [.en: "TYPOGRAPHY", .zhHans: "排版"],
            "编辑器字体": [.en: "Editor Font", .zhHans: "编辑器字体"],
            "预览和编辑 Markdown 与代码时采用的等宽字体": [.en: "Monospace font for previewing and editing", .zhHans: "预览和编辑 Markdown 与代码时采用的等宽字体"],
            "字体大小": [.en: "Font Size", .zhHans: "字体大小"],
            "System Default (Inter)": [.en: "System Default (Inter)", .zhHans: "系统默认 (Inter)"],
            
            // Keybindings
            "KEYBINDINGS": [.en: "KEYBINDINGS", .zhHans: "快捷键"],
            "全局快捷预览": [.en: "Global Preview", .zhHans: "全局快捷预览"],
            "点击右侧键帽录制自定义组合快捷键": [.en: "Click keys on the right to record custom hotkey", .zhHans: "点击右侧键帽录制自定义组合快捷键"],
            "请在键盘上按下新快捷键...": [.en: "Press new shortcut keys...", .zhHans: "请在键盘上按下新快捷键..."],
            "进入编辑模式": [.en: "Enter Edit Mode", .zhHans: "进入编辑模式"],
            "保存文件修改": [.en: "Save File Changes", .zhHans: "保存文件修改"],
            
            // System
            "SYSTEM": [.en: "SYSTEM", .zhHans: "系统"],
            "开机自启动": [.en: "Launch at Login", .zhHans: "开机自启动"],
            "在您登录 macOS 系统时自动静默启动 Quick Cookies": [.en: "Automatically start QuickCookies in the background when you log in", .zhHans: "在您登录 macOS 系统时自动静默启动 Quick Cookies"],
            "恢复默认设置": [.en: "Restore Default Settings", .zhHans: "恢复默认设置"],
            
            // Language
            "语言": [.en: "Language", .zhHans: "语言"],
            "选择界面的显示语言": [.en: "Choose display language", .zhHans: "选择界面的显示语言"],
            
            // Menu
            "打开选中文件": [.en: "Open Selected File", .zhHans: "打开选中文件"],
            "设置": [.en: "Settings", .zhHans: "设置"],
            "退出": [.en: "Quit", .zhHans: "退出"],
            "双击 Option 或点击此按钮打开 Finder 选中的文件": [.en: "Double-press Option or click here to open the selected Finder file", .zhHans: "双击 Option 或点击此按钮打开 Finder 选中的文件"],
            
            // Content View & Overlay
            "正在定位 Finder 选中文件...": [.en: "Locating selected file in Finder...", .zhHans: "正在定位 Finder 选中文件..."],
            "正在载入高亮...": [.en: "Loading highlight...", .zhHans: "正在载入高亮..."],
            "未检测到选中文件，请在 Finder 中选中文件后重试": [.en: "No file selected. Please select a file in Finder and try again.", .zhHans: "未检测到选中文件，请在 Finder 中选中文件后重试"],
            "不支持的文件类型，仅支持 Markdown、代码或纯文本": [.en: "Unsupported file type. Only Markdown, code, or plain text files are supported.", .zhHans: "不支持的文件类型，仅支持 Markdown、代码或纯文本"],
            "按 Esc 键关闭窗口": [.en: "Press Esc to close window", .zhHans: "按 Esc 键关闭窗口"],
            "未检测到选中文件": [.en: "No file selected", .zhHans: "未检测到选中文件"],
            "定位成功: ": [.en: "Located: ", .zhHans: "定位成功: "],
            "不支持的文件类型: ": [.en: "Unsupported: ", .zhHans: "不支持的文件类型: "],
            "Finder 探测失败": [.en: "Finder detection failed", .zhHans: "Finder 探测失败"],
            "权限请求": [.en: "Permission Request", .zhHans: "权限请求"],
            "需要辅助功能权限": [.en: "Accessibility Permission Required", .zhHans: "需要辅助功能权限"],
            "Quick Cookies 需要辅助功能权限来监听全局快捷键。\n请前往 系统偏好设置 → 安全性与隐私 → 辅助功能，添加 Quick Cookies。": [.en: "QuickCookies requires accessibility permission to listen for global hotkeys.\nPlease go to System Settings -> Privacy & Security -> Accessibility, and enable QuickCookies.", .zhHans: "Quick Cookies 需要辅助功能权限来监听全局快捷键。\n请前往 系统偏好设置 → 安全性与隐私 → 辅助功能，添加 Quick Cookies。"],
            "打开设置": [.en: "Open Settings", .zhHans: "打开设置"],
            "稍后": [.en: "Later", .zhHans: "稍后"],
            
            // Added for Full Localization
            "保存失败": [.en: "Save Failed", .zhHans: "保存失败"],
            "确定": [.en: "OK", .zhHans: "OK"],
            "获取失败": [.en: "Failed to Get", .zhHans: "获取失败"],
            "定位中...": [.en: "Locating...", .zhHans: "定位中..."],
            "⚠️只加载了前1000行": [.en: "⚠️ Loaded first 1000 lines only", .zhHans: "⚠️只加载了前1000行"],
            "进入编辑 (Cmd+E)": [.en: "Enter Edit (Cmd+E)", .zhHans: "进入编辑 (Cmd+E)"],
            "回到预览 (Esc)": [.en: "Back to Preview (Esc)", .zhHans: "回到预览 (Esc)"],
            "保存 (Cmd+S)": [.en: "Save (Cmd+S)", .zhHans: "保存 (Cmd+S)"],
            "读取文件失败": [.en: "Failed to read file", .zhHans: "读取文件失败"],
            "大小": [.en: "Size", .zhHans: "大小"],
            "位置": [.en: "Pos", .zhHans: "位置"],
            "不支持的文件类型": [.en: "Unsupported file type", .zhHans: "不支持的文件类型"],
            "聚焦": [.en: "Focused", .zhHans: "聚焦"],
            "源": [.en: "Source", .zhHans: "源"],
            "Finder PID 失败": [.en: "Finder PID failed", .zhHans: "Finder PID 失败"],
            "未搜寻到选中项": [.en: "No selected item found", .zhHans: "未搜寻到选中项"],
            "坐标/大小属性读取失败": [.en: "Failed to read coordinate/size attributes", .zhHans: "坐标/大小属性读取失败"],
            "默认中心": [.en: "Default Center", .zhHans: "默认中心"],
            "Window 遍历成功": [.en: "Window traversal succeeded", .zhHans: "Window 遍历成功"],
            "未知错误": [.en: "Unknown error", .zhHans: "未知错误"],
            "不支持此文件类型": [.en: "Unsupported file type", .zhHans: "不支持此文件类型"]
        ]
        return dict[key]?[lang] ?? key
    }
}

extension String {
    func localized() -> String {
        return Localization.translate(self, lang: Settings.currentLanguage)
    }
}

extension NSFont {
    /// 获取指定名称的字体，若系统未安装则安全降级到系统默认等宽字体
    static func editorFont(name: String, size: CGFloat) -> NSFont {
        if name == "System Default (Inter)" {
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if let font = NSFont(name: name, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}