import SwiftUI
import QuickLookUI

struct OfficePreviewView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .compact) ?? QLPreviewView()
        view.previewItem = fileURL as QLPreviewItem
        
        // 配置 autoresizingMask 允许其跟随父 HostingView 实时流式拉伸大小以铺开铺满
        view.autoresizingMask = [.width, .height]
        
        // 显式启用 layer 物理裁剪，防范底层渲染区域与背景分层导致的直角溢出
        view.wantsLayer = true
        if let layer = view.layer {
            layer.cornerRadius = 12
            layer.masksToBounds = true
        }
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if let currentURL = nsView.previewItem as? URL, currentURL == fileURL {
            return
        }
        nsView.previewItem = fileURL as QLPreviewItem
    }
}
