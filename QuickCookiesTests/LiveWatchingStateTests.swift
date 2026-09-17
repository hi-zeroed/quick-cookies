import XCTest
@testable import QuickCookies

@MainActor
final class LiveWatchingStateTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testInitialState() {
        let state = LiveWatchingState()
        XCTAssertFalse(state.isWatching)
        XCTAssertFalse(state.isLiveTailMode)
        XCTAssertTrue(state.isFollowingTail)
        XCTAssertFalse(state.hasUnreadAppendsWhilePaused)
        XCTAssertFalse(state.isHotReloading)
    }

    func testStartWithLogFileActivatesLiveTailMode() throws {
        let logURL = tempDirectory.appendingPathComponent("debug.log")
        try "Log content".write(to: logURL, atomically: true, encoding: .utf8)

        let state = LiveWatchingState()
        state.start(for: logURL.path, initialFileSize: 11)

        XCTAssertTrue(state.isWatching)
        XCTAssertTrue(state.isLiveTailMode)
        XCTAssertTrue(state.isFollowingTail)
        XCTAssertEqual(state.activePath, logURL.path)

        state.stop()
        XCTAssertFalse(state.isWatching)
        XCTAssertFalse(state.isLiveTailMode)
    }

    func testStartWithCodeFileActivatesNormalWatchMode() throws {
        let codeURL = tempDirectory.appendingPathComponent("Main.swift")
        try "print(42)".write(to: codeURL, atomically: true, encoding: .utf8)

        let state = LiveWatchingState()
        state.start(for: codeURL.path, initialFileSize: 9)

        XCTAssertTrue(state.isWatching)
        XCTAssertFalse(state.isLiveTailMode) // 非 .log 文件不启用 Live Tail 追尾
        XCTAssertEqual(state.activePath, codeURL.path)

        state.stop()
        XCTAssertFalse(state.isWatching)
    }

    func testToggleFollowing() {
        let state = LiveWatchingState()
        state.isLiveTailMode = true
        state.isFollowingTail = true

        state.toggleFollowing()
        XCTAssertFalse(state.isFollowingTail)

        state.hasUnreadAppendsWhilePaused = true
        state.toggleFollowing()
        XCTAssertTrue(state.isFollowingTail)
        XCTAssertFalse(state.hasUnreadAppendsWhilePaused) // 恢复跟随自动清空未读指示
    }

    func testUserScrollAwayAndReturn() {
        let state = LiveWatchingState()
        state.isLiveTailMode = true
        state.isFollowingTail = true

        // 用户向上滑
        state.userScrolledAwayFromBottom()
        XCTAssertFalse(state.isFollowingTail)

        // 用户滑回底部
        state.userScrolledToBottom()
        XCTAssertTrue(state.isFollowingTail)
    }
}
