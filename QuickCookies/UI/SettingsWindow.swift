import SwiftUI
import AppKit

// MARK: - Settings Window Controller

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var languageObserver: Any?
    private var themeObserver: Any?

    override private init() {
        super.init()
        languageObserver = NotificationCenter.default.addObserver(
            forName: .settingsLanguageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTitle()
        }
        themeObserver = NotificationCenter.default.addObserver(
            forName: .settingsThemeModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAppearance()
        }
    }

    func show() {
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            return
        }

        // 紧凑精致黄金规格：540 × 620pt，对标现代经典 macOS Preferences 风格
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "Settings".localized()
        panel.level = .normal
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        
        // 采用系统原生窗口背景色，与标题栏一体化融合，确保全窗口无缝衔接
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        
        // 标题栏透明，融合背景
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true

        let view = SettingsView()
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        panel.contentView = hostingView

        panel.center()
        
        window = panel
        
        // 激活应用并让窗口获取键盘焦点
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        
        updateAppearance()
    }

    func updateTitle() {
        window?.title = "Settings".localized()
    }

    func updateAppearance() {
        guard let window = window else { return }
        
        switch Settings.shared.themeMode {
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        case .system:
            window.appearance = nil
        }
    }

    func close() {
        window?.close()
        window = nil
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - Settings Tab Definition

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case style = "Style"
    case shortcuts = "Shortcuts"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .style: return "paintbrush.pointed"
        case .shortcuts: return "keyboard"
        case .about: return "info.circle"
        }
    }

    var title: String {
        rawValue.localized()
    }
}

// MARK: - Inset Grouped UI Components (对标参考图 Inset Form Cards)

struct InsetSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.85))
            .padding(.leading, 4)
            .padding(.bottom, 2)
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark ? Color(white: 0.16).opacity(0.75) : Color(white: 0.965).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06),
                    lineWidth: 0.6
                )
        )
    }
}

typealias InsetGroupCard = SettingsCard

struct SettingsRow<RightContent: View>: View {
    let title: String
    var subtitle: String? = nil
    let rightContent: RightContent

    init(title: String, subtitle: String? = nil, @ViewBuilder rightContent: () -> RightContent) {
        self.title = title
        self.subtitle = subtitle
        self.rightContent = rightContent()
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.appText)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            rightContent
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 42)
    }
}

typealias InsetGroupRow = SettingsRow

struct InsetRowDivider: View {
    var body: some View {
        Divider()
            .background(Color.appBorder.opacity(0.35))
            .padding(.leading, 16)
    }
}

// MARK: - 拟物微立体质感键帽组件

struct KbdKeyView: View {
    let key: String
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(Color.appText.opacity(0.88))
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: colorScheme == .dark ? [
                        Color(red: 0.22, green: 0.22, blue: 0.26),
                        Color(red: 0.16, green: 0.16, blue: 0.19)
                    ] : [
                        Color.white,
                        Color(red: 0.94, green: 0.94, blue: 0.96)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.appBorder.opacity(colorScheme == .dark ? 0.35 : 0.8), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 1, x: 0, y: 1.5)
    }
}

// MARK: - Top Icon Tab Bar (对标参考图顶部居中图标 Tab 栏)

struct SettingsTopTabBar: View {
    @Binding var selectedTab: SettingsTab
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(isSelected ? Color.accentColor : Color.secondary.opacity(0.85))
                            .frame(height: 22)
                        
                        Text(tab.title)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? Color.accentColor : Color.secondary.opacity(0.85))
                    }
                    .frame(width: 72, height: 50)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.08))
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.5 : 0.35), lineWidth: 1)
                            }
                        }
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Hero Preview Banner (对标参考图顶部实时特性动态演示看板)

struct HeroPreviewBanner: View {
    let tab: SettingsTab
    @ObservedObject var settings: Settings
    let previewFont: Font
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            switch tab {
            case .style:
                styleBanner
            case .general:
                generalBanner
            case .shortcuts:
                shortcutsBanner
            case .about:
                aboutBanner
            }
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.25), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 6, x: 0, y: 3)
    }
    
    // Style Banner: 动态景深背景 + 实时悬浮代码预览卡片
    private var styleBanner: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.10, blue: 0.30),
                    Color(red: 0.30, green: 0.12, blue: 0.38),
                    Color(red: 0.08, green: 0.14, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 悬浮迷你 QuickCookies 预览卡片
            VStack(spacing: 0) {
                // 卡片微标题栏
                HStack(spacing: 5) {
                    Circle().fill(Color(red: 1.0, green: 0.38, blue: 0.34)).frame(width: 6, height: 6)
                    Circle().fill(Color(red: 1.0, green: 0.74, blue: 0.18)).frame(width: 6, height: 6)
                    Circle().fill(Color(red: 0.15, green: 0.79, blue: 0.25)).frame(width: 6, height: 6)
                    
                    Spacer()
                    
                    Text("QuickCookiesPreview.swift")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.70))
                    
                    Spacer()
                    
                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.08))
                
                Divider().background(Color.white.opacity(0.12))
                
                // 代码高亮区域
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("1").font(previewFont).foregroundColor(.white.opacity(0.35))
                        Text("2").font(previewFont).foregroundColor(.white.opacity(0.35))
                        Text("3").font(previewFont).foregroundColor(.white.opacity(0.35))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("func").foregroundColor(Color(red: 1.0, green: 0.48, blue: 0.45))
                            Text("preview").foregroundColor(Color(red: 0.47, green: 0.75, blue: 1.0))
                            Text("() ->").foregroundColor(Color.white.opacity(0.85))
                            Text("QuickCookies").foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.34))
                            Text("{").foregroundColor(Color.white.opacity(0.85))
                        }
                        .font(previewFont)
                        
                        HStack(spacing: 4) {
                            Text("    return").foregroundColor(Color(red: 1.0, green: 0.48, blue: 0.45))
                            Text(".instant").foregroundColor(Color(red: 0.47, green: 0.75, blue: 1.0))
                            Text("(latencyMs:").foregroundColor(Color.white.opacity(0.85))
                            Text("0").foregroundColor(Color(red: 0.45, green: 0.84, blue: 0.62))
                            Text(")").foregroundColor(Color.white.opacity(0.85))
                        }
                        .font(previewFont)
                        
                        Text("}")
                            .font(previewFont)
                            .foregroundColor(Color.white.opacity(0.85))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .frame(width: 350, height: 96)
            .background(Color(red: 0.06, green: 0.07, blue: 0.10).opacity(0.88))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 4)
        }
    }
    
    // General Banner: 系统就绪状态看板
    private var generalBanner: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.14, blue: 0.26),
                    Color(red: 0.04, green: 0.20, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.20)).frame(width: 38, height: 38)
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("QuickCookies Ready".localized())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("Running in Finder with zero high-risk privileges".localized())
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 11))
                        Text("Finder Extension Active")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(6)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill").foregroundColor(.blue).font(.system(size: 11))
                        Text("Zero Accessibility Architecture")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .cornerRadius(6)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .frame(width: 390, height: 92)
            .background(Color.black.opacity(0.40))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
        }
    }
    
    // Shortcuts Banner: 热键展示看板
    private var shortcutsBanner: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.10, blue: 0.30),
                    Color(red: 0.10, green: 0.08, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 18) {
                // 3D 浮雕按键组
                HStack(spacing: 6) {
                    KbdKeyView(key: "⌘")
                        .scaleEffect(1.2)
                    KbdKeyView(key: "⌘")
                        .scaleEffect(1.2)
                }
                .padding(.horizontal, 8)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Global Preview Hotkey".localized())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Press anywhere in Finder to preview files instantly".localized())
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.75))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(width: 390, height: 86)
            .background(Color.black.opacity(0.42))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
        }
    }
    
    // About Banner: 品牌与版本看板
    private var aboutBanner: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.16, blue: 0.08),
                    Color(red: 0.14, green: 0.08, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            HStack(spacing: 16) {
                Image("AppIcon_transparent")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 52, height: 52)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Quick Cookies")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("v1.4.0")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.16))
                            .cornerRadius(8)
                    }
                    
                    Text("Instant Card Preview for macOS".localized())
                        .font(.system(size: 11.5))
                        .foregroundColor(.white.opacity(0.75))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(width: 390, height: 86)
            .background(Color.black.opacity(0.40))
            .cornerRadius(9)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Settings Main View

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var selectedTab: SettingsTab = .style
    
    // 全局热键录制状态
    @State private var isRecordingHotkey: Bool = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKeyCode: UInt16 = 0
    @State private var hotkeyMonitor: Any? = nil
    @State private var lastRecordModifier: NSEvent.ModifierFlags? = nil
    @State private var lastRecordModifierTime: Date? = nil
    
    // 权限状态
    @State private var isFullDiskAccessAuthorized = {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: path)
    }()
    
    let permissionTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    @State private var cliRefreshToken = UUID()

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // 系统原生窗口背景底板，全屏铺满绝无缝隙
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部一体化标题栏：垂直高度 32pt，文本居中，与左上角系统红绿灯水平同轴平齐
                ZStack {
                    Text(selectedTab.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appText)
                }
                .frame(height: 32)
                
                // 顶部图标 Tab 栏 (对标参考图)
                SettingsTopTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 8)
                
                // 极细微高光分割线
                Rectangle()
                    .fill(Color.appBorder.opacity(colorScheme == .dark ? 0.35 : 0.6))
                    .frame(height: 0.6)
                
                // 内容滚动区
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. 顶部实时特性动态演示看板 (Live Hero Preview Banner)
                        HeroPreviewBanner(
                            tab: selectedTab,
                            settings: settings,
                            previewFont: previewTypographyFont
                        )
                        .padding(.top, 14)
                        
                        // 2. 表单卡片区域
                        switch selectedTab {
                        case .general:
                            generalContentView
                        case .style:
                            styleContentView
                        case .shortcuts:
                            shortcutsContentView
                        case .about:
                            aboutContentView
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .id(settings.language)
        .onAppear {
            setupHotkeyRecording()
            checkPermissions()
        }
        .onReceive(permissionTimer) { _ in
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
        .onDisappear {
            if let monitor = hotkeyMonitor {
                NSEvent.removeMonitor(monitor)
                hotkeyMonitor = nil
            }
        }
    }

    // MARK: - Tab 1: General Settings View (通用)

    private var generalContentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Language Section
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Language".localized())
                InsetGroupCard {
                    InsetGroupRow(
                        title: "Interface Language".localized(),
                        subtitle: "Choose display language".localized()
                    ) {
                        Picker("", selection: $settings.language) {
                            ForEach(Language.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                        .labelsHidden()
                    }
                }
            }

            // 2. Behavior Section
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Behavior".localized())
                InsetGroupCard {
                    VStack(spacing: 0) {
                        InsetGroupRow(
                            title: "Open at Login".localized(),
                            subtitle: "Automatically start QuickCookies in the background when you log in".localized()
                        ) {
                            Toggle("", isOn: $settings.launchAtLogin)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        
                        InsetRowDivider()
                        
                        InsetGroupRow(
                            title: "Full Disk Access".localized(),
                            subtitle: "Grant Full Disk Access to eliminate sandbox popups".localized()
                        ) {
                            if isFullDiskAccessAuthorized {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Authorized".localized())
                                        .foregroundColor(.green)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            } else {
                                Button(action: {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    Text("Grant Access".localized())
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            // 3. Command Line Tool (CLI) Section
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Command Line Tool (CLI)".localized())
                InsetGroupCard {
                    InsetGroupRow(
                        title: "qc <path>",
                        subtitle: "Preview files instantly from Terminal using 'qc <path>'.".localized()
                    ) {
                        let status = CLIInstallerPolicy.checkStatus()
                        if status.isInstalled {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Installed".localized())
                                        .foregroundColor(.green)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                Button("Reinstall CLI".localized()) {
                                    installCLI()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            Button("Install CLI Tool".localized()) {
                                installCLI()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .id(cliRefreshToken)
                }
            }

            // 4. Reset Section
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Reset".localized())
                InsetGroupCard {
                    InsetGroupRow(title: "Restore Default Settings".localized()) {
                        Button("Restore Default Settings".localized()) {
                            resetToDefaults()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                }
            }
        }
    }

    private func installCLI() {
        let result = CLIInstallerPolicy.install()
        switch result {
        case .success:
            cliRefreshToken = UUID()
        case .failure:
            break
        }
    }

    // MARK: - Tab 2: Style & Typography Settings View (排版与外观)

    private var styleContentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. Text Section
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Text".localized())
                InsetGroupCard {
                    VStack(spacing: 0) {
                        InsetGroupRow(
                            title: "Font".localized(),
                            subtitle: "Monospace font for previewing and editing".localized()
                        ) {
                            Picker("", selection: $settings.editorFont) {
                                Text("JetBrains Mono").tag("JetBrains Mono")
                                Text("SF Pro Display").tag("SF Pro Display")
                                Text("System Default (Inter)".localized()).tag("System Default (Inter)")
                            }
                            .frame(width: 190)
                            .labelsHidden()
                        }
                        
                        InsetRowDivider()
                        
                        InsetGroupRow(title: "Font Size".localized()) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    if settings.fontSize > 10 {
                                        settings.saveFontSize(settings.fontSize - 1)
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color.appText.opacity(0.8))
                                        .frame(width: 24, height: 24)
                                        .background(Color.kbdBackground)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.appBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(Int(settings.fontSize))px")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.appText)
                                    .frame(width: 38, alignment: .center)
                                
                                Button(action: {
                                    if settings.fontSize < 24 {
                                        settings.saveFontSize(settings.fontSize + 1)
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color.appText.opacity(0.8))
                                        .frame(width: 24, height: 24)
                                        .background(Color.kbdBackground)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.appBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // 2. Colors Section
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Colors".localized())
                InsetGroupCard {
                    InsetGroupRow(
                        title: "Theme Mode".localized(),
                        subtitle: "Choose your preferred display mode".localized()
                    ) {
                        Picker("", selection: $settings.themeMode) {
                            Text("System".localized()).tag(ThemeMode.system)
                            Text("Light".localized()).tag(ThemeMode.light)
                            Text("Dark".localized()).tag(ThemeMode.dark)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 210)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Tab 3: Shortcuts Settings View (快捷键)

    private var shortcutsContentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. 全局呼出热键
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "GLOBAL HOTKEY".localized())
                InsetGroupCard {
                    VStack(spacing: 0) {
                        InsetGroupRow(
                            title: "Global Preview Hotkey".localized(),
                            subtitle: "Toggle overlay instantly when files are selected in Finder".localized()
                        ) {
                            HStack(spacing: 8) {
                                if isRecordingHotkey {
                                    Text("Press new shortcut keys...".localized())
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.12))
                                        .cornerRadius(6)
                                } else {
                                    Button(action: { isRecordingHotkey = true }) {
                                        HStack(spacing: 4) {
                                            ForEach(0..<hotkeyKeyNames.count, id: \.self) { index in
                                                KbdKeyView(key: hotkeyKeyNames[index])
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .help("Click keys on the right to record custom hotkey".localized())
                                }
                                
                                Button(action: {
                                    settings.saveHotkey(
                                        modifiers: Constants.defaultHotkeyModifiers,
                                        keyCode: Constants.defaultHotkeyKeyCode
                                    )
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Reset Hotkey".localized())
                            }
                        }

                        Divider().padding(.horizontal, 14)

                        InsetGroupRow(
                            title: "Inspect Clipboard".localized(),
                            subtitle: "Inspect clipboard content instantly".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "⌃")
                                KbdKeyView(key: "⌥")
                                KbdKeyView(key: "V")
                            }
                        }

                        Divider().padding(.horizontal, 14)

                        InsetGroupRow(
                            title: "Share as Card".localized(),
                            subtitle: "Directly preview and export as card".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "⌃")
                                KbdKeyView(key: "⌥")
                                KbdKeyView(key: "C")
                            }
                        }
                    }
                }
            }

            // 2. 常用工作流速查表
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "WORKFLOW SHORTCUTS".localized())
                InsetGroupCard {
                    VStack(spacing: 0) {
                        // 1. 在文件中查找
                        InsetGroupRow(
                            title: "Find in File".localized(),
                            subtitle: "Search in text, code and Markdown".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "⌥")
                                KbdKeyView(key: "F")
                            }
                        }
                        
                        InsetRowDivider()
                        
                        // 2. 上一个 / 下一个匹配项
                        InsetGroupRow(
                            title: "Previous / Next Match".localized(),
                            subtitle: "Jump between search results".localized()
                        ) {
                            HStack(spacing: 5) {
                                HStack(spacing: 2) {
                                    KbdKeyView(key: "⇧")
                                    KbdKeyView(key: "↩")
                                }
                                Text("/")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.8))
                                KbdKeyView(key: "↩")
                            }
                        }
                        
                        InsetRowDivider()
                        
                        // 3. 用默认应用打开
                        InsetGroupRow(
                            title: "Open with Default App".localized(),
                            subtitle: "Open current file in external editor".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "⌘")
                                KbdKeyView(key: "O")
                            }
                        }
                        
                        InsetRowDivider()
                        
                        // 4. 在访达中显示
                        InsetGroupRow(
                            title: "Reveal in Finder".localized(),
                            subtitle: "Locate and highlight current file in Finder".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "⌘")
                                KbdKeyView(key: "R")
                            }
                        }
                        
                        InsetRowDivider()
                        
                        // 5. 复制文件路径
                        InsetGroupRow(
                            title: "Copy File Path".localized(),
                            subtitle: "Copy full path to clipboard".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "⌥")
                                KbdKeyView(key: "⌘")
                                KbdKeyView(key: "C")
                            }
                        }
                        
                        InsetRowDivider()
                        
                        // 6. 连续切换访达文件
                        InsetGroupRow(
                            title: "Navigate Files in Finder".localized(),
                            subtitle: "Switch to previous or next file seamlessly".localized()
                        ) {
                            HStack(spacing: 4) {
                                KbdKeyView(key: "↑")
                                KbdKeyView(key: "↓")
                            }
                        }
                        
                        InsetRowDivider()
                        
                        // 7. 关闭预览窗口
                        InsetGroupRow(
                            title: "Close Preview (Esc)".localized(),
                            subtitle: "Close overlay and return focus to Finder".localized()
                        ) {
                            KbdKeyView(key: "Esc")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab 4: About Settings View (关于)

    private var aboutContentView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 1. 特性 Tag 矩阵卡片
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Architecture & Capabilities".localized())
                InsetGroupCard {
                    VStack(spacing: 0) {
                        InsetGroupRow(title: "Zero-Accessibility Architecture".localized()) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 13))
                        }
                        
                        InsetRowDivider()
                        
                        InsetGroupRow(title: "Fast Syntax Highlighting".localized()) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 13))
                        }
                        
                        InsetRowDivider()
                        
                        InsetGroupRow(title: "Seamless Editor Handoff".localized()) {
                            Image(systemName: "arrow.up.forward.app.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 13))
                        }
                    }
                }
            }

            // 2. 操作按钮通道
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "Actions".localized())
                InsetGroupCard {
                    VStack(spacing: 0) {
                        InsetGroupRow(title: "Re-open Onboarding".localized()) {
                            Button(action: {
                                SettingsWindowController.shared.close()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    AppDelegate.shared?.showOnboarding(reopen: true)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text("Re-open Onboarding".localized())
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        InsetRowDivider()
                        
                        InsetGroupRow(title: "View on GitHub".localized()) {
                            Button(action: {
                                if let url = URL(string: "https://github.com/hi-zeroed/quick-cookies") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "safari")
                                    Text("View on GitHub".localized())
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // 3. 开源许可证
            VStack(alignment: .leading, spacing: 6) {
                InsetSectionHeader(title: "License".localized())
                InsetGroupCard {
                    InsetGroupRow(title: "License".localized()) {
                        Text("Released under the GNU GPL v3 License".localized())
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods & Computed Properties

    private var previewTypographyFont: Font {
        switch settings.editorFont {
        case "JetBrains Mono":
            return .custom("JetBrains Mono", size: max(11, settings.fontSize - 1))
        case "SF Pro Display":
            return .system(size: max(11, settings.fontSize - 1), design: .default)
        default:
            return .system(size: max(11, settings.fontSize - 1), design: .monospaced)
        }
    }

    private func checkPermissions() {
        let fda = checkFDA()
        DispatchQueue.main.async {
            self.isFullDiskAccessAuthorized = fda
        }
    }

    private func checkFDA() -> Bool {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: path)
    }

    private var hotkeyKeyNames: [String] {
        let modifiers = settings.hotkeyModifiers
        if settings.hotkeyKeyCode == 0 {
            var sym = "⌘"
            if modifiers.contains(.option) { sym = "⌥" }
            else if modifiers.contains(.shift) { sym = "⇧" }
            else if modifiers.contains(.control) { sym = "⌃" }
            return [sym, sym]
        }
        
        var names: [String] = []
        if modifiers.contains(.command) { names.append("⌘") }
        if modifiers.contains(.option) { names.append("⌥") }
        if modifiers.contains(.control) { names.append("⌃") }
        if modifiers.contains(.shift) { names.append("⇧") }
        
        let keyName = keyCodeToName(settings.hotkeyKeyCode)
        if !keyName.isEmpty && settings.hotkeyKeyCode != 0 {
            names.append(keyName)
        }
        
        return names
    }

    private func keyCodeToName(_ keyCode: UInt16) -> String {
        let keyMap: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            50: "`", 49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc"
        ]
        return keyMap[keyCode] ?? "Key\(keyCode)"
    }

    private func setupHotkeyRecording() {
        if hotkeyMonitor != nil { return }
        
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if isRecordingHotkey {
                if event.type == .flagsChanged {
                    let coreFlags: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
                    let currentModifiers = event.modifierFlags.intersection(coreFlags)
                    
                    if !currentModifiers.isEmpty {
                        let currentTime = Date()
                        if let lastMod = lastRecordModifier, lastMod == currentModifiers,
                           let lastTime = lastRecordModifierTime, currentTime.timeIntervalSince(lastTime) < Constants.doublePressInterval {
                            recordedModifiers = currentModifiers
                            recordedKeyCode = 0
                            
                            settings.saveHotkey(modifiers: recordedModifiers, keyCode: recordedKeyCode)
                            isRecordingHotkey = false

                            lastRecordModifier = nil
                            lastRecordModifierTime = nil
                            return nil
                        } else {
                            lastRecordModifier = currentModifiers
                            lastRecordModifierTime = currentTime
                        }
                    }
                    return nil
                }
                
                let keyCode = event.keyCode
                if keyCode == 54 || keyCode == 55 ||
                   keyCode == 58 || keyCode == 61 ||
                   keyCode == 56 || keyCode == 60 ||
                   keyCode == 59 || keyCode == 62 {
                    return nil
                }

                let coreFlags: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
                recordedModifiers = event.modifierFlags.intersection(coreFlags)
                recordedKeyCode = event.keyCode

                settings.saveHotkey(modifiers: recordedModifiers, keyCode: recordedKeyCode)
                isRecordingHotkey = false

                return nil
            }
            return event
        }
    }

    private func resetToDefaults() {
        settings.saveHotkey(
            modifiers: Constants.defaultHotkeyModifiers,
            keyCode: Constants.defaultHotkeyKeyCode
        )
        settings.saveFontSize(13)
        settings.showLineNumbers = true
        settings.themeMode = .system
        settings.language = Language.system
        settings.editorFont = "JetBrains Mono"
        settings.launchAtLogin = false
    }
}
