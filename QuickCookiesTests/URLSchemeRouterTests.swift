import XCTest
@testable import QuickCookies

final class URLSchemeRouterTests: XCTestCase {

    func test_nonQuickCookiesScheme_returnsNil() {
        let url = URL(string: "https://preview?path=/Users/test/file.swift")!
        XCTAssertNil(URLSchemeRouter.parse(url: url))
    }

    func test_nonPreviewHost_returnsNil() {
        let url = URL(string: "quickcookies://other?path=/Users/test/file.swift")!
        XCTAssertNil(URLSchemeRouter.parse(url: url))
    }

    func test_openFile_withPathOnly() {
        let url = URL(string: "quickcookies://preview?path=%2FUsers%2Ftest%2Ffile.swift")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .openFile(path: "/Users/test/file.swift", line: nil))
    }

    func test_openFile_withPathAndLine() {
        let url = URL(string: "quickcookies://preview?path=%2FUsers%2Ftest%2Ffile.swift&line=142")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .openFile(path: "/Users/test/file.swift", line: 142))
    }

    func test_inspectClipboard() {
        let url = URL(string: "quickcookies://preview?source=clipboard")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .inspectClipboard)
    }

    func test_shareCard_withoutPath_directStudio() {
        let url = URL(string: "quickcookies://preview?action=shareCard")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .openShareCard(path: nil))
    }

    func test_shareCard_withModeCard() {
        let url = URL(string: "quickcookies://preview?mode=card")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .openShareCard(path: nil))
    }

    func test_shareCard_withSpecificPath() {
        let url = URL(string: "quickcookies://preview?action=shareCard&path=%2FUsers%2Ftest%2FApp.swift")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .openShareCard(path: "/Users/test/App.swift"))
    }

    func test_finderSelection_explicitAction() {
        let url = URL(string: "quickcookies://preview?action=finderSelection")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .triggerFinderSelection)
    }

    func test_finderSelection_emptyQueryParams() {
        let url = URL(string: "quickcookies://preview")!
        let action = URLSchemeRouter.parse(url: url)
        XCTAssertEqual(action, .triggerFinderSelection)
    }
}
