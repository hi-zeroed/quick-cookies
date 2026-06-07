import Foundation

struct MarkdownRenderedBlockSnapshot: Codable, Hashable {
    let id: String
    let kind: MarkdownRenderBlockKind
    let html: String
    let height: Double?
}

struct MarkdownRenderSnapshot: Codable, Hashable {
    let renderedBlocks: [MarkdownRenderedBlockSnapshot]
    let blockOrder: [String]
    let blockHeights: [String: Double]
    let shouldVirtualize: Bool
    let overscanScreens: Int
}
