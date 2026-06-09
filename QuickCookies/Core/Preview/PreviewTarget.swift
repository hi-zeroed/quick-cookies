import Foundation

extension FileRenderType: Equatable {}

struct PreviewTarget: Equatable {
    let originalPath: String
    let resolvedPath: String
    let renderType: FileRenderType
    let language: String?
    let displayName: String
}

enum PreviewTargetErrorKind: Equatable {
    case noSelection
    case fileNotFound
    case directoryNotSupported
    case unsupportedType
    case finderUnavailable
    case runtimeFailure
}

struct PreviewTargetError: Error, Equatable {
    let kind: PreviewTargetErrorKind
    let defaultMessage: String

    static let noFinderSelection = PreviewTargetError(
        kind: .noSelection,
        defaultMessage: "No file selected"
    )

    static let fileNotFound = PreviewTargetError(
        kind: .fileNotFound,
        defaultMessage: "File not found"
    )

    static func runtime(message: String) -> PreviewTargetError {
        PreviewTargetError(
            kind: .runtimeFailure,
            defaultMessage: message
        )
    }
}
