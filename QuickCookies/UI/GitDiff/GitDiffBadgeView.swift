import SwiftUI

/// Git 差异状态微胶囊徽章（20pt 水晶磨砂风格）
struct GitDiffBadgeView: View {
    @ObservedObject var gitDiffState: GitDiffState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        let report = gitDiffState.report

        switch report.status {
        case .modified:
            Button(action: {
                gitDiffState.jumpToNextHunk()
            }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange.opacity(0.95))
                        .frame(width: 5, height: 5)

                    if report.additions > 0 {
                        Text("+\(report.additions)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.green.opacity(0.95))
                    }

                    if report.deletions > 0 {
                        Text("-\(report.deletions)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.red.opacity(0.95))
                    }

                    if report.hunks.count > 1 {
                        Text("\(gitDiffState.currentHunkIndex + 1)/\(report.hunks.count)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.appText.opacity(0.55))
                    }
                }
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(colorScheme == .dark ? (isHovered ? 0.16 : 0.09) : (isHovered ? 0.24 : 0.15)))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.20), lineWidth: 0.5)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .help("Git Uncommitted Changes (Click to jump to next hunk)".localized())

        case .untracked:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green.opacity(0.95))
                    .frame(width: 5, height: 5)

                Text("UNTRACKED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.green.opacity(0.95))
            }
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(
                Capsule()
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.09 : 0.15))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.20), lineWidth: 0.5)
            )
            .help("Git Untracked File".localized())

        case .clean, .notInRepo:
            EmptyView()
        }
    }
}
