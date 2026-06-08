import Combine
import Foundation

enum PreviewSessionMode: Equatable {
    case preview
    case edit
}

enum PreviewReadiness: Equatable {
    case idle
    case loading
    case ready
    case failed(PreviewTargetError)
}

struct PreviewSessionState: Equatable {
    var target: PreviewTarget?
    var source: PreviewLaunchSource?
    var runtimeKind: PreviewRuntimeKind?
    var mode: PreviewSessionMode
    var readiness: PreviewReadiness
    var isExpanded: Bool
    var renderTypeOverride: FileRenderType? = nil

    var errorMessage: String? {
        guard case .failed(let error) = readiness else {
            return nil
        }
        return error.defaultMessage
    }

    var displayRenderType: FileRenderType? {
        renderTypeOverride ?? target?.renderType
    }

    static let initial = PreviewSessionState(
        target: nil,
        source: nil,
        runtimeKind: nil,
        mode: .preview,
        readiness: .idle,
        isExpanded: false,
        renderTypeOverride: nil
    )
}

@MainActor
final class PreviewSession: ObservableObject {
    // 只承载业务意义上的当前预览会话状态；
    // 纯视图层的局部状态仍应留在各自 view/runtime 内部。
    @Published private(set) var state: PreviewSessionState = .initial

    func open(target: PreviewTarget, source: PreviewLaunchSource) {
        state = PreviewSessionState(
            target: target,
            source: source,
            runtimeKind: PreviewRuntimeKind.forRenderType(target.renderType),
            mode: .preview,
            readiness: .loading,
            isExpanded: false,
            renderTypeOverride: nil
        )
    }

    func markReady() {
        state.readiness = .ready
        state.renderTypeOverride = nil
    }

    func markFailed(_ error: PreviewTargetError) {
        state.readiness = .failed(error)
        state.mode = .preview
        state.isExpanded = false
        state.renderTypeOverride = nil

        if state.target == nil {
            state.runtimeKind = nil
        }
    }

    func replaceWithFailure(_ error: PreviewTargetError) {
        state = PreviewSessionState(
            target: nil,
            source: nil,
            runtimeKind: nil,
            mode: .preview,
            readiness: .failed(error),
            isExpanded: false,
            renderTypeOverride: nil
        )
    }

    func applyRuntimeFailure(message: String, renderTypeOverride: FileRenderType? = nil) {
        state.readiness = .failed(.runtime(message: message))
        state.renderTypeOverride = renderTypeOverride
        state.mode = .preview
        state.isExpanded = false
    }

    func enterEditMode() {
        state.mode = .edit
    }

    func returnToPreviewMode() {
        state.mode = .preview
    }

    func toggleExpanded() {
        state.isExpanded.toggle()
    }

    func collapseExpanded() {
        state.isExpanded = false
    }

    func reset() {
        state = .initial
    }
}

private extension PreviewRuntimeKind {
    static func forRenderType(_ renderType: FileRenderType) -> PreviewRuntimeKind {
        switch renderType {
        case .markdown:
            return .web
        case .code, .plainText, .unsupported:
            return .text
        case .office:
            return .document
        case .image, .pdf:
            return .media
        }
    }
}
