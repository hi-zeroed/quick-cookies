import SwiftUI
import AppKit

/// 顶栏右侧的外部应用接力打开控件（一体化分段高质感胶囊）
struct AppRelayControlView: View {
    let filePath: String
    let onOpenRelay: () -> Void

    @State private var defaultApp: RelayApp? = nil
    @State private var candidates: [RelayApp] = []
    @State private var isActionHovered: Bool = false
    @State private var isMenuHovered: Bool = false
    @State private var dropdownAnchorView: NSView? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            if let app = defaultApp {
                // 1. 左半区：主接力动作按钮（点击直接打开，Hover 全覆盖左侧圆角）
                Button(action: {
                    openWith(app: app)
                }) {
                    HStack(spacing: 5) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 14, height: 14)

                        Text(app.shortName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.appText.opacity(isActionHovered ? 0.95 : 0.85))
                            .lineLimit(1)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 6)
                    .frame(height: 22)
                    .background(
                        Rectangle()
                            .fill(Color.appText.opacity(isActionHovered ? 0.08 : 0))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open with \(app.name)".localized())
                .onHover { isActionHovered = $0 }

                // 2. 右半区：微型下拉角标按钮（Hover 全覆盖右侧圆角，精准在下方弹出菜单）
                Button(action: {
                    showMenu()
                }) {
                    HStack(spacing: 0) {
                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6.5, height: 4)
                            .foregroundColor(Color.appText.opacity(isMenuHovered ? 0.9 : 0.55))
                    }
                    .frame(width: 18, height: 22)
                    .background(
                        Rectangle()
                            .fill(Color.appText.opacity(isMenuHovered ? 0.08 : 0))
                    )
                    .background(DropdownAnchorView(anchorView: $dropdownAnchorView))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("More Applications".localized())
                .onHover { isMenuHovered = $0 }
            } else {
                // 兜底按钮
                Button(action: {
                    showMenu()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.appText.opacity(0.85))

                        Text("Open".localized())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.appText.opacity(0.85))

                        Image(systemName: "chevron.down")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6.5, height: 4)
                            .foregroundColor(Color.appText.opacity(0.55))
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(
                        Rectangle()
                            .fill(Color.appText.opacity(isMenuHovered ? 0.08 : 0))
                    )
                    .background(DropdownAnchorView(anchorView: $dropdownAnchorView))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open with Application".localized())
                .onHover { isMenuHovered = $0 }
            }
        }
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appText.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.appText.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            refreshApps()
        }
        .onChange(of: filePath) { _ in
            refreshApps()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let fileURL = URL(fileURLWithPath: filePath)

        if let defaultApp = defaultApp {
            let item = NSMenuItem(
                title: "\(defaultApp.name) (\("Default".localized()))",
                action: #selector(AppRelayMenuTarget.onDefaultClick),
                keyEquivalent: ""
            )
            let iconCopy = defaultApp.icon.copy() as? NSImage ?? defaultApp.icon
            iconCopy.size = NSSize(width: 16, height: 16)
            item.image = iconCopy
            item.target = AppRelayMenuTarget.shared
            AppRelayMenuTarget.shared.onDefault = { [self] in openWith(app: defaultApp) }
            menu.addItem(item)
        }

        if !candidates.isEmpty {
            menu.addItem(NSMenuItem.separator())
            for app in candidates {
                let item = NSMenuItem(
                    title: app.name,
                    action: #selector(AppRelayMenuTarget.onCandidateClick(_:)),
                    keyEquivalent: ""
                )
                let iconCopy = app.icon.copy() as? NSImage ?? app.icon
                iconCopy.size = NSSize(width: 16, height: 16)
                item.image = iconCopy
                item.representedObject = app
                item.target = AppRelayMenuTarget.shared
                AppRelayMenuTarget.shared.onCandidate = { [self] candidate in openWith(app: candidate) }
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let revealItem = NSMenuItem(
            title: "Reveal in Finder".localized(),
            action: #selector(AppRelayMenuTarget.onRevealClick),
            keyEquivalent: ""
        )
        revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        revealItem.target = AppRelayMenuTarget.shared
        AppRelayMenuTarget.shared.onReveal = { [self] in
            ExternalAppRelay.shared.revealInFinder(fileURL: fileURL)
            onOpenRelay()
        }
        menu.addItem(revealItem)

        let copyItem = NSMenuItem(
            title: "Copy Path".localized(),
            action: #selector(AppRelayMenuTarget.onCopyClick),
            keyEquivalent: ""
        )
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.target = AppRelayMenuTarget.shared
        AppRelayMenuTarget.shared.onCopy = {
            ExternalAppRelay.shared.copyPathToClipboard(fileURL: fileURL)
        }
        menu.addItem(copyItem)

        if let anchor = dropdownAnchorView {
            AppRelayMenuTarget.shared.setActiveMenu(menu)
            // 在视图正下方 4pt 弹出，绝对不遮挡胶囊按钮与下拉 icon
            let yOffset: CGFloat = anchor.isFlipped ? (anchor.bounds.height + 4) : -4
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: yOffset), in: anchor)
            AppRelayMenuTarget.shared.setActiveMenu(nil)
        } else if let event = NSApp.currentEvent, let windowView = NSApp.keyWindow?.contentView {
            AppRelayMenuTarget.shared.setActiveMenu(menu)
            var location = event.locationInWindow
            location.y -= 22
            menu.popUp(positioning: nil, at: location, in: windowView)
            AppRelayMenuTarget.shared.setActiveMenu(nil)
        }
    }

    private func refreshApps() {
        let fileURL = URL(fileURLWithPath: filePath)
        let (def, cand) = ExternalAppRelay.shared.getApps(for: fileURL)
        self.defaultApp = def
        self.candidates = cand
    }

    private func openWith(app: RelayApp) {
        let fileURL = URL(fileURLWithPath: filePath)
        ExternalAppRelay.shared.open(fileURL: fileURL, with: app)
        onOpenRelay()
    }
}

/// 获取宿主 NSView 用于精准在正下方弹出菜单的锚点组件
struct DropdownAnchorView: NSViewRepresentable {
    @Binding var anchorView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.anchorView = view
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if self.anchorView != nsView {
            DispatchQueue.main.async {
                self.anchorView = nsView
            }
        }
    }
}

/// 接收 NSMenu 动作回调的全局目标分发器
final class AppRelayMenuTarget: NSObject {
    static let shared = AppRelayMenuTarget()

    private(set) weak var activeMenu: NSMenu?

    func setActiveMenu(_ menu: NSMenu?) {
        self.activeMenu = menu
    }

    func cancelActiveMenu() {
        activeMenu?.cancelTracking()
        activeMenu = nil
    }

    var onDefault: (() -> Void)?
    var onCandidate: ((RelayApp) -> Void)?
    var onReveal: (() -> Void)?
    var onCopy: (() -> Void)?

    @objc func onDefaultClick() {
        onDefault?()
    }

    @objc func onCandidateClick(_ sender: NSMenuItem) {
        if let app = sender.representedObject as? RelayApp {
            onCandidate?(app)
        }
    }

    @objc func onRevealClick() {
        onReveal?()
    }

    @objc func onCopyClick() {
        onCopy?()
    }
}
