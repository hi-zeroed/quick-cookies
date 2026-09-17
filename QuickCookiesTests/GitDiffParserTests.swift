import XCTest
@testable import QuickCookies

final class GitDiffParserTests: XCTestCase {

    func testParseEmptyDiff() {
        let report = GitDiffExtractor.parseUnifiedDiff("", fileStatus: .clean)
        XCTAssertEqual(report.status, .clean)
        XCTAssertEqual(report.additions, 0)
        XCTAssertEqual(report.deletions, 0)
        XCTAssertTrue(report.hunks.isEmpty)
        XCTAssertTrue(report.changedLines.isEmpty)
        XCTAssertEqual(report.summaryBadgeText, "")
    }

    func testParseAdditionsHunk() {
        let diff = """
        diff --git a/test.txt b/test.txt
        index 1111111..2222222 100644
        --- a/test.txt
        +++ b/test.txt
        @@ -0,0 +1,3 @@
        +line 1
        +line 2
        +line 3
        """

        let report = GitDiffExtractor.parseUnifiedDiff(diff, fileStatus: .modified)
        XCTAssertEqual(report.status, .modified)
        XCTAssertEqual(report.additions, 3)
        XCTAssertEqual(report.deletions, 0)
        XCTAssertEqual(report.hunks.count, 1)

        let hunk = report.hunks[0]
        XCTAssertEqual(hunk.type, .added)
        XCTAssertEqual(hunk.startLine, 1)
        XCTAssertEqual(hunk.lineCount, 3)
        XCTAssertEqual(report.changedLines[1], .added)
        XCTAssertEqual(report.changedLines[2], .added)
        XCTAssertEqual(report.changedLines[3], .added)
        XCTAssertEqual(report.summaryBadgeText, "+3")
    }

    func testParseModificationsHunk() {
        let diff = """
        diff --git a/test.txt b/test.txt
        index 1111111..2222222 100644
        --- a/test.txt
        +++ b/test.txt
        @@ -10,2 +10,3 @@
        -old line 10
        -old line 11
        +new line 10
        +new line 11
        +new line 12
        """

        let report = GitDiffExtractor.parseUnifiedDiff(diff, fileStatus: .modified)
        XCTAssertEqual(report.status, .modified)
        XCTAssertEqual(report.additions, 3)
        XCTAssertEqual(report.deletions, 2)
        XCTAssertEqual(report.hunks.count, 1)

        let hunk = report.hunks[0]
        XCTAssertEqual(hunk.type, .modified)
        XCTAssertEqual(hunk.startLine, 10)
        XCTAssertEqual(hunk.lineCount, 3)
        XCTAssertEqual(report.summaryBadgeText, "+3 -2")
    }

    func testParseDeletionsHunk() {
        let diff = """
        diff --git a/test.txt b/test.txt
        index 1111111..2222222 100644
        --- a/test.txt
        +++ b/test.txt
        @@ -20,2 +20,0 @@
        -deleted line 20
        -deleted line 21
        """

        let report = GitDiffExtractor.parseUnifiedDiff(diff, fileStatus: .modified)
        XCTAssertEqual(report.status, .modified)
        XCTAssertEqual(report.additions, 0)
        XCTAssertEqual(report.deletions, 2)
        XCTAssertEqual(report.hunks.count, 1)

        let hunk = report.hunks[0]
        XCTAssertEqual(hunk.type, .deleted)
        XCTAssertEqual(hunk.startLine, 20)
        XCTAssertEqual(hunk.lineCount, 0)
        XCTAssertEqual(report.summaryBadgeText, "-2")
    }

    func testNextAndPreviousHunkCycling() {
        let hunk1 = GitDiffHunk(type: .added, startLine: 10, lineCount: 2, oldStartLine: 10, oldLineCount: 0)
        let hunk2 = GitDiffHunk(type: .modified, startLine: 35, lineCount: 5, oldStartLine: 33, oldLineCount: 3)
        let hunk3 = GitDiffHunk(type: .added, startLine: 80, lineCount: 1, oldStartLine: 78, oldLineCount: 0)

        let report = GitDiffReport(
            status: .modified,
            additions: 8,
            deletions: 3,
            hunks: [hunk1, hunk2, hunk3],
            changedLines: [:]
        )

        // 行号在 10 之前 -> 下一个为 hunk1 (10)
        XCTAssertEqual(report.nextHunk(after: 5)?.startLine, 10)

        // 行号在 10 处 -> 下一个为 hunk2 (35)
        XCTAssertEqual(report.nextHunk(after: 10)?.startLine, 35)

        // 行号在 50 处 -> 下一个为 hunk3 (80)
        XCTAssertEqual(report.nextHunk(after: 50)?.startLine, 80)

        // 行号在 80 之后 -> 循环回首个 hunk1 (10)
        XCTAssertEqual(report.nextHunk(after: 90)?.startLine, 10)

        // 上一个 hunk 循环
        XCTAssertEqual(report.previousHunk(before: 100)?.startLine, 80)
        XCTAssertEqual(report.previousHunk(before: 80)?.startLine, 35)
        XCTAssertEqual(report.previousHunk(before: 35)?.startLine, 10)
        XCTAssertEqual(report.previousHunk(before: 10)?.startLine, 80)
    }

    func testUntrackedSummaryBadgeText() {
        let report = GitDiffReport(
            status: .untracked,
            additions: 0,
            deletions: 0,
            hunks: [],
            changedLines: [:]
        )
        XCTAssertEqual(report.summaryBadgeText, "UNTRACKED")
    }
}
