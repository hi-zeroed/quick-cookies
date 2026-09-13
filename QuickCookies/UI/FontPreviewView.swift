import SwiftUI
import CoreText
import AppKit

public struct FontPreviewView: View {
    public let filePath: String

    @State private var fontName: String = ""
    @State private var familyName: String = ""
    @State private var postScriptName: String = ""
    @State private var glyphCount: Int = 0
    @State private var isRegistered: Bool = false

    public init(filePath: String) {
        self.filePath = filePath
    }

    private func fontAtSize(_ size: CGFloat) -> NSFont {
        if !postScriptName.isEmpty, let font = NSFont(name: postScriptName, size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 顶层字体元数据面板（只读纯净展示）
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(fontName.isEmpty ? URL(fileURLWithPath: filePath).lastPathComponent : fontName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appText)

                    HStack(spacing: 10) {
                        if !familyName.isEmpty {
                            Label(familyName, systemImage: "textformat")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appText.opacity(0.6))
                        }

                        if glyphCount > 0 {
                            Label("\(glyphCount) glyphs".localized(), systemImage: "character.book.closed")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.appText.opacity(0.6))
                        }

                        let ext = URL(fileURLWithPath: filePath).pathExtension.uppercased()
                        Text(ext)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.appText.opacity(0.08))
                            .cornerRadius(4)
                            .foregroundColor(Color.appText.opacity(0.7))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.appBackground.opacity(0.6))

            Divider()
                .opacity(0.25)

            // 标本与瀑布流纯净展示
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 22) {
                    // 核心字样标本看板 (Headline Specimen)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(fontName.isEmpty ? "Specimen" : fontName)
                            .font(Font(fontAtSize(32)))
                            .foregroundColor(Color.appText)
                            .lineLimit(2)

                        Text("The quick brown fox jumps over the lazy dog.")
                            .font(Font(fontAtSize(20)))
                            .foregroundColor(Color.appText.opacity(0.85))
                            .lineLimit(2)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appText.opacity(0.04))
                    .cornerRadius(10)

                    // 级进字阶标本 (Waterfall)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Waterfall".localized())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.appText.opacity(0.4))

                        ForEach([14, 18, 24, 36, 48], id: \.self) { size in
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text("\(size)pt")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(Color.appText.opacity(0.35))
                                    .frame(width: 32, alignment: .trailing)

                                Text("Sphinx of black quartz, judge my vow.")
                                    .font(Font(fontAtSize(CGFloat(size))))
                                    .foregroundColor(Color.appText.opacity(0.9))
                                    .lineLimit(1)
                            }
                        }
                    }

                    // 经典字母表与符号集 (Alphabet & Numerals)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Alphabet & Numerals".localized())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.appText.opacity(0.4))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                                .font(Font(fontAtSize(17)))
                                .foregroundColor(Color.appText.opacity(0.85))
                            Text("abcdefghijklmnopqrstuvwxyz")
                                .font(Font(fontAtSize(17)))
                                .foregroundColor(Color.appText.opacity(0.85))
                            Text("0123456789 • !@#$%^&*()_+{}[]:;\"'<>?,./")
                                .font(Font(fontAtSize(16)))
                                .foregroundColor(Color.appText.opacity(0.75))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appText.opacity(0.03))
                        .cornerRadius(10)
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            registerAndLoadFont()
        }
        .onDisappear {
            unregisterFont()
        }
    }

    private func registerAndLoadFont() {
        let url = URL(fileURLWithPath: filePath)
        var error: Unmanaged<CFError>? = nil
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        isRegistered = success

        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(dataProvider) else {
            return
        }

        let psName = cgFont.postScriptName as String? ?? ""
        let fName = cgFont.fullName as String? ?? psName
        self.postScriptName = psName
        self.fontName = fName

        let ctFont = CTFontCreateWithGraphicsFont(cgFont, 24, nil, nil)
        self.glyphCount = CTFontGetGlyphCount(ctFont)
        if let famName = CTFontCopyFamilyName(ctFont) as String? {
            self.familyName = famName
        }
    }

    private func unregisterFont() {
        if isRegistered {
            let url = URL(fileURLWithPath: filePath)
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
            isRegistered = false
        }
    }
}
