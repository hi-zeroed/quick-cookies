import SwiftUI
import PDFKit
import AppKit

struct MediaPreviewView: View {
    let filePath: String
    let renderType: FileRenderType
    
    var body: some View {
        Group {
            if renderType == .pdf {
                PDFKitView(url: URL(fileURLWithPath: filePath))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appBorder.opacity(0.3), lineWidth: 1)
                    )
            } else if renderType == .image {
                ImageFileView(filePath: filePath)
            } else {
                Text("Unsupported file format".localized())
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A wrapper for PDFView from PDFKit to SwiftUI
struct PDFKitView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.backgroundColor = .clear
        
        // 彻底消除 PDF 页面外边距与投影阴影，防止直角分层残留
        pdfView.pageBreakMargins = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        pdfView.pageShadowsEnabled = false
        
        if let scrollView = pdfView.subviews.first as? NSScrollView {
            scrollView.drawsBackground = false
            scrollView.borderType = .noBorder
            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        
        // 显式启用 layer 物理裁剪，对贴合边缘 of PDF 纸张内容进行绝对的圆角裁剪
        pdfView.wantsLayer = true
        if let layer = pdfView.layer {
            layer.cornerRadius = 12
            layer.masksToBounds = true
        }
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}

/// A view displaying details and preview of image files
struct ImageFileView: View {
    let filePath: String
    
    @State private var imageSize: CGSize = .zero
    @State private var fileSizeString: String = ""
    
    private var isSVG: Bool {
        URL(fileURLWithPath: filePath).pathExtension.lowercased() == "svg"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            
            if let nsImage = NSImage(contentsOfFile: filePath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("无法加载图片".localized())
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Image details badge
            if isSVG || imageSize != .zero {
                HStack(spacing: 16) {
                    if isSVG {
                        Label("Vector Graphics (SVG)".localized() + (imageSize != .zero ? " \(Int(imageSize.width)) × \(Int(imageSize.height))" : ""), systemImage: "pencil.and.outline")
                    } else {
                        Label("\(Int(imageSize.width)) × \(Int(imageSize.height)) Px", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    }
                    Label(fileSizeString, systemImage: "doc.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cardBackground)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            loadContent(for: filePath)
        }
        .onChange(of: filePath) { newPath in
            loadContent(for: newPath)
        }
    }
    
    private func loadContent(for path: String) {
        // Retrieve physical file size
        if let attr = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attr[.size] as? UInt64 {
            let kb = Double(size) / 1024.0
            if kb > 1024 {
                self.fileSizeString = String(format: "%.2f MB", kb / 1024.0)
            } else {
                self.fileSizeString = String(format: "%.1f KB", kb)
            }
        }
        
        self.imageSize = .zero
        if let nsImage = NSImage(contentsOfFile: path) {
            if isSVG {
                // 对于 SVG 矢量图，使用 nsImage.size 获取其 viewBox 逻辑尺寸
                self.imageSize = nsImage.size
            } else if let rep = nsImage.representations.first {
                self.imageSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            } else {
                self.imageSize = nsImage.size
            }
        }
    }
}
