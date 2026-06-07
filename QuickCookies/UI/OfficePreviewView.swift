import SwiftUI
import QuickLookUI

struct OfficePreviewView: NSViewRepresentable {
    let fileURL: URL
    let readyToken: UUID
    let onReady: (UUID) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let containerView = PreviewLayoutAwareContainerView()
        containerView.autoresizingMask = [.width, .height]
        
        // 恢复使用自适应机制健全的 .normal 模式以打通 Word 和 Excel 自动宽度缩放
        let previewView = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        previewView.previewItem = fileURL as QLPreviewItem
        previewView.translatesAutoresizingMaskIntoConstraints = false
        
        // 显式启用 layer 物理裁剪，防范底层渲染区域与背景分层导致的直角溢出
        previewView.wantsLayer = true
        if let layer = previewView.layer {
            layer.cornerRadius = 12
            layer.masksToBounds = true
        }
        
        containerView.addSubview(previewView)
        
        // 使用 NSLayoutConstraint 四向强锚点锁定，将 QLPreviewView 钉死在容器边缘，强制平铺铺满
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: containerView.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        context.coordinator.attach(
            to: containerView,
            previewView: previewView,
            token: readyToken,
            notify: onReady
        )
        
        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let containerView = nsView as! PreviewLayoutAwareContainerView
        guard let previewView = containerView.subviews.first as? QLPreviewView else { return }
        if let currentURL = previewView.previewItem as? URL, currentURL == fileURL {
            context.coordinator.attach(
                to: containerView,
                previewView: previewView,
                token: readyToken,
                notify: onReady
            )
            return
        }
        previewView.previewItem = fileURL as QLPreviewItem
        context.coordinator.attach(
            to: containerView,
            previewView: previewView,
            token: readyToken,
            notify: onReady
        )
    }

    final class Coordinator {
        private var deliveredToken: UUID?

        fileprivate func attach(
            to containerView: PreviewLayoutAwareContainerView,
            previewView: QLPreviewView,
            token: UUID,
            notify: @escaping (UUID) -> Void
        ) {
            guard deliveredToken != token else { return }
            deliveredToken = token

            containerView.scheduleStableReady {
                previewView.layoutSubtreeIfNeeded()
                notify(token)
            }
        }
    }
}

fileprivate final class PreviewLayoutAwareContainerView: NSView {
    private var pendingReadyWorkItem: DispatchWorkItem?
    private var readyCallback: (() -> Void)?

    override func layout() {
        super.layout()
        scheduleReadyIfPossible()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleReadyIfPossible()
    }

    func scheduleStableReady(_ callback: @escaping () -> Void) {
        readyCallback = callback
        scheduleReadyIfPossible()
    }

    private func scheduleReadyIfPossible() {
        guard window != nil, !bounds.isEmpty, let readyCallback else {
            return
        }

        pendingReadyWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.window != nil,
                  !self.bounds.isEmpty else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.window != nil,
                      !self.bounds.isEmpty else {
                    return
                }
                readyCallback()
            }
        }

        pendingReadyWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }
}
