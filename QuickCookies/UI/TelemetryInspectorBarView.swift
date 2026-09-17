import SwiftUI

struct TelemetryInspectorBarView: View {
    @ObservedObject var state: TelemetryInspectorState
    
    init(state: TelemetryInspectorState) {
        self.state = state
    }
    
    var body: some View {
        if state.isPresented {
            HStack(spacing: 8) {
                // 左侧微图标
                Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(.leading, 4)
                
                if state.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                    Text("Analyzing...".localized())
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                } else if let report = state.report, !report.isEmpty {
                    // 中间水平滚动元数据流
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(report.items.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 4) {
                                    Text(item.label)
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(item.value)
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.primary)
                                }
                                .help(item.tooltip ?? "\(item.label): \(item.value)")
                                
                                if index < report.items.count - 1 {
                                    Text("·")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.secondary.opacity(0.4))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    Text("No telemetry available".localized())
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 4)
                
                // 拷贝按钮
                Button(action: {
                    state.copySummary()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: state.showCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(state.showCopiedFeedback ? .green : .secondary)
                        if state.showCopiedFeedback {
                            Text("Copied".localized())
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Copy Telemetry (⌘C)".localized())
                
                // 关闭按钮
                Button(action: {
                    state.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.secondary.opacity(0.7))
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close (Esc)".localized())
                .padding(.trailing, 2)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
    }
}
