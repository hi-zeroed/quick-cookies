import Foundation

enum PreviewContentIdentity {
    static func makeKey(
        path: String?,
        renderType: FileRenderType?,
        mode: ContentMode
    ) -> String {
        let resolvedPath = path ?? "no-path"
        let resolvedRenderType = renderType.map { String(describing: $0) } ?? "no-render-type"
        let resolvedMode = mode == .edit ? "edit" : "preview"
        return "\(resolvedPath)|\(resolvedRenderType)|\(resolvedMode)"
    }
}

enum PreviewContentReloadIdentityPolicy {
    static func shouldBumpGeneration(
        previousPath: String?,
        nextPath: String
    ) -> Bool {
        previousPath == nextPath
    }
}
