import XCTest
@testable import QuickCookies

final class PreviewContentLoadCoordinatorTests: XCTestCase {
    func test_beginLoad_replacesPreviousRequestIdentity() {
        var coordinator = PreviewContentLoadCoordinator()

        let first = coordinator.beginLoad(path: "/tmp/a.md")
        let second = coordinator.beginLoad(path: "/tmp/b.md")

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(coordinator.activeRequest?.path, "/tmp/b.md")
    }

    func test_shouldApply_acceptsOnlyLatestRequestIdentity() {
        var coordinator = PreviewContentLoadCoordinator()

        let first = coordinator.beginLoad(path: "/tmp/a.md")
        let second = coordinator.beginLoad(path: "/tmp/b.md")

        XCTAssertFalse(coordinator.shouldApplyResult(for: first))
        XCTAssertTrue(coordinator.shouldApplyResult(for: second))
    }

    func test_shouldApply_rejectsSamePathOldIdentityAfterReload() {
        var coordinator = PreviewContentLoadCoordinator()

        let first = coordinator.beginLoad(path: "/tmp/a.md")
        let second = coordinator.beginLoad(path: "/tmp/a.md")

        XCTAssertFalse(coordinator.shouldApplyResult(for: first))
        XCTAssertTrue(coordinator.shouldApplyResult(for: second))
    }

    func test_reset_clearsActiveRequest() {
        var coordinator = PreviewContentLoadCoordinator()

        _ = coordinator.beginLoad(path: "/tmp/a.md")
        coordinator.reset()

        XCTAssertNil(coordinator.activeRequest)
    }

    func test_shouldApply_rejectsRequestWhenCurrentPathHasMovedBeforeNextRequestStarts() {
        var coordinator = PreviewContentLoadCoordinator()

        let request = coordinator.beginLoad(path: "/tmp/a.md")

        XCTAssertFalse(
            coordinator.shouldApplyResult(
                for: request,
                currentPath: "/tmp/b.md"
            )
        )
    }

    func test_shouldApply_acceptsLatestRequestOnlyWhenItStillMatchesCurrentPath() {
        var coordinator = PreviewContentLoadCoordinator()

        let request = coordinator.beginLoad(path: "/tmp/a.md")

        XCTAssertTrue(
            coordinator.shouldApplyResult(
                for: request,
                currentPath: "/tmp/a.md"
            )
        )
    }
}
