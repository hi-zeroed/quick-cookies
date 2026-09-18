import XCTest
import Combine
import Observation
@testable import QuickCookies

final class GoToLineStateTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    func test_initialState_isNotPresented() {
        let state = GoToLineState()
        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.totalLines, 1)
        XCTAssertNil(state.errorMessage)
    }

    func test_present_updatesState() {
        let state = GoToLineState()
        state.present(totalLines: 150)
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.totalLines, 150)
        XCTAssertEqual(state.inputLine, "")
        XCTAssertNil(state.errorMessage)
    }

    func test_submit_validLine_emitsTriggerAndDismisses() {
        let state = GoToLineState()
        state.present(totalLines: 100)
        state.inputLine = "42"

        var receivedLine: Int?
        state.jumpToLineTrigger
            .sink { line in
                receivedLine = line
            }
            .store(in: &cancellables)

        state.submit()

        XCTAssertEqual(receivedLine, 42)
        XCTAssertFalse(state.isPresented)
    }

    func test_submit_outOfBounds_clampsToTotalLines() {
        let state = GoToLineState()
        state.present(totalLines: 80)
        state.inputLine = "120"

        var receivedLine: Int?
        state.jumpToLineTrigger
            .sink { line in
                receivedLine = line
            }
            .store(in: &cancellables)

        state.submit()

        XCTAssertEqual(receivedLine, 80)
        XCTAssertFalse(state.isPresented)
    }

    func test_submit_invalidCharacters_setsErrorMessage() {
        let state = GoToLineState()
        state.present(totalLines: 100)
        state.inputLine = "abc"

        var didTrigger = false
        state.jumpToLineTrigger
            .sink { _ in
                didTrigger = true
            }
            .store(in: &cancellables)

        state.submit()

        XCTAssertFalse(didTrigger)
        XCTAssertTrue(state.isPresented)
        XCTAssertNotNil(state.errorMessage)
    }

    func test_dismiss_resetsState() {
        let state = GoToLineState()
        state.present(totalLines: 50)
        state.inputLine = "25"
        state.dismiss()

        XCTAssertFalse(state.isPresented)
        XCTAssertEqual(state.inputLine, "")
        XCTAssertNil(state.errorMessage)
    }

    func test_updateTotalLines_clampsToMinimumOne() {
        let state = GoToLineState()
        state.updateTotalLines(0)
        XCTAssertEqual(state.totalLines, 1)

        state.updateTotalLines(350)
        XCTAssertEqual(state.totalLines, 350)

        state.updateTotalLines(-10)
        XCTAssertEqual(state.totalLines, 1)
    }

    func test_updateTotalLines_sameValue_doesNotTriggerObservation() {
        let state = GoToLineState()
        state.updateTotalLines(50)

        var changeTriggered = false
        withObservationTracking {
            _ = state.totalLines
        } onChange: {
            changeTriggered = true
        }

        // 传入相同的值，应当被 guard 拦截，不触发 Observation 变更通知
        state.updateTotalLines(50)
        XCTAssertFalse(changeTriggered)

        // 传入不同的值，应触发 Observation 变更通知
        state.updateTotalLines(60)
        XCTAssertTrue(changeTriggered)
    }
}
