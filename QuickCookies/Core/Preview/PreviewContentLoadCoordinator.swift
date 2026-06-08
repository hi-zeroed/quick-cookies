import Foundation

struct PreviewContentLoadRequest: Equatable {
    let id: UUID
    let path: String
}

struct PreviewContentLoadCoordinator {
    private(set) var activeRequest: PreviewContentLoadRequest?

    @discardableResult
    mutating func beginLoad(path: String) -> PreviewContentLoadRequest {
        let request = PreviewContentLoadRequest(id: UUID(), path: path)
        activeRequest = request
        return request
    }

    func shouldApplyResult(for request: PreviewContentLoadRequest) -> Bool {
        activeRequest == request
    }

    mutating func reset() {
        activeRequest = nil
    }
}
