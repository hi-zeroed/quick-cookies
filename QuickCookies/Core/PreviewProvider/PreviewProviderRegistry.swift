import Foundation
import SwiftUI

/// 预览提供者注册与调度中心
final class PreviewProviderRegistry {
    static let shared = PreviewProviderRegistry()
    
    private let providers: [FileRenderType: any PreviewProvider]
    private let fallbackProvider: any PreviewProvider = UnsupportedPreviewProvider()
    
    init() {
        let list: [any PreviewProvider] = [
            MarkdownPreviewProvider(),
            CodePreviewProvider(),
            PlainTextPreviewProvider(),
            ImagePreviewProvider(),
            PDFPreviewProvider(),
            OfficePreviewProvider(),
            ArchivePreviewProvider(),
            FolderPreviewProvider(),
            AudioPreviewProvider(),
            VideoPreviewProvider(),
            FontPreviewProvider(),
            HexPreviewProvider(),
            UnsupportedPreviewProvider()
        ]
        var map: [FileRenderType: any PreviewProvider] = [:]
        for p in list {
            map[p.renderType] = p
        }
        self.providers = map
    }
    
    func provider(for renderType: FileRenderType?) -> any PreviewProvider {
        guard let renderType, let match = providers[renderType] else {
            return fallbackProvider
        }
        return match
    }
    
    // MARK: - 便捷静态查询门面
    
    static func allowsPDFExport(for renderType: FileRenderType?) -> Bool {
        shared.provider(for: renderType).allowsPDFExport
    }
    
    static func usesTextContentLoader(for renderType: FileRenderType?, path: String? = nil) -> Bool {
        guard let renderType else { return false }
        if renderType == .image {
            return path?.lowercased().hasSuffix(".svg") == true
        }
        return shared.provider(for: renderType).usesTextContentLoader
    }
    
    static func showsGenericLoading(for renderType: FileRenderType?) -> Bool {
        shared.provider(for: renderType).showsGenericLoading
    }
    
    static func supportsSearch(for renderType: FileRenderType?, path: String? = nil, isSVGSourceMode: Bool = false) -> Bool {
        shared.provider(for: renderType).supportsSearch(path: path, isSVGSourceMode: isSVGSourceMode)
    }
    
    static func backgroundStyle(for renderType: FileRenderType?, isSVGSourceMode: Bool = false) -> PreviewContentAreaChrome.BackgroundStyle {
        shared.provider(for: renderType).backgroundStyle(isSVGSourceMode: isSVGSourceMode)
    }
    
    static func borderStyle(for renderType: FileRenderType?, isSVGSourceMode: Bool = false) -> PreviewContentAreaChrome.BorderStyle {
        shared.provider(for: renderType).borderStyle(isSVGSourceMode: isSVGSourceMode)
    }
}
