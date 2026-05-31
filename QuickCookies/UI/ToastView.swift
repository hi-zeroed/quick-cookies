import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String?

    init(message: String, icon: String? = nil) {
        self.message = message
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                // 如果是特定错误，使用更直观的字符，否则默认使用信息图标
                Text(icon == "xmark.circle" ? "✗" : "ℹ️")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
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
    let icon: String?

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isShowing {
                        ToastView(message: message, icon: icon)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: isShowing)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.toastDuration) {
                                    withAnimation {
                                        isShowing = false
                                    }
                                }
                            }
                    }
                },
                alignment: .center
            )
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String? = nil) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon))
    }
}