import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String? // 保留 icon 属性

    init(message: String, icon: String? = nil) {
        self.message = message
        self.icon = icon
    }

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.12).opacity(0.85)) // 统一深色高档半透明磨砂背景，适配深浅色模式
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
            )
            .frame(maxWidth: 300, maxHeight: 46)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String? // 保持对历史调用签名的完全向下兼容

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isShowing {
                        ToastView(message: message, icon: icon)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 60) // 距顶端偏移，确保视觉居上且防标题工具栏遮挡
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.toastDuration) {
                                    withAnimation {
                                        isShowing = false
                                    }
                                }
                            }
                    }
                },
                alignment: .top // 改变位置居上
            )
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String? = nil) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon))
    }
}