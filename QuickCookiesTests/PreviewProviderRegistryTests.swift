import XCTest
import SwiftUI
@testable import QuickCookies

final class PreviewProviderRegistryTests: XCTestCase {
    
    func test_registryReturnsCorrectProviderForEveryRenderType() {
        let registry = PreviewProviderRegistry.shared
        
        XCTAssertEqual(registry.provider(for: .markdown).renderType, .markdown)
        XCTAssertEqual(registry.provider(for: .code).renderType, .code)
        XCTAssertEqual(registry.provider(for: .plainText).renderType, .plainText)
        XCTAssertEqual(registry.provider(for: .image).renderType, .image)
        XCTAssertEqual(registry.provider(for: .pdf).renderType, .pdf)
        XCTAssertEqual(registry.provider(for: .office).renderType, .office)
        XCTAssertEqual(registry.provider(for: .archive).renderType, .archive)
        XCTAssertEqual(registry.provider(for: .folder).renderType, .folder)
        XCTAssertEqual(registry.provider(for: .audio).renderType, .audio)
        XCTAssertEqual(registry.provider(for: .video).renderType, .video)
        XCTAssertEqual(registry.provider(for: .font).renderType, .font)
        XCTAssertEqual(registry.provider(for: .unsupported).renderType, .unsupported)
        XCTAssertEqual(registry.provider(for: nil).renderType, .unsupported)
    }
    
    func test_allowsPDFExport_onlyMarkdownAllowed() {
        XCTAssertTrue(PreviewProviderRegistry.allowsPDFExport(for: .markdown))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .code))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .plainText))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .image))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .pdf))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .office))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .archive))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: .unsupported))
        XCTAssertFalse(PreviewProviderRegistry.allowsPDFExport(for: nil))
    }
    
    func test_usesTextContentLoader_forTextTypesAndSVG() {
        XCTAssertTrue(PreviewProviderRegistry.usesTextContentLoader(for: .markdown))
        XCTAssertTrue(PreviewProviderRegistry.usesTextContentLoader(for: .code))
        XCTAssertTrue(PreviewProviderRegistry.usesTextContentLoader(for: .plainText))
        XCTAssertTrue(PreviewProviderRegistry.usesTextContentLoader(for: .image, path: "/path/to/icon.svg"))
        XCTAssertFalse(PreviewProviderRegistry.usesTextContentLoader(for: .image, path: "/path/to/photo.png"))
        XCTAssertFalse(PreviewProviderRegistry.usesTextContentLoader(for: .pdf))
        XCTAssertFalse(PreviewProviderRegistry.usesTextContentLoader(for: .archive))
        XCTAssertFalse(PreviewProviderRegistry.usesTextContentLoader(for: nil))
    }
    
    func test_showsGenericLoading_onlyCodeAndPlainText() {
        XCTAssertTrue(PreviewProviderRegistry.showsGenericLoading(for: .code))
        XCTAssertTrue(PreviewProviderRegistry.showsGenericLoading(for: .plainText))
        XCTAssertFalse(PreviewProviderRegistry.showsGenericLoading(for: .markdown))
        XCTAssertFalse(PreviewProviderRegistry.showsGenericLoading(for: .image))
        XCTAssertFalse(PreviewProviderRegistry.showsGenericLoading(for: .pdf))
        XCTAssertFalse(PreviewProviderRegistry.showsGenericLoading(for: nil))
    }
    
    func test_supportsSearch_matrix() {
        XCTAssertTrue(PreviewProviderRegistry.supportsSearch(for: .markdown))
        XCTAssertTrue(PreviewProviderRegistry.supportsSearch(for: .code))
        XCTAssertTrue(PreviewProviderRegistry.supportsSearch(for: .plainText))
        XCTAssertTrue(PreviewProviderRegistry.supportsSearch(for: .image, path: "vector.svg", isSVGSourceMode: true))
        XCTAssertFalse(PreviewProviderRegistry.supportsSearch(for: .image, path: "vector.svg", isSVGSourceMode: false))
        XCTAssertFalse(PreviewProviderRegistry.supportsSearch(for: .image, path: "photo.jpg", isSVGSourceMode: true))
        XCTAssertFalse(PreviewProviderRegistry.supportsSearch(for: .pdf))
        XCTAssertFalse(PreviewProviderRegistry.supportsSearch(for: .archive))
        XCTAssertFalse(PreviewProviderRegistry.supportsSearch(for: nil))
    }
    
    func test_chromeBackgroundAndBorderStyle() {
        // Image & Unsupported 默认透明无边框
        XCTAssertEqual(PreviewProviderRegistry.backgroundStyle(for: .image, isSVGSourceMode: false), .transparent)
        XCTAssertEqual(PreviewProviderRegistry.borderStyle(for: .image, isSVGSourceMode: false), .none)
        
        XCTAssertEqual(PreviewProviderRegistry.backgroundStyle(for: .unsupported), .transparent)
        XCTAssertEqual(PreviewProviderRegistry.borderStyle(for: .unsupported), .none)
        
        // SVG 源码模式下具有常规边框与背景
        XCTAssertEqual(PreviewProviderRegistry.backgroundStyle(for: .image, isSVGSourceMode: true), .appBackground)
        XCTAssertEqual(PreviewProviderRegistry.borderStyle(for: .image, isSVGSourceMode: true), .appBorder)
        
        // Code & Markdown 具有常规背景与边框
        XCTAssertEqual(PreviewProviderRegistry.backgroundStyle(for: .code), .appBackground)
        XCTAssertEqual(PreviewProviderRegistry.borderStyle(for: .code), .appBorder)
        XCTAssertEqual(PreviewProviderRegistry.backgroundStyle(for: .markdown), .appBackground)
        XCTAssertEqual(PreviewProviderRegistry.borderStyle(for: .markdown), .appBorder)
    }
}
