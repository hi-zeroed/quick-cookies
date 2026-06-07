import Foundation

enum MarkdownRenderBlockKind: String, Codable, Hashable {
    case heading
    case paragraph
    case list
    case quote
    case code
    case table
    case html
    case image
    case thematicBreak
}

enum MarkdownAppendMode: String, Codable, Hashable {
    case initial
    case incremental
    case restore
}

struct MarkdownImageMeta: Codable, Hashable {
    let source: String
    let resolvedSourceURL: String?
    let width: Int?
    let height: Int?

    init(source: String, resolvedSourceURL: String? = nil, width: Int?, height: Int?) {
        self.source = source
        self.resolvedSourceURL = resolvedSourceURL
        self.width = width
        self.height = height
    }
}

struct MarkdownRenderBlock: Identifiable, Codable, Hashable {
    let id: String
    let kind: MarkdownRenderBlockKind
    let markdown: String
    let preferredHeight: Double?
    let imageMetas: [MarkdownImageMeta]
    let codeLanguage: String?
}

struct MarkdownPreviewBatch: Codable, Hashable {
    let appendMode: MarkdownAppendMode
    let blocks: [MarkdownRenderBlock]
}

struct MarkdownPreviewPreparedContent {
    let batches: [MarkdownPreviewBatch]
    let shouldVirtualize: Bool
    let overscanScreens: Int
}
