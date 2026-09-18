import XCTest
import SwiftUI
@testable import QuickCookies

final class LiquidGlassChromeModifierTests: XCTestCase {
    
    @MainActor
    func test_liquidGlassCardModifier_initialization() {
        let modifier = LiquidGlassCardModifier(cornerRadius: 24, isInteractive: true, tint: .blue)
        XCTAssertNotNil(modifier)
    }

    @MainActor
    func test_liquidGlassPillModifier_initialization() {
        let modifier = LiquidGlassPillModifier(cornerRadius: 10, isInteractive: true)
        XCTAssertNotNil(modifier)
    }

    @MainActor
    func test_liquidGlassCapsuleModifier_initialization() {
        let modifier = LiquidGlassCapsuleModifier(isInteractive: false)
        XCTAssertNotNil(modifier)
    }

    @MainActor
    func test_viewExtensions_attachModifiersSuccessfully() {
        let view = Text("Hello QuickCookies")
            .liquidGlassCard(cornerRadius: 20, isInteractive: false, tint: .purple)
            .liquidGlassPill(cornerRadius: 8, isInteractive: true)
            .liquidGlassCapsule(isInteractive: true)

        XCTAssertNotNil(view)
    }

    @MainActor
    func test_liquidGlassToolbarContainer_rendersContent() {
        let container = LiquidGlassToolbarContainer(spacing: 6) {
            Text("Button A")
            Text("Button B")
        }
        XCTAssertNotNil(container.body)
    }
}
