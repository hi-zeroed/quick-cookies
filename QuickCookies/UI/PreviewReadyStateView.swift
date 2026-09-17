import SwiftUI
import AppKit

/// 未选中文件唤起时的轻量极简就绪卡片视图
struct PreviewReadyStateView: View {
    @Environment(\.colorScheme) var colorScheme
    let errorMessage: String?
    let onInspectClipboard: () -> Void

    @State private var sniffResult: ClipboardSniffResult = .empty
    @State private var isClipboardButtonHovered: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // 顶部拟物晶体图标
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16),
                                Color.purple.opacity(colorScheme == .dark ? 0.16 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.6),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: Color.accentColor.opacity(0.15), radius: 10, x: 0, y: 4)

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color.accentColor)
            }

            // 标题与副标题
            VStack(spacing: 6) {
                Text("QuickCookies Ready".localized())
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundColor(Color.appText)

                Text("Select a file in Finder to preview instantly".localized())
                    .font(.system(size: 12, design: .default))
                    .foregroundColor(Color.appText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // 剪贴板感知微胶囊
            if sniffResult != .empty {
                Button(action: onInspectClipboard) {
                    HStack(spacing: 8) {
                        Image(systemName: clipboardIconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.accentColor)

                        Text(clipboardDescription)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.appText.opacity(0.9))

                        Spacer(minLength: 4)

                        Text("⌃⌥V")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.appText.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                            )
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(isClipboardButtonHovered ? 0.12 : 0.07) : Color.white.opacity(isClipboardButtonHovered ? 0.65 : 0.45))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(isClipboardButtonHovered ? 0.25 : 0.12) : Color.black.opacity(isClipboardButtonHovered ? 0.15 : 0.08),
                                lineWidth: 0.8
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isClipboardButtonHovered = $0 }
                .padding(.horizontal, 32)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            Spacer()

            // 底部快捷键提示速查栏
            HStack(spacing: 12) {
                shortcutHint(key: "⌘ ⌘", label: "Preview Selection".localized())
                shortcutHint(key: "⌃⌥V", label: "Clipboard".localized())
                shortcutHint(key: "Esc", label: "Close".localized())
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            sniffResult = ClipboardContentSniffer.sniff()
        }
    }

    private var clipboardIconName: String {
        switch sniffResult {
        case .image:
            return "photo.fill"
        case .json:
            return "curlybraces"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .markdown:
            return "doc.richtext"
        case .fileURL:
            return "doc.fill"
        default:
            return "doc.on.clipboard.fill"
        }
    }

    private var clipboardDescription: String {
        switch sniffResult {
        case .code(_, let lang, _):
            return String(format: "Clipboard: %@ Code (Click to inspect)".localized(), lang)
        case .json:
            return "Clipboard: JSON Data (Click to inspect)".localized()
        case .markdown:
            return "Clipboard: Markdown (Click to inspect)".localized()
        case .image:
            return "Clipboard: Image (Click to inspect)".localized()
        case .plainText:
            return "Clipboard: Text (Click to inspect)".localized()
        case .fileURL(let path):
            let name = URL(fileURLWithPath: path).lastPathComponent
            return String(format: "Clipboard: %@ (Click to inspect)".localized(), name)
        case .empty:
            return ""
        }
    }

    @ViewBuilder
    private func shortcutHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color.appText.opacity(0.55))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                )
            Text(label)
                .font(.system(size: 10, design: .default))
                .foregroundColor(Color.appText.opacity(0.45))
        }
    }
}
