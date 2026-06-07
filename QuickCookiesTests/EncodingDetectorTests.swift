import XCTest
@testable import QuickCookies

final class EncodingDetectorTests: XCTestCase {
    func testDetectUTF8Text() {
        let text = "Hello, 世界"
        let data = text.data(using: .utf8)!

        XCTAssertEqual(EncodingDetector.detect(data: data), .utf8)
    }

    func testDetectUTF16TextWithBOM() {
        let text = "Hello, UTF16"
        let data = text.data(using: .utf16)!

        XCTAssertEqual(EncodingDetector.detect(data: data), .utf16)
    }

    func testDetectGB18030Text() {
        let raw = CFStringConvertEncodingToNSStringEncoding(0x0631)
        let encoding = String.Encoding(rawValue: raw)
        let text = "测试中文"

        guard let data = text.data(using: encoding) else {
            return XCTFail("Unable to build GB18030 sample data")
        }

        XCTAssertEqual(EncodingDetector.detect(data: data), encoding)
    }

    func testInvalidBinaryLikeDataFallsBackToUTF8() {
        let data = Data([0xFF, 0xFF, 0x00, 0x12, 0x85])

        XCTAssertEqual(EncodingDetector.detect(data: data), .utf8)
    }
}
