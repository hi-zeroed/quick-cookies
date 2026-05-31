import Foundation

/// 缓存语法高亮富文本包装类
class CachedHighlight: NSObject {
    let attributedString: NSAttributedString
    let modificationDate: Date

    init(attributedString: NSAttributedString, modificationDate: Date) {
        self.attributedString = attributedString
        self.modificationDate = modificationDate
        super.init()
    }
}

/// 语法高亮内存缓存器
class HighlightCache {
    static let shared = HighlightCache()

    private let cache = NSCache<NSString, CachedHighlight>()

    private init() {
        // 设置缓存上限，避免内存占用过大
        cache.countLimit = 100
    }

    /// 获取缓存的高亮文本
    func get(for filePath: String, themeName: String, fontName: String? = nil, fontSize: CGFloat? = nil, modificationDate: Date) -> NSAttributedString? {
        var key = "\(filePath)_\(themeName)"
        if let fontName = fontName, let fontSize = fontSize {
            key += "_\(fontName)_\(fontSize)"
        }
        let nsKey = key as NSString
        if let cached = cache.object(forKey: nsKey) {
            // 只有当文件最后修改时间一致时才认为缓存有效
            if cached.modificationDate == modificationDate {
                return cached.attributedString
            }
        }
        return nil
    }

    /// 存入高亮文本缓存
    func set(_ attributedString: NSAttributedString, for filePath: String, themeName: String, fontName: String? = nil, fontSize: CGFloat? = nil, modificationDate: Date) {
        var key = "\(filePath)_\(themeName)"
        if let fontName = fontName, let fontSize = fontSize {
            key += "_\(fontName)_\(fontSize)"
        }
        let nsKey = key as NSString
        let cached = CachedHighlight(attributedString: attributedString, modificationDate: modificationDate)
        cache.setObject(cached, forKey: nsKey)
    }

    /// 清空所有缓存
    func clear() {
        cache.removeAllObjects()
    }
}
