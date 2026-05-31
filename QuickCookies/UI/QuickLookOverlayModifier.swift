import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 预览大窗卡片自适应系统背景色
private var adaptiveBackgroundColor: Color {
    #if os(macOS)
    return Color(NSColor.windowBackgroundColor)
    #else
    return Color(UIColor.systemBackground)
    #endif
}

/// 物理等价的弹簧出现动画 (快速且带极微弱回弹)
private var snappyAppearAnimation: Animation {
    if #available(macOS 14.0, iOS 17.0, *) {
        return .snappy(duration: 0.25, extraBounce: 0.1)
    } else {
        return .spring(response: 0.25, dampingFraction: 0.8)
    }
}

/// 物理等价的弹簧消失动画 (更干脆且无回弹)
private var snappyDismissAnimation: Animation {
    if #available(macOS 14.0, iOS 17.0, *) {
        return .snappy(duration: 0.2)
    } else {
        return .spring(response: 0.2, dampingFraction: 1.0)
    }
}

/// 纯 SwiftUI 跨平台 Quick Look 弹出动画修饰符
struct QuickLookOverlayModifier<OverlayContent: View, ID: Hashable>: ViewModifier {
    @Binding var isPresented: Bool
    let sourceId: ID
    let namespace: Namespace.ID
    let overlayContent: () -> OverlayContent

    // 内部控制渲染和动画状态的双向绑定安全锁
    @State private var isAnimatingIn: Bool = false
    @State private var isShowingView: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isShowingView {
                        ZStack {
                            // 1. 半透明背景遮罩 (Scrim)，点击任意空白区域关闭
                            Color.black.opacity(isAnimatingIn ? 0.35 : 0.0)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    dismiss()
                                }
                            
                            // 2. 物理连续性预览卡片
                            ZStack(alignment: .topLeading) {
                                if isAnimatingIn {
                                    overlayContent()
                                        // 核心：使用 drawingGroup 避免缩放动画期间的文字和子视图拉伸/模糊/闪烁
                                        .drawingGroup()
                                        .matchedGeometryEffect(id: sourceId, in: namespace, isSource: false)
                                        .frame(maxWidth: 800, maxHeight: 600)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(adaptiveBackgroundColor)
                                                .shadow(color: .black.opacity(0.25), radius: 15, x: 0, y: 8)
                                        )
                                    
                                    // 3. 原生风格悬浮关闭按钮
                                    Button(action: {
                                        dismiss()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.primary.opacity(0.4))
                                            .padding(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.identity) // matchedGeometryEffect 会接管位移与缩放，过渡效果设为 identity 防止冲突
                            
                            // 4. 隐藏式按钮，用于跨版本、跨平台捕获键盘 Esc 键，完美保证吸回原点缩小动画
                            Button("") {
                                dismiss()
                            }
                            .keyboardShortcut(.cancelAction)
                            .opacity(0)
                            .frame(width: 0, height: 0)
                        }
                    }
                }
            )
            // 监听外部状态的变更以触发打开/关闭动画
            .onChange(of: isPresented) { newValue in
                if newValue {
                    // 弹出
                    isShowingView = true
                    withAnimation(snappyAppearAnimation) {
                        isAnimatingIn = true
                    }
                } else if isAnimatingIn {
                    // 关闭
                    withAnimation(snappyDismissAnimation) {
                        isAnimatingIn = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isShowingView = false
                    }
                }
            }
            .onAppear {
                if isPresented {
                    isShowingView = true
                    withAnimation(snappyAppearAnimation) {
                        isAnimatingIn = true
                    }
                }
            }
    }

    /// 执行平滑关闭动画，先收缩吸回原点，再解挂视图
    private func dismiss() {
        withAnimation(snappyDismissAnimation) {
            isAnimatingIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowingView = false
            isPresented = false
        }
    }
}

// MARK: - View 接口扩展

public extension View {
    /// 类似于 macOS 官方 Quick Look 的物理连续性视图弹出和关闭修饰符
    /// - Parameters:
    ///   - isPresented: 绑定是否弹出
    ///   - sourceId: 源网格单元格/图标的 ID，必须与源视图的 matchedGeometryEffect 匹配
    ///   - namespace: 外部绑定的共享命名空间
    ///   - content: 预览窗口的内容视图
    func quickLookOverlay<Content: View, ID: Hashable>(
        isPresented: Binding<Bool>,
        sourceId: ID,
        namespace: Namespace.ID,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(QuickLookOverlayModifier(
            isPresented: isPresented,
            sourceId: sourceId,
            namespace: namespace,
            overlayContent: content
        ))
    }
}
