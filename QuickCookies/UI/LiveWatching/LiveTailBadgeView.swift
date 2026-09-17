import SwiftUI

/// 顶栏 22pt 水晶磨砂 ● LIVE 呼吸徽标与交互胶囊
struct LiveTailBadgeView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var liveState: LiveWatchingState
    @State private var isPulsing: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        if liveState.isLiveTailMode {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    liveState.toggleFollowing()
                }
            }) {
                HStack(spacing: 5) {
                    // 状态指示圆点 / 图标
                    if liveState.hasUnreadAppendsWhilePaused {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                    } else {
                        ZStack {
                            if liveState.isFollowingTail {
                                Circle()
                                    .fill(Color.green.opacity(0.35))
                                    .frame(width: 10, height: 10)
                                    .scaleEffect(isPulsing ? 1.4 : 0.9)
                                    .opacity(isPulsing ? 0.0 : 0.8)
                            }

                            Circle()
                                .fill(liveState.isFollowingTail ? Color.green : Color.secondary.opacity(0.6))
                                .frame(width: 6, height: 6)
                        }
                    }

                    // 文本标签
                    Text(badgeLabel)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(badgeTextColor)
                }
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(badgeBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(badgeBorderColor, lineWidth: 0.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help(liveState.isFollowingTail ? "Live Tail: Auto-scrolling (Click to pause)".localized() : "Live Tail: Paused (Click to follow)".localized())
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }

    private var badgeLabel: String {
        if liveState.hasUnreadAppendsWhilePaused {
            return "NEW"
        }
        return liveState.isFollowingTail ? "LIVE" : "PAUSED"
    }

    private var badgeTextColor: Color {
        if liveState.hasUnreadAppendsWhilePaused {
            return .orange
        }
        return liveState.isFollowingTail ? Color.green : Color.secondary
    }

    private var badgeBackgroundColor: Color {
        if isHovered {
            return Color.white.opacity(colorScheme == .dark ? 0.12 : 0.20)
        }
        if liveState.hasUnreadAppendsWhilePaused {
            return Color.orange.opacity(0.12)
        }
        return liveState.isFollowingTail ? Color.green.opacity(0.10) : Color.appText.opacity(0.06)
    }

    private var badgeBorderColor: Color {
        if liveState.hasUnreadAppendsWhilePaused {
            return Color.orange.opacity(0.35)
        }
        return liveState.isFollowingTail ? Color.green.opacity(0.25) : Color.appBorder.opacity(0.15)
    }
}
