import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct UnsupportedFileView: View {
    @Environment(\.colorScheme) var colorScheme
    let filePath: String?
    let errorMessage: String?
    
    // 获取文件大小
    private var fileSizeString: String? {
        guard let path = filePath else { return nil }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            if let size = attrs[.size] as? UInt64 {
                return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
            }
        } catch {}
        return nil
    }
    
    // 获取文件修改时间
    private var fileModificationDateString: String? {
        guard let path = filePath else { return nil }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            if let date = attrs[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        } catch {}
        return nil
    }
    
    var onShowToast: ((String, String?) -> Void)? = nil
    @State private var isShowingHex: Bool = false

    var body: some View {
        if isShowingHex, let path = filePath {
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isShowingHex = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 10, weight: .bold))
                            Text("Summary".localized())
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color.appText.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.appText.opacity(colorScheme == .dark ? 0.08 : 0.05))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.appText.opacity(colorScheme == .dark ? 0.03 : 0.02))

                HexPreviewView(path: path, isDark: colorScheme == .dark, onShowToast: onShowToast)
            }
        } else {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 6) {
                    // 文件名
                    if let path = filePath {
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(Color.appText)
                            .lineLimit(1)
                            .padding(.horizontal, 24)
                    }
                    
                    // 文件大小及修改时间
                    if let size = fileSizeString, let date = fileModificationDateString {
                        Text("\(size)  •  \(date)")
                            .font(.system(size: 11, design: .default))
                            .foregroundColor(Color.appText.opacity(0.6))
                    }
                }
                
                // 提示信息
                VStack(spacing: 4) {
                    Text(errorMessage?.localized() ?? "Unsupported file type (detail)".localized())
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(Color.appText.opacity(0.8))
                }
                
                // 操作按钮组（打开 + 十六进制检视）
                if let path = filePath {
                    HStack(spacing: 12) {
                        Button(action: {
                            NSWorkspace.shared.open(URL(fileURLWithPath: path))
                        }) {
                            Text("使用默认应用打开".localized())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appText.opacity(0.9))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isShowingHex = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "ellipsis.curlybraces")
                                    .font(.system(size: 11))
                                Text("Inspect in Hex".localized())
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color.accentColor.opacity(0.95))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 16)
        }
    }
}
