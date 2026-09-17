import Foundation

/// 负责安全加载并内存缓存 Markdown 扩展组件（Mermaid、KaTeX）的离线静态资源。
enum MarkdownVendorAssetLoader {
    private static let lock = NSLock()
    private static var cachedScripts: [String: String] = [:]

    /// 加载 Mermaid 离线 JS 脚本
    static func loadMermaidScript() -> String? {
        loadCachedAsset(name: "mermaid", ext: "min.js")
    }

    /// 加载 KaTeX 核心 JS 脚本
    static func loadKaTeXScript() -> String? {
        loadCachedAsset(name: "katex", ext: "min.js")
    }

    /// 加载 KaTeX Auto-Render 扩展 JS 脚本
    static func loadKaTeXAutoRenderScript() -> String? {
        loadCachedAsset(name: "auto-render", ext: "min.js")
    }

    /// 加载 KaTeX 样式表 CSS
    static func loadKaTeXCSS() -> String? {
        loadCachedAsset(name: "katex", ext: "min.css")
    }

    /// 清空脚本缓存（测试或低内存时调用）
    static func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cachedScripts.removeAll()
    }

    private static func loadCachedAsset(name: String, ext: String) -> String? {
        let key = "\(name).\(ext)"
        lock.lock()
        if let existing = cachedScripts[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        guard let url = findAssetURL(name: name, ext: ext),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        lock.lock()
        cachedScripts[key] = content
        lock.unlock()
        return content
    }

    private static func findAssetURL(name: String, ext: String) -> URL? {
        // 1. 优先从主 Bundle 的 Resources/Vendor 目录下查找
        if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Vendor") {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return url
        }

        // 2. 遍历当前进程的所有 Bundle（针对测试用例 host 或 extension）
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Vendor") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }

        // 3. 源码工程目录安全回退（单元测试与本地预览未打包环境）
        let sourceFile = URL(fileURLWithPath: #file)
        let repoRoot = sourceFile
            .deletingLastPathComponent() // Markdown/
            .deletingLastPathComponent() // Core/
            .deletingLastPathComponent() // QuickCookies/
        let devVendorURL = repoRoot
            .appendingPathComponent("QuickCookies")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Vendor")
            .appendingPathComponent("\(name).\(ext)")

        if FileManager.default.fileExists(atPath: devVendorURL.path) {
            return devVendorURL
        }

        return nil
    }
}
