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
        case .light: return "Light".localized()
        case .dark: return "Dark".localized()
        case .system: return "System".localized()
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case system = "system"
    case en = "en"
    case zhHans = "zhHans"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "Follow System".localized()
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
            Settings.currentLanguage = (language == Language.system) ? Settings.getSystemLanguage() : language
            DispatchQueue.main.async {
                SettingsWindowController.shared.updateTitle()
            }
        }
    }

    static func getSystemLanguage() -> Language {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        if preferredLanguage.hasPrefix("zh") {
            return .zhHans
        } else {
            return .en
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
        fontSize = 13
        showLineNumbers = true
        themeMode = .system
        language = Language.system
        Settings.currentLanguage = Settings.getSystemLanguage()
        editorFont = "JetBrains Mono"
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
            language = Language.system
        }
        Settings.currentLanguage = (language == Language.system) ? Settings.getSystemLanguage() : language

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
            "Onboarding": [.en: "Onboarding", .zhHans: "新手向导"],
            "Next": [.en: "Next", .zhHans: "下一步"],
            "Back": [.en: "Back", .zhHans: "上一步"],
            "Start Using Quick Cookies": [.en: "Start Using Quick Cookies", .zhHans: "开启 Quick Cookies"],
            "Skip": [.en: "Skip", .zhHans: "跳过"],
            "Instant Code & Document Preview": [.en: "Instant Code & Document Preview", .zhHans: "秒级代码与文档预览"],
            "Three simple steps to start": [.en: "Three simple steps to start", .zhHans: "简单三步，开启效率之旅"],
            "1. Select any code or Markdown file in Finder": [.en: "1. Select any code or Markdown file in Finder", .zhHans: "1. 在 Finder 中选中任意代码或 Markdown 文件"],
            "2. Double-press Option key (or right-click to preview)": [.en: "2. Double-press Option key (or right-click to preview)", .zhHans: "2. 在键盘上快速双击 Option 键（或右键选择预览）"],
            "3. The preview panel flies out with line numbers & live edit!": [.en: "3. The preview panel flies out with line numbers & live edit!", .zhHans: "3. 预览窗口瞬间飞出，支持行号与即时编辑！"],
            "Preferences": [.en: "Preferences", .zhHans: "偏好配置"],
            "You can customize basic settings before we start:": [.en: "You can customize basic settings before we start:", .zhHans: "在正式使用前，您可以进行一些基础的个性化定制："],
            "Default Hotkey": [.en: "Default Hotkey", .zhHans: "默认触发快捷键"],
            "System Permissions": [.en: "System Permissions", .zhHans: "系统权限授权"],
            "Please grant accessibility permission to enable the global hotkey trigger.": [.en: "Please grant accessibility permission to enable the global hotkey trigger.", .zhHans: "请授予辅助功能权限，以便能够通过快捷键触发预览。"],
            "(Optional) If not granted, you can still preview files via Finder right-click and Services menu.": [.en: "(Optional) If not granted, you can still preview files via Finder right-click and Services menu.", .zhHans: "（选填）若不授予，您仍可通过 Finder 右键菜单及 Services 菜单直接预览文件。"],
            "Grant Permission": [.en: "Grant Permission", .zhHans: "去授予权限"],
            "Permission Granted": [.en: "Permission Granted", .zhHans: "已获得授权"],
            "Successfully Authorized! 🎉": [.en: "Successfully Authorized! 🎉", .zhHans: "授权成功！🎉"],
            "Permissionless Fallback": [.en: "Permissionless Fallback", .zhHans: "免授权降级"],
            
            // New Onboarding Additions
            "Instant Preview": [.en: "Instant Preview", .zhHans: "极速唤起预览"],
            "2. Quickly double-press": [.en: "2. Quickly double-press", .zhHans: "2. 键盘上快速双击"],
            "3. The preview window flies out instantly, supporting live edit & save": [.en: "3. The preview window flies out instantly, supporting live edit & save", .zhHans: "3. 预览窗口瞬间飞出，支持即时修改与保存"],
            "Personalized Settings": [.en: "Personalized Settings", .zhHans: "个性化定制"],
            "Before getting started, you can customize some core preferences:": [.en: "Before getting started, you can customize some core preferences:", .zhHans: "正式使用前，您可以进行一些核心的偏好设定："],
            "Adapt to your system appearance": [.en: "Adapt to your system appearance", .zhHans: "自适应匹配您的系统外观"],
            "Interface Language": [.en: "Interface Language", .zhHans: "界面语言"],
            "Support dynamic toggle between English & Chinese": [.en: "Support dynamic toggle between English & Chinese", .zhHans: "支持中文与 English 热切换"],
            "Silently start in the background when you log in": [.en: "Silently start in the background when you log in", .zhHans: "登录系统时自动静默在后台启动"],
            "Running Mode & Permissions": [.en: "Running Mode & Permissions", .zhHans: "运行模式与权限配置"],
            "QuickCookies supports running without high-level permissions. Choose as you need:": [.en: "QuickCookies supports running without high-level permissions. Choose as you need:", .zhHans: "Quick Cookies 支持免系统高级权限运行，您可按需选择："],
            "Zero-Permission Mode (Recommended)": [.en: "Zero-Permission Mode (Recommended)", .zhHans: "零权限模式 (推荐)"],
            "Run with 0 privacy risk using Finder extension. Support right-click menu & default double-press Option.": [.en: "Run with 0 privacy risk using Finder extension. Support right-click menu & default double-press Option.", .zhHans: "借助系统 Finder 扩展，零隐私风险运行。支持右键菜单预览和默认双击起跳预览。"],
            "Advanced Animation Mode": [.en: "Advanced Animation Mode", .zhHans: "高级动画模式"],
            "With Accessibility enabled, the preview window will fly from the actual file icon position with spring physics.": [.en: "With Accessibility enabled, the preview window will fly from the actual file icon position with spring physics.", .zhHans: "开启辅助功能后，预览窗将直接从 Finder 文件图标的原位飞出/缩回，交互极具连贯物理弹簧质感。"],
            "Grant Accessibility": [.en: "Grant Accessibility", .zhHans: "授予辅助功能"],
            "Enable Finder Extension": [.en: "Enable Finder Extension", .zhHans: "启用 Finder 扩展"],
            "Full Disk Access": [.en: "Full Disk Access", .zhHans: "所有文件夹访问"],
            "Grant Full Disk Access to avoid folder permission prompts.": [.en: "Grant Full Disk Access to avoid folder permission prompts.", .zhHans: "授权完全磁盘访问，消除受保护文件夹的频繁弹窗。"],
            "Grant Access": [.en: "Grant Access", .zhHans: "去授权"],
            "Attempted": [.en: "Attempted", .zhHans: "已尝试启用"],
            "Enable": [.en: "Enable", .zhHans: "去启用"],
            "Accessibility": [.en: "Accessibility", .zhHans: "辅助功能"],
            "Accessibility Permission": [.en: "Accessibility", .zhHans: "辅助功能权限"],
            "Authorized": [.en: "Authorized", .zhHans: "已授权"],
            "Unauthorized": [.en: "Unauthorized", .zhHans: "未授权"],
            "Checking...": [.en: "Checking...", .zhHans: "正在检测..."],
            "Starting...": [.en: "Starting...", .zhHans: "正在启动..."],
            "Full Disk Access Permission": [.en: "Full Disk Access", .zhHans: "所有文件夹访问权限"],
            "Grant Full Disk Access to eliminate sandbox popups": [.en: "Grant Full Disk Access to eliminate sandbox popups", .zhHans: "授权完全磁盘访问，消除系统安全弹窗"],
            "Used for global hotkeys & advanced animations": [.en: "Used for global hotkeys & advanced animations", .zhHans: "用于全局快捷键与高级动画定位"],

            // Appearance
            "APPEARANCE": [.en: "APPEARANCE", .zhHans: "外观"],
            "Theme Mode": [.en: "Theme Mode", .zhHans: "外观主题"],
            "Choose your preferred display mode": [.en: "Choose your preferred display mode", .zhHans: "选择您偏好的界面显示模式"],
            "Light": [.en: "Light", .zhHans: "亮色"],
            "Dark": [.en: "Dark", .zhHans: "暗色"],
            "System": [.en: "System", .zhHans: "自适应"],
            
            // Typography
            "TYPOGRAPHY": [.en: "TYPOGRAPHY", .zhHans: "排版"],
            "Editor Font": [.en: "Editor Font", .zhHans: "编辑器字体"],
            "Monospace font for previewing and editing": [.en: "Monospace font for previewing and editing", .zhHans: "预览和编辑 Markdown 与代码时采用的等宽字体"],
            "Font Size": [.en: "Font Size", .zhHans: "字体大小"],
            "System Default (Inter)": [.en: "System Default (Inter)", .zhHans: "系统默认 (Inter)"],
            
            // Keybindings
            "KEYBINDINGS": [.en: "KEYBINDINGS", .zhHans: "快捷键"],
            "Global Preview": [.en: "Global Preview", .zhHans: "全局快捷键预览"],
            "Click keys on the right to record custom hotkey": [.en: "Click keys on the right to record custom hotkey", .zhHans: "点击右侧键帽录制自定义组合快捷键"],
            "Press new shortcut keys...": [.en: "Press new shortcut keys...", .zhHans: "请在键盘上按下新快捷键..."],
            "Enter Edit Mode": [.en: "Enter Edit Mode", .zhHans: "进入编辑模式"],
            "Save File Changes": [.en: "Save File Changes", .zhHans: "保存文件修改"],
            
            // System
            "SYSTEM": [.en: "SYSTEM", .zhHans: "系统"],
            "Launch at Login": [.en: "Launch at Login", .zhHans: "开机自启动"],
            "Automatically start QuickCookies in the background when you log in": [.en: "Automatically start QuickCookies in the background when you log in", .zhHans: "在您登录 macOS 系统时自动静默启动 Quick Cookies"],
            "Restore Default Settings": [.en: "Restore Default Settings", .zhHans: "恢复默认设置"],
            
            // Language
            "Language": [.en: "Language", .zhHans: "语言"],
            "Choose display language": [.en: "Choose display language", .zhHans: "选择界面的显示语言"],
            "Follow System": [.en: "Follow System", .zhHans: "跟随系统"],
            
            // Menu
            "Open Selected File": [.en: "Open Selected File", .zhHans: "打开选中文件"],
            "Settings": [.en: "Settings", .zhHans: "设置"],
            "Quit": [.en: "Quit", .zhHans: "退出"],
            "Double-press Option or click here to open the selected Finder file": [.en: "Double-press Option or click here to open the selected Finder file", .zhHans: "双击 Option 或点击此按钮打开 Finder 选中的文件"],
            
            // Content View & Overlay
            "Locating selected file in Finder...": [.en: "Locating selected file in Finder...", .zhHans: "正在定位 Finder 选中文件..."],
                      // Added for Full Localization
            "OK": [.en: "OK", .zhHans: "确定"],
            "Failed to Get": [.en: "Failed to Get", .zhHans: "获取失败"],
            "Locating...": [.en: "Locating...", .zhHans: "定位中..."],
            "⚠️ Loaded first 1000 lines only": [.en: "⚠️ Loaded first 1000 lines only", .zhHans: "⚠️只加载了前1000行"],
            "Enter Edit (Cmd+E)": [.en: "Enter Edit (Cmd+E)", .zhHans: "进入编辑 (Cmd+E)"],
            "Back to Preview (Esc)": [.en: "Back to Preview (Esc)", .zhHans: "回到预览 (Esc)"],
            "Save (Cmd+S)": [.en: "Save (Cmd+S)", .zhHans: "保存 (Cmd+S)"],
            "Failed to read file": [.en: "Failed to read file", .zhHans: "读取文件失败"],
            "Size": [.en: "Size", .zhHans: "大小"],
            "Pos": [.en: "Pos", .zhHans: "位置"],
            "Unsupported file type": [.en: "Unsupported file type", .zhHans: "不支持的文件类型"],
            "Focused": [.en: "Focused", .zhHans: "聚焦"],
            "Source": [.en: "Source", .zhHans: "源"],
            "Finder PID failed": [.en: "Finder PID failed", .zhHans: "Finder PID 失败"],
            "No selected item found": [.en: "No selected item found", .zhHans: "未搜寻到选中项"],
            "Failed to read coordinate/size attributes": [.en: "Failed to read coordinate/size attributes", .zhHans: "坐标/大小属性读取失败"],
            "Default Center": [.en: "Default Center", .zhHans: "默认中心"],
            "Window traversal succeeded": [.en: "Window traversal succeeded", .zhHans: "Window 遍历成功"],
            "Unknown error": [.en: "Unknown error", .zhHans: "未知错误"],
            "Unsupported file type (detail)": [.en: "Unsupported file type", .zhHans: "不支持此文件类型"],
            "Unsupported file format": [.en: "Unsupported file format", .zhHans: "不支持的文件格式"],
            "Vector Graphics (SVG)": [.en: "Vector Graphics (SVG)", .zhHans: "矢量图形 (SVG)"],
            
            // Custom Message Bar & Translation Cleanups
            "File Updated Externally": [.en: "File Updated Externally", .zhHans: "文件已被外部修改"],
            "This file has been modified by another editor. Reload the latest changes?": [.en: "This file has been modified by another editor. Reload the latest changes?", .zhHans: "该文件已被其他编辑器修改，是否重新加载最新内容？"],
            "Reload": [.en: "Reload", .zhHans: "重新加载"],
            "Ignore": [.en: "Ignore", .zhHans: "忽略"],
            "Loading remaining content...": [.en: "Loading remaining content...", .zhHans: "正在载入后续内容..."],
            "Loading content...": [.en: "Loading content...", .zhHans: "正在载入内容..."],
            "PDF exported successfully": [.en: "PDF exported successfully", .zhHans: "PDF 导出成功"],
            "Export PDF": [.en: "Export PDF", .zhHans: "导出 PDF"],
            "Save Failed": [.en: "Save Failed", .zhHans: "保存失败"],
            "Export": [.en: "Export", .zhHans: "导出"],
            "Failed to load remaining text": [.en: "Failed to load remaining text", .zhHans: "载入后续文本失败"],
            "Failed to read remaining file": [.en: "Failed to read remaining file", .zhHans: "读取剩余文件失败"],
            "Finder Extension": [.en: "Finder Extension", .zhHans: "Finder 扩展"],
            "Integrate right-click menu and seamless preview. Zero privacy risk.": [.en: "Integrate right-click menu and seamless preview. Zero privacy risk.", .zhHans: "集成右键菜单与无感预览。零隐私风险。"],
            "Allow flying from file position with smooth spring physics animations.": [.en: "Allow flying from file position with smooth spring physics animations.", .zhHans: "允许从文件原位起跳，享受物理弹簧质感动画。"],
            "macOS version too low, PDF generation is not supported": [.en: "macOS version too low, PDF generation is not supported", .zhHans: "macOS 版本过低，不支持生成 PDF"]
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
        var targetName = name
        if name == "JetBrains Mono" {
            targetName = "JetBrainsMono-Regular"
        }
        if let font = NSFont(name: targetName, size: size) {
            return font
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}