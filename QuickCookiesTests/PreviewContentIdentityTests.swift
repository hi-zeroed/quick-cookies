import XCTest
@testable import QuickCookies

final class PreviewContentIdentityTests: XCTestCase {
    func test_reloadGenerationPolicy_doesNotBumpForFirstLoad() {
        XCTAssertFalse(
            PreviewContentReloadIdentityPolicy.shouldBumpGeneration(
                previousPath: nil,
                nextPath: "/tmp/demo.docx"
            )
        )
    }

    func test_reloadGenerationPolicy_doesNotBumpForDifferentPath() {
        XCTAssertFalse(
            PreviewContentReloadIdentityPolicy.shouldBumpGeneration(
                previousPath: "/tmp/old.docx",
                nextPath: "/tmp/new.docx"
            )
        )
    }

    func test_reloadGenerationPolicy_bumpsForSamePathReload() {
        XCTAssertTrue(
            PreviewContentReloadIdentityPolicy.shouldBumpGeneration(
                previousPath: "/tmp/demo.docx",
                nextPath: "/tmp/demo.docx"
            )
        )
    }

    func test_key_changesWhenPathChanges() {
        let first = PreviewContentIdentity.makeKey(
            path: "/tmp/first.md",
            renderType: .markdown,
            mode: .preview
        )
        let second = PreviewContentIdentity.makeKey(
            path: "/tmp/second.md",
            renderType: .markdown,
            mode: .preview
        )

        XCTAssertNotEqual(first, second)
    }

    func test_key_changesWhenRenderTypeChanges() {
        let first = PreviewContentIdentity.makeKey(
            path: "/tmp/demo",
            renderType: .markdown,
            mode: .preview
        )
        let second = PreviewContentIdentity.makeKey(
            path: "/tmp/demo",
            renderType: .code,
            mode: .preview
        )

        XCTAssertNotEqual(first, second)
    }

    func test_key_changesWhenModeChanges() {
        let previewKey = PreviewContentIdentity.makeKey(
            path: "/tmp/demo.md",
            renderType: .markdown,
            mode: .preview
        )
        let editKey = PreviewContentIdentity.makeKey(
            path: "/tmp/demo.md",
            renderType: .markdown,
            mode: .edit
        )

        XCTAssertNotEqual(previewKey, editKey)
    }

    func test_key_isStableWithoutErrorStateInput() {
        let baseline = PreviewContentIdentity.makeKey(
            path: "/tmp/demo.md",
            renderType: .markdown,
            mode: .preview
        )
        let afterTransientReloadState = PreviewContentIdentity.makeKey(
            path: "/tmp/demo.md",
            renderType: .markdown,
            mode: .preview
        )

        XCTAssertEqual(baseline, afterTransientReloadState)
    }
}
