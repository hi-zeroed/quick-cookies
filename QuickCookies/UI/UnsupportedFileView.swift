import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct UnsupportedFileView: View {
    @Environment(\.colorScheme) var colorScheme
    let filePath: String?
    let errorMessage: String?
    
    // 获取文件的图标
    private var fileIcon: NSImage {
        if let path = filePath, FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        // 如果文件不存在或路径为空，返回默认的未知文件图标
        return NSWorkspace.shared.icon(for: .item)
    }
    
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
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 居中的大图标（类似原生 Quick Look）
            Image(nsImage: fileIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 8, y: 4)
            
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
                Text(errorMessage?.localized() ?? "不支持此文件类型".localized())
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color.appText.opacity(0.8))
                
                Text("按 Esc 键关闭窗口".localized())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.appText.opacity(0.35))
            }
            
            // 用默认应用打开的按钮（如果有路径）
            if let path = filePath {
                Button(action: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                }) {
                    Text("使用默认应用打开".localized())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appText.opacity(0.9))
                        .padding(.horizontal, 20)
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
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 16)
    }
}
