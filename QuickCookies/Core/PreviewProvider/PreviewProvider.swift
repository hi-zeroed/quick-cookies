import Foundation
import SwiftUI

/// 预览提供者能力契约
protocol PreviewProvider {
    var renderType: FileRenderType { get }
    var allowsPDFExport: Bool { get }
    var usesTextContentLoader: Bool { get }
    var showsGenericLoading: Bool { get }
    
    func supportsSearch(path: String?, isSVGSourceMode: Bool) -> Bool
    func backgroundStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BackgroundStyle
    func borderStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BorderStyle
}

extension PreviewProvider {
    var allowsPDFExport: Bool { false }
    var usesTextContentLoader: Bool { false }
    var showsGenericLoading: Bool { false }
    
    func supportsSearch(path: String?, isSVGSourceMode: Bool) -> Bool { false }
    
    func backgroundStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BackgroundStyle {
        .appBackground
    }
    
    func borderStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BorderStyle {
        .appBorder
    }
}

// MARK: - 内置 Providers 实现

struct MarkdownPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .markdown
    var allowsPDFExport: Bool { true }
    var usesTextContentLoader: Bool { true }
    var showsGenericLoading: Bool { false }
    func supportsSearch(path: String?, isSVGSourceMode: Bool) -> Bool { true }
}

struct CodePreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .code
    var allowsPDFExport: Bool { false }
    var usesTextContentLoader: Bool { true }
    var showsGenericLoading: Bool { true }
    func supportsSearch(path: String?, isSVGSourceMode: Bool) -> Bool { true }
}

struct PlainTextPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .plainText
    var allowsPDFExport: Bool { false }
    var usesTextContentLoader: Bool { true }
    var showsGenericLoading: Bool { true }
    func supportsSearch(path: String?, isSVGSourceMode: Bool) -> Bool { true }
}

struct ImagePreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .image
    var allowsPDFExport: Bool { false }
    var usesTextContentLoader: Bool { false }
    var showsGenericLoading: Bool { false }
    
    func supportsSearch(path: String?, isSVGSourceMode: Bool) -> Bool {
        let isSVG = path?.lowercased().hasSuffix(".svg") == true
        return isSVG && isSVGSourceMode
    }
    
    func backgroundStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BackgroundStyle {
        isSVGSourceMode ? .appBackground : .transparent
    }
    
    func borderStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BorderStyle {
        isSVGSourceMode ? .appBorder : .none
    }
}

struct PDFPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .pdf
}

struct OfficePreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .office
}

struct ArchivePreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .archive
}

struct FolderPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .folder
}

struct AudioPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .audio
}

struct VideoPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .video
}

struct FontPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .font
}

struct UnsupportedPreviewProvider: PreviewProvider {
    let renderType: FileRenderType = .unsupported
    
    func backgroundStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BackgroundStyle {
        .transparent
    }
    
    func borderStyle(isSVGSourceMode: Bool) -> PreviewContentAreaChrome.BorderStyle {
        .none
    }
}
