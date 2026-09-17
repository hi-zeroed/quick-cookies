import Foundation
import SwiftUI
import AppKit

/// 代码卡片艺术背景渐变预设
enum CardGradientPreset: String, CaseIterable, Identifiable {
    case aurora = "Aurora"
    case sunset = "Sunset"
    case charcoal = "Charcoal"
    case cyberpunk = "Cyberpunk"
    case monochrome = "Monochrome"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .aurora: return "Aurora".localized()
        case .sunset: return "Sunset".localized()
        case .charcoal: return "Charcoal".localized()
        case .cyberpunk: return "Cyberpunk".localized()
        case .monochrome: return "Monochrome".localized()
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .aurora:
            return LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.73, blue: 0.51), // #10b981
                    Color(red: 0.39, green: 0.40, blue: 0.95), // #6366f1
                    Color(red: 0.93, green: 0.28, blue: 0.60)  // #ec4899
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sunset:
            return LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.25, blue: 0.37), // #f43f5e
                    Color(red: 0.98, green: 0.57, blue: 0.24)  // #fb923c
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .charcoal:
            return LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.13, blue: 0.16),
                    Color(red: 0.05, green: 0.05, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cyberpunk:
            return LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.53, blue: 0.98), // #2185fa
                    Color(red: 0.68, green: 0.20, blue: 0.95)  // #ae33f3
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .monochrome:
            return LinearGradient(
                colors: [
                    Color(white: 0.25),
                    Color(white: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .aurora: return Color(red: 0.06, green: 0.73, blue: 0.51)
        case .sunset: return Color(red: 0.96, green: 0.25, blue: 0.37)
        case .charcoal: return Color(red: 0.40, green: 0.42, blue: 0.48)
        case .cyberpunk: return Color(red: 0.68, green: 0.20, blue: 0.95)
        case .monochrome: return Color(white: 0.60)
        }
    }
}

/// 代码卡片边距规格
enum CardPaddingPreset: CGFloat, CaseIterable, Identifiable {
    case compact = 20.0
    case regular = 32.0
    case spacious = 44.0
    
    var id: CGFloat { rawValue }
    
    var displayName: String {
        switch self {
        case .compact: return "Compact".localized()
        case .regular: return "Regular".localized()
        case .spacious: return "Spacious".localized()
        }
    }
}

/// 代码与内容分享卡片类型模式
enum CardContentMode: String, CaseIterable, Identifiable {
    case code = "Code"
    case quote = "Quote"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .code: return "Code".localized()
        case .quote: return "Text / Quote".localized()
        }
    }
    
    var iconName: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .quote: return "quote.opening"
        }
    }
}

/// 代码卡片明暗色彩主题
enum CardColorTheme: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case light = "Light"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dark: return "Dark".localized()
        case .light: return "Light".localized()
        }
    }
    
    var iconName: String {
        switch self {
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        }
    }
}

/// 卡片画布社交分享比例预设
enum CardAspectRatio: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case square = "1:1"
    case landscape = "16:9"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto".localized()
        case .square: return "1:1"
        case .landscape: return "16:9"
        }
    }
}

/// 代码卡片自定义选项配置模型
struct CodeCardConfig: Equatable {
    var mode: CardContentMode = .code
    var colorTheme: CardColorTheme = .dark
    var aspectRatio: CardAspectRatio = .auto
    var preset: CardGradientPreset = .aurora
    var padding: CardPaddingPreset = .regular
    var isTransparentBackground: Bool = false
    var showAmbientGlow: Bool = true
    var showLineNumbers: Bool = true
    var showWatermark: Bool = true
    var showTrafficLights: Bool = true
    var fontName: String = "SF Mono"
    var fontSize: CGFloat = 13.0
    var customLanguage: String? = nil
}

/// 代码卡片语言识别与徽标大写格式化器
enum CodeCardLanguageFormatter {
    /// 常见快速可选语言列表
    static let popularLanguages: [String] = [
        "Auto", "TSX", "TS", "JS", "JAVA", "SWIFT", "PYTHON", "RUST", "GO", "C++", "JSON", "SQL", "HTML", "CSS", "BASH"
    ]
    
    /// 将语言、标题文件名或代码内容推断并格式化为标准大写简称 (如 TSX, JS, JAVA, SWIFT)
    static func format(customLanguage: String? = nil, detectedLanguage: String? = nil, title: String? = nil, code: String? = nil) -> String {
        // 1. 若用户显式自选了语言（非 Auto）
        if let custom = customLanguage, !custom.isEmpty, custom.lowercased() != "auto" {
            return custom.uppercased()
        }
        
        // 2. 检查传入的 detectedLanguage
        if let lang = detectedLanguage?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !lang.isEmpty {
            if let matched = matchStandardBadge(from: lang) {
                return matched
            }
        }
        
        // 3. 从 title / 原始文件名或 "Clipboard (Language)" 提取后缀或名称
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            // 处理 "Clipboard (JavaScript)" 等格式
            if title.contains("(") && title.contains(")") {
                if let start = title.lastIndex(of: "("), let end = title.lastIndex(of: ")"), start < end {
                    let inside = String(title[title.index(after: start)..<end]).lowercased()
                    if let matched = matchStandardBadge(from: inside) {
                        return matched
                    }
                }
            }
            
            // 提取文件扩展名 (例如 App.tsx -> tsx)
            let ext = URL(fileURLWithPath: title).pathExtension.lowercased()
            if !ext.isEmpty, let matched = matchStandardBadge(from: ext) {
                return matched
            }
            
            // 匹配纯文件名如果包含已知标识 (例如 tsx, js 等)
            let clean = title.lowercased()
            if let matched = matchStandardBadge(from: clean) {
                return matched
            }
        }
        
        // 4. 从代码正文快速嗅探常见特征
        if let code = code, !code.isEmpty {
            if let sniffed = sniffLanguageFromContent(code) {
                return sniffed
            }
        }
        
        // 5. 兜底通用徽标
        return "CODE"
    }
    
    /// 将自选、推断或徽标语言名称精准转换为 Highlightr 底层语法引擎支持的合法标识符
    static func highlightrLanguage(from rawName: String?) -> String? {
        guard let name = rawName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !name.isEmpty else {
            return nil
        }
        if let mapped = Constants.languageMap[name] {
            return mapped
        }
        switch name {
        case "tsx", "ts", "typescript", "typescript-react", "typescriptreact":
            return "typescript"
        case "jsx", "js", "javascript", "javascript-react", "javascriptreact", "node":
            return "javascript"
        case "py", "python", "py3", "python3":
            return "python"
        case "rs", "rust":
            return "rust"
        case "kt", "kotlin", "kts":
            return "kotlin"
        case "cpp", "c++", "cc", "cxx", "hpp":
            return "cpp"
        case "cs", "c#", "csharp":
            return "cs"
        case "go", "golang":
            return "go"
        case "sh", "bash", "zsh", "shell":
            return "bash"
        case "html", "htm", "vue":
            return "xml"
        case "yml", "yaml":
            return "yaml"
        case "json", "jsonc", "json5":
            return "json"
        case "sql":
            return "sql"
        case "java":
            return "java"
        case "swift":
            return "swift"
        default:
            return name
        }
    }
    
    private static func matchStandardBadge(from raw: String) -> String? {
        switch raw {
        case "tsx", "typescript-react", "typescriptreact":
            return "TSX"
        case "jsx", "javascript-react", "javascriptreact":
            return "JSX"
        case "ts", "typescript", "cts", "mts":
            return "TS"
        case "js", "javascript", "cjs", "mjs", "node":
            return "JS"
        case "java":
            return "JAVA"
        case "kt", "kotlin", "kts":
            return "KOTLIN"
        case "swift":
            return "SWIFT"
        case "py", "python", "py3", "python3":
            return "PYTHON"
        case "rs", "rust":
            return "RUST"
        case "go", "golang":
            return "GO"
        case "cpp", "c++", "cc", "cxx", "hpp":
            return "C++"
        case "c", "h":
            return "C"
        case "cs", "csharp", "c#":
            return "C#"
        case "rb", "ruby":
            return "RUBY"
        case "php":
            return "PHP"
        case "sh", "bash", "zsh", "shell":
            return "BASH"
        case "json", "jsonc", "json5":
            return "JSON"
        case "yaml", "yml":
            return "YAML"
        case "toml":
            return "TOML"
        case "xml", "plist":
            return "XML"
        case "html", "htm":
            return "HTML"
        case "css", "scss", "sass", "less":
            return "CSS"
        case "sql":
            return "SQL"
        case "md", "markdown":
            return "MARKDOWN"
        case "dart":
            return "DART"
        case "lua":
            return "LUA"
        case "scala":
            return "SCALA"
        case "zig":
            return "ZIG"
        default:
            return nil
        }
    }
    
    private static func sniffLanguageFromContent(_ content: String) -> String? {
        let sample = String(content.prefix(1500))
        
        if sample.contains("import React") || sample.contains("from 'react'") || sample.contains("from \"react\"") {
            return sample.contains(": ") || sample.contains("interface ") || sample.contains("<FC") ? "TSX" : "JSX"
        }
        if sample.contains("import SwiftUI") || sample.contains("var body: some View") {
            return "SWIFT"
        }
        if sample.contains("public static void main") || sample.contains("System.out.print") {
            return "JAVA"
        }
        if sample.contains("def ") && (sample.contains("self") || sample.contains("print(") || sample.contains("import ")) {
            return "PYTHON"
        }
        if sample.contains("fn main()") || sample.contains("let mut ") || sample.contains("println!") {
            return "RUST"
        }
        if sample.contains("package main") || (sample.contains("func ") && sample.contains("fmt.")) {
            return "GO"
        }
        if sample.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") &&
           sample.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") {
            return "JSON"
        }
        if sample.contains("const ") || sample.contains("let ") || sample.contains("console.log") {
            return sample.contains(": ") || sample.contains("interface ") ? "TS" : "JS"
        }
        return nil
    }
}

/// 代码卡片图像渲染服务
@MainActor
enum CodeCardRenderer {
    /// 利用 SwiftUI ImageRenderer 将任意 View 渲染为高清 Retina @2x NSImage
    static func renderToImage<V: View>(view: V, scale: CGFloat = 2.0) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.nsImage
    }
    
    /// 将渲染结果转换为 PNG 字节流
    static func renderToPNGData<V: View>(view: V, scale: CGFloat = 2.0) -> Data? {
        guard let nsImage = renderToImage(view: view, scale: scale),
              let tiffRepresentation = nsImage.tiffRepresentation,
              let bitmapImageRep = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImageRep.representation(using: .png, properties: [:])
    }
    
    /// 拷贝高清图像至剪贴板
    static func copyImageToPasteboard<V: View>(view: V, scale: CGFloat = 2.0) -> Bool {
        guard let image = renderToImage(view: view, scale: scale) else {
            return false
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
}
