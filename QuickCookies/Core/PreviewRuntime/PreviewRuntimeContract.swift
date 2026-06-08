import Foundation

enum PreviewRuntimeKind: Equatable {
    case web
    case text
    case document
    case media
}

@MainActor
protocol PreviewRuntime: AnyObject {
    var kind: PreviewRuntimeKind { get }

    func detach()
    func reset()
}
