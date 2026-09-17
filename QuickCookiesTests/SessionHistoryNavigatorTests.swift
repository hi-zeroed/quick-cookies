import XCTest
@testable import QuickCookies

@MainActor
final class SessionHistoryNavigatorTests: XCTestCase {
    var navigator: SessionHistoryNavigator!

    override func setUp() {
        super.setUp()
        navigator = SessionHistoryNavigator(maxCapacity: 5)
    }

    override func tearDown() {
        navigator = nil
        super.tearDown()
    }

    func testInitialStateIsClean() {
        XCTAssertEqual(navigator.entries.count, 0)
        XCTAssertEqual(navigator.currentIndex, -1)
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
        XCTAssertNil(navigator.currentPath)
    }

    func testRecordSingleFile() {
        navigator.record(path: "/path/A.swift")
        XCTAssertEqual(navigator.entries.count, 1)
        XCTAssertEqual(navigator.currentIndex, 0)
        XCTAssertEqual(navigator.currentPath, "/path/A.swift")
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
    }

    func testRecordMultipleFilesEnablesGoBack() {
        navigator.record(path: "/path/A.swift")
        navigator.record(path: "/path/B.swift")
        navigator.record(path: "/path/C.swift")

        XCTAssertEqual(navigator.entries.count, 3)
        XCTAssertEqual(navigator.currentIndex, 2)
        XCTAssertEqual(navigator.currentPath, "/path/C.swift")
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
    }

    func testGoBackAndGoForwardMovesIndexAndUpdatesFlags() {
        navigator.record(path: "/path/A.swift")
        navigator.record(path: "/path/B.swift")
        navigator.record(path: "/path/C.swift")

        let back1 = navigator.goBack()
        XCTAssertEqual(back1, "/path/B.swift")
        XCTAssertEqual(navigator.currentIndex, 1)
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertTrue(navigator.canGoForward)

        let back2 = navigator.goBack()
        XCTAssertEqual(back2, "/path/A.swift")
        XCTAssertEqual(navigator.currentIndex, 0)
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertTrue(navigator.canGoForward)

        // 不能再后退
        XCTAssertNil(navigator.goBack())

        // 前进
        let fwd1 = navigator.goForward()
        XCTAssertEqual(fwd1, "/path/B.swift")
        XCTAssertEqual(navigator.currentIndex, 1)
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertTrue(navigator.canGoForward)

        let fwd2 = navigator.goForward()
        XCTAssertEqual(fwd2, "/path/C.swift")
        XCTAssertEqual(navigator.currentIndex, 2)
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)

        // 不能再前进
        XCTAssertNil(navigator.goForward())
    }

    func testRecordSameConsecutivePathDoesNotDuplicate() {
        navigator.record(path: "/path/A.swift")
        navigator.record(path: "/path/A.swift")
        navigator.record(path: "/path/A.swift")

        XCTAssertEqual(navigator.entries.count, 1)
        XCTAssertEqual(navigator.currentIndex, 0)
    }

    func testRecordAfterGoBackTruncatesForwardBranch() {
        navigator.record(path: "/path/A.swift")
        navigator.record(path: "/path/B.swift")
        navigator.record(path: "/path/C.swift")

        // 回退到 B
        _ = navigator.goBack()
        XCTAssertEqual(navigator.currentPath, "/path/B.swift")
        XCTAssertTrue(navigator.canGoForward)

        // 在 B 状态记录新文件 D -> 应该截断 C 并将 D 压栈为 [A, B, D]
        navigator.record(path: "/path/D.swift")
        XCTAssertEqual(navigator.entries.count, 3)
        XCTAssertEqual(navigator.entries.map(\.path), ["/path/A.swift", "/path/B.swift", "/path/D.swift"])
        XCTAssertEqual(navigator.currentIndex, 2)
        XCTAssertEqual(navigator.currentPath, "/path/D.swift")
        XCTAssertTrue(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
    }

    func testInternalNavigationDoesNotRecord() {
        navigator.record(path: "/path/A.swift")
        navigator.performInternalNavigation {
            navigator.record(path: "/path/B.swift")
        }
        XCTAssertEqual(navigator.entries.count, 1)
        XCTAssertEqual(navigator.currentPath, "/path/A.swift")
    }

    func testCapacityLimitsFIFO() {
        navigator.record(path: "/path/1.swift")
        navigator.record(path: "/path/2.swift")
        navigator.record(path: "/path/3.swift")
        navigator.record(path: "/path/4.swift")
        navigator.record(path: "/path/5.swift")
        navigator.record(path: "/path/6.swift") // 超出容量 5，淘汰 1

        XCTAssertEqual(navigator.entries.count, 5)
        XCTAssertEqual(navigator.entries.map(\.path), [
            "/path/2.swift",
            "/path/3.swift",
            "/path/4.swift",
            "/path/5.swift",
            "/path/6.swift"
        ])
        XCTAssertEqual(navigator.currentIndex, 4)
    }

    func testClearResetsState() {
        navigator.record(path: "/path/A.swift")
        navigator.record(path: "/path/B.swift")
        navigator.clear()

        XCTAssertEqual(navigator.entries.count, 0)
        XCTAssertEqual(navigator.currentIndex, -1)
        XCTAssertFalse(navigator.canGoBack)
        XCTAssertFalse(navigator.canGoForward)
    }
}
