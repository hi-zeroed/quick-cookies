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
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    HStack(spacing: 12) {
                        // 1. 状态指示圆点（信息/错误）
                        Circle()
                            .fill(primaryButton.style == .destructive ? Color.red : Color.blue)
                            .frame(width: 7, height: 7)
                        
                        // 2. 消息内容（合并 title 与 message 以保持单行极简）
                        let displayMessage = title.isEmpty ? message : "\(title)：\(message)"
                        Text(displayMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.8))
                            .lineLimit(1)
                        
                        Spacer(minLength: 24)
                        
                        // 3. 按钮组
                        HStack(spacing: 8) {
                            // 主按钮
                            Button(action: {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                    isPresented = false
                                }
                                primaryButton.action()
                            }) {
                                Text(primaryButton.title.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(primaryButton.style == .destructive ? Color.red : Color.blue)
                            }
                            .buttonStyle(.plain)
                            
                            if let secondary = secondaryButton {
                                // 优雅细分割线
                                Text("|")
                                    .font(.system(size: 11))
                                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12))
                                
                                // 次要按钮
                                Button(action: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        isPresented = false
                                    }
                                    secondary.action()
                                }) {
                                    Text(secondary.title.uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.95) : Color.white.opacity(0.95))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 8, x: 0, y: 4)
                    )
                    .overlay(
                        Capsule()
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                    .padding(.bottom, 16)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
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
