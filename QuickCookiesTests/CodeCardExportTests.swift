import XCTest
import SwiftUI
@testable import QuickCookies

final class CodeCardExportTests: XCTestCase {
    
    func testPresetEnumerationAndNames() {
        let allPresets = CardGradientPreset.allCases
        XCTAssertEqual(allPresets.count, 8)
        
        let expectedNames = ["Aurora", "Sunset", "Ocean", "Charcoal", "Cyberpunk", "Cosmic", "Emerald", "Monochrome"]
        for preset in allPresets {
            XCTAssertTrue(expectedNames.contains(preset.rawValue))
            XCTAssertFalse(preset.displayName.isEmpty)
            XCTAssertEqual(preset.id, preset.rawValue)
            _ = preset.primaryColor
        }
    }
    
    func testPaddingPresets() {
        let paddings = CardPaddingPreset.allCases
        XCTAssertEqual(paddings.count, 3)
        XCTAssertEqual(CardPaddingPreset.compact.rawValue, 20.0)
        XCTAssertEqual(CardPaddingPreset.regular.rawValue, 32.0)
        XCTAssertEqual(CardPaddingPreset.spacious.rawValue, 44.0)
        
        for padding in paddings {
            XCTAssertFalse(padding.displayName.isEmpty)
        }
    }
    
    func testContentModes() {
        let modes = CardContentMode.allCases
        XCTAssertEqual(modes.count, 2)
        XCTAssertTrue(modes.contains(.code))
        XCTAssertTrue(modes.contains(.quote))
        
        for mode in modes {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertFalse(mode.iconName.isEmpty)
        }
    }
    
    func testColorThemes() {
        let themes = CardColorTheme.allCases
        XCTAssertEqual(themes.count, 2)
        XCTAssertTrue(themes.contains(.dark))
        XCTAssertTrue(themes.contains(.light))
        
        for theme in themes {
            XCTAssertFalse(theme.displayName.isEmpty)
            XCTAssertFalse(theme.iconName.isEmpty)
        }
    }
    
    func testAspectRatios() {
        let ratios = CardAspectRatio.allCases
        XCTAssertEqual(ratios.count, 3)
        XCTAssertTrue(ratios.contains(.auto))
        XCTAssertTrue(ratios.contains(.square))
        XCTAssertTrue(ratios.contains(.landscape))
        
        for ratio in ratios {
            XCTAssertFalse(ratio.displayName.isEmpty)
        }
    }
    
    func testCardWidthPresets() {
        let widths = CardWidthPreset.allCases
        XCTAssertEqual(widths.count, 3)
        XCTAssertEqual(CardWidthPreset.compact.width, 640.0)
        XCTAssertEqual(CardWidthPreset.standard.width, 780.0)
        XCTAssertEqual(CardWidthPreset.wide.width, 860.0)
        
        for width in widths {
            XCTAssertFalse(width.displayName.isEmpty)
            XCTAssertEqual(width.id, width.rawValue)
        }
    }
    
    func testDefaultConfigValues() {
        let config = CodeCardConfig()
        XCTAssertEqual(config.mode, .code)
        XCTAssertEqual(config.colorTheme, .dark)
        XCTAssertEqual(config.aspectRatio, .auto)
        XCTAssertEqual(config.preset, .aurora)
        XCTAssertEqual(config.padding, .regular)
        XCTAssertEqual(config.cardWidthPreset, .standard)
        XCTAssertFalse(config.isTransparentBackground)
        XCTAssertTrue(config.showAmbientGlow)
        XCTAssertTrue(config.showLineNumbers)
        XCTAssertTrue(config.showWatermark)
        XCTAssertTrue(config.showTrafficLights)
        XCTAssertEqual(config.fontName, "SF Mono")
        XCTAssertEqual(config.fontSize, 13.0)
        XCTAssertTrue(config.focusedLineIndices.isEmpty)
    }
    
    @MainActor
    func testImageRendererExportPNGData() {
        let testView = Text("Hello QuickCookies")
            .padding()
            .background(Color.blue)
        
        let pngData = CodeCardRenderer.renderToPNGData(view: testView, scale: 1.0)
        XCTAssertNotNil(pngData)
        
        guard let data = pngData, data.count > 8 else {
            XCTFail("PNG 数据为空或长度不足")
            return
        }
        
        // 校验 PNG 魔数: 89 50 4E 47 0D 0A 1A 0A
        let pngHeader = [UInt8](data.prefix(8))
        XCTAssertEqual(pngHeader[0], 0x89)
        XCTAssertEqual(pngHeader[1], 0x50) // P
        XCTAssertEqual(pngHeader[2], 0x4E) // N
        XCTAssertEqual(pngHeader[3], 0x47) // G
    }
    
    @MainActor
    func testSnapshotViewRendering() {
        let content = "let message = \"Hello, QuickCookies!\"\nprint(message)"
        let config = CodeCardConfig(preset: .sunset, padding: .compact, showLineNumbers: true, showWatermark: true)
        
        let snapshotView = CodeCardSnapshotView(
            title: "Test.swift",
            code: content,
            language: "swift",
            config: config
        )
        
        let image = CodeCardRenderer.renderToImage(view: snapshotView, scale: 2.0)
        XCTAssertNotNil(image)
        if let img = image {
            XCTAssertGreaterThan(img.size.width, 0)
            XCTAssertGreaterThan(img.size.height, 0)
        }
    }
    
    @MainActor
    func testQuoteSnapshotViewRendering() {
        let quote = "Stay hungry, stay foolish.\n-- Steve Jobs"
        var config = CodeCardConfig(preset: .aurora, padding: .regular, showLineNumbers: false, showWatermark: true)
        config.mode = .quote
        
        let snapshotView = CodeCardSnapshotView(
            title: "Quote.md",
            code: quote,
            language: nil,
            config: config
        )
        
        let image = CodeCardRenderer.renderToImage(view: snapshotView, scale: 2.0)
        XCTAssertNotNil(image)
        if let img = image {
            XCTAssertGreaterThan(img.size.width, 0)
            XCTAssertGreaterThan(img.size.height, 0)
        }
    }
    
    @MainActor
    func testLightModeAndAspectRatiosRendering() {
        let quote = "Design is not just what it looks like and feels like. Design is how it works."
        var config = CodeCardConfig()
        config.mode = .quote
        config.colorTheme = .light
        config.aspectRatio = .square
        config.preset = .sunset
        config.showAmbientGlow = true
        
        let snapshotView = CodeCardSnapshotView(
            title: "Quote.txt",
            code: quote,
            language: nil,
            config: config
        )
        
        let image = CodeCardRenderer.renderToImage(view: snapshotView, scale: 2.0)
        XCTAssertNotNil(image)
        if let img = image {
            XCTAssertGreaterThan(img.size.width, 0)
            XCTAssertGreaterThan(img.size.height, 0)
        }
        
        // 测试透明背景与横屏比例
        var landscapeConfig = config
        landscapeConfig.aspectRatio = .landscape
        landscapeConfig.isTransparentBackground = true
        let landscapeView = CodeCardSnapshotView(
            title: "Quote.txt",
            code: quote,
            language: nil,
            config: landscapeConfig
        )
        let landscapeImg = CodeCardRenderer.renderToImage(view: landscapeView, scale: 2.0)
        XCTAssertNotNil(landscapeImg)
    }
    
    func testLanguageFormatterExplicitCustomLanguage() {
        let badge1 = CodeCardLanguageFormatter.format(customLanguage: "TSX")
        XCTAssertEqual(badge1, "TSX")
        
        let badge2 = CodeCardLanguageFormatter.format(customLanguage: "java")
        XCTAssertEqual(badge2, "JAVA")
        
        // Auto 应该降级到后续逻辑
        let badge3 = CodeCardLanguageFormatter.format(customLanguage: "Auto", detectedLanguage: "swift")
        XCTAssertEqual(badge3, "SWIFT")
    }
    
    func testLanguageFormatterDetectedLanguageMapping() {
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "typescript"), "TS")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "tsx"), "TSX")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "javascript"), "JS")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "java"), "JAVA")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "python"), "PYTHON")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "rust"), "RUST")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "go"), "GO")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "cpp"), "C++")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "csharp"), "C#")
        XCTAssertEqual(CodeCardLanguageFormatter.format(detectedLanguage: "json"), "JSON")
    }
    
    func testLanguageFormatterTitleAndExtensionParsing() {
        XCTAssertEqual(CodeCardLanguageFormatter.format(title: "App.tsx"), "TSX")
        XCTAssertEqual(CodeCardLanguageFormatter.format(title: "index.js"), "JS")
        XCTAssertEqual(CodeCardLanguageFormatter.format(title: "User.java"), "JAVA")
        XCTAssertEqual(CodeCardLanguageFormatter.format(title: "Clipboard (Swift)"), "SWIFT")
        XCTAssertEqual(CodeCardLanguageFormatter.format(title: "Clipboard (JavaScript)"), "JS")
    }
    
    func testLanguageFormatterContentSniffing() {
        let tsxCode = "import React from 'react';\nexport const MyComp: React.FC = () => <div>Hello</div>;"
        XCTAssertEqual(CodeCardLanguageFormatter.format(code: tsxCode), "TSX")
        
        let swiftCode = "import SwiftUI\nstruct ContentView: View { var body: some View { Text(\"Hi\") } }"
        XCTAssertEqual(CodeCardLanguageFormatter.format(code: swiftCode), "SWIFT")
        
        let pyCode = "def calculate_sum(a, b):\n    print(a + b)\n    return a + b"
        XCTAssertEqual(CodeCardLanguageFormatter.format(code: pyCode), "PYTHON")
        
        let jsonCode = "{\n  \"name\": \"QuickCookies\",\n  \"version\": \"1.0.0\"\n}"
        XCTAssertEqual(CodeCardLanguageFormatter.format(code: jsonCode), "JSON")
    }
    
    func testLanguageFormatterFallback() {
        let unknown = CodeCardLanguageFormatter.format(title: "unknown.xyz", code: "plain text with no keywords")
        XCTAssertEqual(unknown, "CODE")
    }
    
    func testPopularLanguagesList() {
        let popular = CodeCardLanguageFormatter.popularLanguages
        XCTAssertTrue(popular.contains("Auto"))
        XCTAssertTrue(popular.contains("TSX"))
        XCTAssertTrue(popular.contains("JS"))
        XCTAssertTrue(popular.contains("JAVA"))
        XCTAssertTrue(popular.contains("SWIFT"))
        XCTAssertTrue(popular.contains("PYTHON"))
        XCTAssertTrue(popular.contains("RUST"))
    }
    
    @MainActor
    func testSnapshotViewRenderingWithLanguageBadge() {
        let code = "const greet = (name: string) => `Hello, ${name}!`;"
        var config = CodeCardConfig()
        config.customLanguage = "TSX"
        
        let snapshotView = CodeCardSnapshotView(
            title: "clipboard.txt",
            code: code,
            language: "typescript",
            config: config
        )
        
        let image = CodeCardRenderer.renderToImage(view: snapshotView, scale: 2.0)
        XCTAssertNotNil(image)
    }
    
    func testHighlightrLanguageMapping() {
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "TSX"), "typescript")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "TS"), "typescript")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "JS"), "javascript")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "JAVA"), "java")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "C++"), "cpp")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "C#"), "cs")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "BASH"), "bash")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "PYTHON"), "python")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "RUST"), "rust")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "GO"), "go")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "JSON"), "json")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "SQL"), "sql")
    }
    
    @MainActor
    func testLanguageSwitchingProducesHighlightedOutput() {
        let code = "const message: string = \"Hello QuickCookies\";\nfunction test() { return message; }"
        var config = CodeCardConfig()
        config.customLanguage = "TSX"
        
        let snapshotView1 = CodeCardSnapshotView(
            title: "snippet.txt",
            code: code,
            language: nil,
            config: config
        )
        let img1 = CodeCardRenderer.renderToImage(view: snapshotView1, scale: 1.0)
        XCTAssertNotNil(img1)
        
        // 切换语言为 JS
        config.customLanguage = "JS"
        let snapshotView2 = CodeCardSnapshotView(
            title: "snippet.txt",
            code: code,
            language: nil,
            config: config
        )
        let img2 = CodeCardRenderer.renderToImage(view: snapshotView2, scale: 1.0)
        XCTAssertNotNil(img2)
    }

    @MainActor
    func testCodeCardAppliesEditorFontFromSettings() {
        let code = "let x: Int = 42\nprint(x)"
        var config = CodeCardConfig()
        config.customLanguage = "Swift"
        
        let originalFont = Settings.shared.editorFont
        defer { Settings.shared.editorFont = originalFont }
        
        // 1. 设置为 JetBrains Mono
        Settings.shared.editorFont = "JetBrains Mono"
        let viewJB = CodeCardSnapshotView(
            title: "demo.swift",
            code: code,
            language: "swift",
            config: config
        )
        let imgJB = CodeCardRenderer.renderToImage(view: viewJB, scale: 1.0)
        XCTAssertNotNil(imgJB)
        
        // 2. 设置为 System Default (Inter)
        Settings.shared.editorFont = "System Default (Inter)"
        let viewSys = CodeCardSnapshotView(
            title: "demo.swift",
            code: code,
            language: "swift",
            config: config
        )
        let imgSys = CodeCardRenderer.renderToImage(view: viewSys, scale: 1.0)
        XCTAssertNotNil(imgSys)
    }

    func testFailedToSaveImageLocalization() {
        let savedLang = Settings.currentLanguage
        defer { Settings.currentLanguage = savedLang }
        
        Settings.currentLanguage = .en
        let enMsg = String(format: "Failed to save image: %@".localized(), "Disk full")
        XCTAssertEqual(enMsg, "Failed to save image: Disk full")
        
        Settings.currentLanguage = .zhHans
        let zhMsg = String(format: "Failed to save image: %@".localized(), "磁盘已满")
        XCTAssertEqual(zhMsg, "保存卡片图片失败：磁盘已满")
    }

    func testDiffLineClassificationAndSniffing() {
        // 1. 测试单行分类
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("+    let added = true"), .added)
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("-    let removed = false"), .deleted)
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("@@ -10,5 +10,6 @@"), .header)
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("diff --git a/App.swift b/App.swift"), .header)
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("--- a/App.swift"), .header)
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("+++ b/App.swift"), .header)
        XCTAssertEqual(CodeCardDiffAnalyzer.classifyLine("    let normal = 42"), .context)

        // 2. 测试全文特征嗅探
        let diffSample = """
        diff --git a/App.swift b/App.swift
        index 1234567..89abcdef 100644
        --- a/App.swift
        +++ b/App.swift
        @@ -1,3 +1,4 @@
         import SwiftUI
        -let oldVal = 1
        +let newVal = 2
        """
        XCTAssertTrue(CodeCardDiffAnalyzer.isDiffContent(diffSample))
        
        let normalCode = "func hello() { print(\"world\") }"
        XCTAssertFalse(CodeCardDiffAnalyzer.isDiffContent(normalCode))

        // 3. 测试语言推断与映射
        let badge = CodeCardLanguageFormatter.format(code: diffSample)
        XCTAssertEqual(badge, "DIFF")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "diff"), "diff")
        XCTAssertEqual(CodeCardLanguageFormatter.highlightrLanguage(from: "patch"), "diff")
    }

    @MainActor
    func testLineFocusConfigAndSnapshotRendering() {
        var config = CodeCardConfig()
        config.focusedLineIndices = [1, 2] // 聚焦第 2, 3 行
        XCTAssertEqual(config.focusedLineIndices.count, 2)
        XCTAssertTrue(config.focusedLineIndices.contains(1))
        XCTAssertTrue(config.focusedLineIndices.contains(2))
        XCTAssertFalse(config.focusedLineIndices.contains(0))

        var toggledIndex: Int? = nil
        let testCode = "line 0\nline 1\nline 2\nline 3"
        let snapshot = CodeCardSnapshotView(
            title: "focus_test.swift",
            code: testCode,
            language: "swift",
            config: config,
            onToggleLineFocus: { idx in
                toggledIndex = idx
            }
        )
        
        let img = CodeCardRenderer.renderToImage(view: snapshot, scale: 1.0)
        XCTAssertNotNil(img)
        
        snapshot.onToggleLineFocus?(3)
        XCTAssertEqual(toggledIndex, 3)
    }

    func testNewGradientPresets() {
        let ocean = CardGradientPreset.ocean
        XCTAssertEqual(ocean.rawValue, "Ocean")
        XCTAssertFalse(ocean.displayName.isEmpty)
        _ = ocean.gradient
        _ = ocean.primaryColor

        let cosmic = CardGradientPreset.cosmic
        XCTAssertEqual(cosmic.rawValue, "Cosmic")
        XCTAssertFalse(cosmic.displayName.isEmpty)
        _ = cosmic.gradient
        _ = cosmic.primaryColor

        let emerald = CardGradientPreset.emerald
        XCTAssertEqual(emerald.rawValue, "Emerald")
        XCTAssertFalse(emerald.displayName.isEmpty)
        _ = emerald.gradient
        _ = emerald.primaryColor
    }

    func testCardZoomModeEnumeration() {
        let modes = CardZoomMode.allCases
        XCTAssertEqual(modes.count, 2)
        XCTAssertTrue(modes.contains(.fit))
        XCTAssertTrue(modes.contains(.actual))
        
        for mode in modes {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }
}

