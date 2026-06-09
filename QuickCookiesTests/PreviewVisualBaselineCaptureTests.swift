import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import QuickCookies

@MainActor
final class PreviewVisualBaselineCaptureTests: XCTestCase {
    override func tearDown() {
        QuickLookOverlay.shared.close()
        super.tearDown()
    }

    func testCaptureMarkdownPreviewVisualBaselineWhenEnabled() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["QUICKCOOKIES_CAPTURE_PREVIEW_BASELINE"] == "1",
            "Set QUICKCOOKIES_CAPTURE_PREVIEW_BASELINE=1 to capture a local visual baseline."
        )

        let outputDirectory = URL(fileURLWithPath: "docs/visual-baselines/preview-interaction-redesign", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let sampleDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("quickcookies-visual-baseline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sampleDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: sampleDirectory)
        }

        let sampleFile = sampleDirectory.appendingPathComponent("baseline.md")
        try """
        # QuickCookies Visual Baseline

        This Markdown file is opened by the visual baseline capture test.

        - The preview window should be focused.
        - The HUD card should keep its accepted blur, corner radius, shadow, and spacing.
        - This capture is only a baseline artifact; it is not an automated visual assertion.
        """.write(to: sampleFile, atomically: true, encoding: .utf8)

        let target = PreviewTarget(
            originalPath: sampleFile.path,
            resolvedPath: sampleFile.path,
            renderType: .markdown,
            language: "markdown",
            displayName: sampleFile.lastPathComponent
        )
        let session = PreviewSession()
        session.open(target: target, source: .service)

        QuickLookOverlay.shared.present(session: session)
        session.markReady()

        try await waitUntil(timeout: 5) {
            QuickLookOverlay.shared.currentWindow != nil
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let window = try XCTUnwrap(QuickLookOverlay.shared.currentWindow)
        let screenshot = try XCTUnwrap(
            captureWindowImage(window),
            "Unable to capture preview window image."
        )
        let destination = outputDirectory.appendingPathComponent("markdown-preview-xctest.png")
        try writePNGImage(screenshot, to: destination)

        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("Timed out waiting for visual baseline condition.")
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func captureWindowImage(_ window: NSWindow) -> CGImage? {
        guard let windowID = CGWindowID(exactly: window.windowNumber) else {
            return nil
        }

        return CGWindowListCreateImage(
            .null,
            [.optionIncludingWindow],
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
    }

    private func writePNGImage(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(
                domain: "PreviewVisualBaselineCaptureTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG destination."]
            )
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(
                domain: "PreviewVisualBaselineCaptureTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to finalize PNG destination."]
            )
        }
    }
}
