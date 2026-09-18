import SwiftUI
import Combine
import AppKit
import Observation

@MainActor
@Observable
final class TelemetryInspectorState {
    var isPresented: Bool = false
    var report: TelemetryReport? = nil
    var isLoading: Bool = false
    var showCopiedFeedback: Bool = false
    
    private var currentTask: Task<Void, Never>?
    private var lastLoadedPath: String?
    
    init() {}
    
    func toggle(path: String, renderType: FileRenderType, content: String? = nil) {
        if isPresented {
            dismiss()
        } else {
            present(path: path, renderType: renderType, content: content)
        }
    }
    
    func present(path: String, renderType: FileRenderType, content: String? = nil) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            isPresented = true
        }
        loadIfNeeded(path: path, renderType: renderType, content: content)
    }
    
    func dismiss() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
            isPresented = false
        }
    }
    
    func loadIfNeeded(path: String, renderType: FileRenderType, content: String? = nil) {
        guard lastLoadedPath != path || report == nil else { return }
        lastLoadedPath = path
        
        currentTask?.cancel()
        isLoading = true
        
        currentTask = Task {
            let result = await TelemetryExtractor.extract(from: path, renderType: renderType, existingContent: content)
            guard !Task.isCancelled else { return }
            self.report = result
            self.isLoading = false
        }
    }
    
    /// 当浮层处于激活状态且切换了预览文件时，自动更新元数据
    func reloadIfPresented(path: String, renderType: FileRenderType, content: String? = nil) {
        if isPresented {
            lastLoadedPath = nil
            loadIfNeeded(path: path, renderType: renderType, content: content)
        }
    }
    
    /// 拷贝全部元数据摘要到系统剪贴板
    func copySummary() {
        guard let summary = report?.summaryText, !summary.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        
        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopiedFeedback = false
        }
    }
}
