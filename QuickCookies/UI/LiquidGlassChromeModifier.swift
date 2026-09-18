import SwiftUI
import AppKit

// MARK: - 主卡片 Liquid Glass 修饰符

/// 主预览浮层卡片 Liquid Glass 材质修饰符
public struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let isInteractive: Bool
    let tint: Color?

    public init(
        cornerRadius: CGFloat = 20,
        isInteractive: Bool = false,
        tint: Color? = nil
    ) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            var glass = Glass.regular
            if let tint = tint {
                glass = glass.tint(tint)
            }
            if #available(macOS 27.0, *), isInteractive {
                glass = glass.interactive(true)
            }
            return AnyView(
                content
                    .glassEffect(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        } else {
            return AnyView(
                content
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        }
    }
}

// MARK: - 悬浮胶囊 / 工具条 Liquid Glass 修饰符

/// 悬浮条与微 HUD 专属高透 Clear Liquid Glass 修饰符
public struct LiquidGlassPillModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isInteractive: Bool

    public init(cornerRadius: CGFloat = 8, isInteractive: Bool = true) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            var glass = Glass.clear
            if #available(macOS 27.0, *), isInteractive {
                glass = glass.interactive(true)
            }
            return AnyView(
                content
                    .glassEffect(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        } else {
            return AnyView(
                content
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
        }
    }
}

/// 药丸胶囊 (Capsule) 专用 Liquid Glass 修饰符（用于 CustomAlert 与 Toast）
public struct LiquidGlassCapsuleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let isInteractive: Bool

    public init(isInteractive: Bool = true) {
        self.isInteractive = isInteractive
    }

    public func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            var glass = Glass.clear
            if #available(macOS 27.0, *), isInteractive {
                glass = glass.interactive(true)
            }
            return AnyView(
                content
                    .glassEffect(glass, in: Capsule())
            )
        } else {
            return AnyView(
                content
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.95) : Color.white.opacity(0.95))
                    )
            )
        }
    }
}

// MARK: - 邻近流体融合工具栏容器 (Liquid Coalescing)

/// 工具栏按钮流体融合容器：在 macOS 26+ 下自动启用 GlassEffectContainer 实现水滴邻近光影互吸
public struct LiquidGlassToolbarContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    public init(spacing: CGFloat = 4, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - View 扩展方法

extension View {
    /// 应用主卡片 Liquid Glass 材质
    public func liquidGlassCard(
        cornerRadius: CGFloat = 20,
        isInteractive: Bool = false,
        tint: Color? = nil
    ) -> some View {
        self.modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                isInteractive: isInteractive,
                tint: tint
            )
        )
    }

    /// 应用悬浮条与微 HUD 圆角 Liquid Glass 材质
    public func liquidGlassPill(cornerRadius: CGFloat = 8, isInteractive: Bool = true) -> some View {
        self.modifier(LiquidGlassPillModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }

    /// 应用药丸胶囊 (Capsule) Liquid Glass 材质
    public func liquidGlassCapsule(isInteractive: Bool = true) -> some View {
        self.modifier(LiquidGlassCapsuleModifier(isInteractive: isInteractive))
    }
}
