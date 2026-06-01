import SwiftUI
import QuickLookUI

struct OfficePreviewView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.previewItem = fileURL as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if let currentURL = nsView.previewItem as? URL, currentURL == fileURL {
            return
        }
        nsView.previewItem = fileURL as QLPreviewItem
    }
}
