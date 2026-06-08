import Foundation

@MainActor
final class PreviewCoordinator {
    private let session: PreviewSession
    private let resolver: PreviewTargetResolver

    init(
        session: PreviewSession,
        resolver: PreviewTargetResolver = PreviewTargetResolver()
    ) {
        self.session = session
        self.resolver = resolver
    }

    /// 统一执行 launch -> resolve -> session 的主流程。
    ///
    /// 这里负责把结构化错误写回 session，供 overlay/content 展示错误态；
    /// 不负责窗口动画与壳层展示。
    func handle(_ request: PreviewLaunchRequest) throws {
        do {
            let target = try resolver.resolve(request: request)

            if request == .refreshFinderSelection(),
               session.state.target?.resolvedPath == target.resolvedPath,
               session.state.target?.renderType == target.renderType {
                return
            }

            session.open(target: target, source: request.source)
        } catch let error as PreviewTargetError {
            session.replaceWithFailure(error)
            throw error
        }
    }
}
