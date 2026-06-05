import SwiftUI

/// 自定义弹窗按钮样式与交互动作结构体
struct CustomAlertButton {
    let title: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary      // 主动蓝色高亮样式
        case secondary    // 次要灰色半透明样式
        case destructive  // 红色警告样式
    }
    
    static func primary(_ title: String, action: @escaping () -> Void = {}) -> CustomAlertButton {
        CustomAlertButton(title: title, style: .primary, action: action)
    }
    
    static func secondary(_ title: String, action: @escaping () -> Void = {}) -> CustomAlertButton {
        CustomAlertButton(title: title, style: .secondary, action: action)
    }
    
    static func destructive(_ title: String, action: @escaping () -> Void = {}) -> CustomAlertButton {
        CustomAlertButton(title: title, style: .destructive, action: action)
    }
}

/// 自定义卡片内嵌式弹窗视图修饰符
struct CustomAlertModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Binding var isPresented: Bool
    
    let title: String
    let message: String
    let primaryButton: CustomAlertButton
    let secondaryButton: CustomAlertButton?
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isPresented) // 弹窗时禁用主内容区域的交互
            
            if isPresented {
                // 1. 半透明黑色遮罩层
                Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .zIndex(100)
                    .onTapGesture {
                        // 如果仅有单按钮（提示确定类），允许点击背景空白处快速关闭
                        if secondaryButton == nil {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isPresented = false
                            }
                        }
                    }
                
                // 2. 弹窗卡片主体（尺寸限制，防止溢出圆角）
                VStack(spacing: 16) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(colorScheme == .dark ? Color(white: 0.7) : Color(white: 0.4))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                    
                    // 按钮组
                    HStack(spacing: 12) {
                        if let secondary = secondaryButton {
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isPresented = false
                                }
                                secondary.action()
                            }) {
                                Text(secondary.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                isPresented = false
                            }
                            primaryButton.action()
                        }) {
                            Text(primaryButton.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(primaryButton.style == .destructive ? Color.red : (primaryButton.style == .secondary ? (colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)) : Color.blue))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(width: 290)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colorScheme == .dark ? Color(white: 0.16) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                .zIndex(101)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
        }
    }
}

extension View {
    /// 挂载自定义极简卡片内弹窗修饰符
    /// - Parameters:
    ///   - isPresented: 绑定是否弹出
    ///   - title: 对话框标题
    ///   - message: 对话框正文说明描述
    ///   - primaryButton: 主要按钮配置
    ///   - secondaryButton: 可选的次要按钮配置
    func customAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        primaryButton: CustomAlertButton,
        secondaryButton: CustomAlertButton? = nil
    ) -> some View {
        self.modifier(
            CustomAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                primaryButton: primaryButton,
                secondaryButton: secondaryButton
            )
        )
    }
}
