import XCTest
import Combine
@testable import QuickCookies

@MainActor
final class GitDiffStateTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func testInitialState() {
        let state = GitDiffState()
        XCTAssertEqual(state.report, .empty)
        XCTAssertFalse(state.isLoading)
        XCTAssertEqual(state.currentHunkIndex, 0)
        XCTAssertNil(state.activePath)
    }

    func testLoadDiffNotInRepo() async throws {
        let state = GitDiffState()
        let nonRepoPath = "/tmp/quickcookies_non_existent_\(UUID().uuidString)/test.txt"

        state.loadDiff(for: nonRepoPath)

        // 等待微任务完成
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(state.report.status, .notInRepo)
        XCTAssertFalse(state.isLoading)
    }

    func testHunkNavigation() {
        let state = GitDiffState()

        let hunk1 = GitDiffHunk(type: .added, startLine: 12, lineCount: 2, oldStartLine: 12, oldLineCount: 0)
        let hunk2 = GitDiffHunk(type: .modified, startLine: 45, lineCount: 3, oldStartLine: 45, oldLineCount: 2)

        state.report = GitDiffReport(
            status: .modified,
            additions: 5,
            deletions: 2,
            hunks: [hunk1, hunk2],
            changedLines: [:]
        )

        var jumpedLines: [Int] = []
        state.jumpToLineSubject
            .sink { jumpedLines.append($0) }
            .store(in: &cancellables)

        // 首次调用 jumpToNextHunk: 从 0 到 1 (hunk2, startLine 45)
        state.jumpToNextHunk()
        XCTAssertEqual(state.currentHunkIndex, 1)
        XCTAssertEqual(jumpedLines.last, 45)

        // 再次调用: 循环回 0 (hunk1, startLine 12)
        state.jumpToNextHunk()
        XCTAssertEqual(state.currentHunkIndex, 0)
        XCTAssertEqual(jumpedLines.last, 12)

        // 上一个 hunk 循环
        state.jumpToPreviousHunk()
        XCTAssertEqual(state.currentHunkIndex, 1)
        XCTAssertEqual(jumpedLines.last, 45)
    }

    func testReset() {
        let state = GitDiffState()
        state.report = GitDiffReport(status: .modified, additions: 2, deletions: 1, hunks: [], changedLines: [:])
        state.currentHunkIndex = 3

        state.reset()

        XCTAssertEqual(state.report, .empty)
        XCTAssertEqual(state.currentHunkIndex, 0)
        XCTAssertNil(state.activePath)
        XCTAssertFalse(state.isLoading)
    }
}
