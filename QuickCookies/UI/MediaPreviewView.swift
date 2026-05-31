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
            } else if renderType == .image {
                ImageFileView(filePath: filePath)
            } else {
                Text("不支持的文件格式".localized())
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
                    .onAppear {
                        // Retrieve pixel dimensions of the image representation
                        if let rep = nsImage.representations.first {
                            self.imageSize = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
                        } else {
                            self.imageSize = nsImage.size
                        }
                        
                        // Retrieve physical file size
                        if let attr = try? FileManager.default.attributesOfItem(atPath: filePath),
                           let size = attr[.size] as? UInt64 {
                            let kb = Double(size) / 1024.0
                            if kb > 1024 {
                                self.fileSizeString = String(format: "%.2f MB", kb / 1024.0)
                            } else {
                                self.fileSizeString = String(format: "%.1f KB", kb)
                            }
                        }
                    }
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
            if imageSize != .zero {
                HStack(spacing: 16) {
                    Label("\(Int(imageSize.width)) × \(Int(imageSize.height)) Px", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
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
    }
}
