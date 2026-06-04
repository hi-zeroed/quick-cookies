import SwiftUI
import AppKit

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    override private init() {
        super.init()
    }

    func show() {
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "设置".localized()
        panel.level = .normal
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        
        // 标题栏透明，融合背景
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .visible

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
        window?.title = "设置".localized()
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
        
        if let layer = window.contentView?.layer {
            layer.backgroundColor = NSColor.appBackground.cgColor
        }
    }

    func close() {
        window?.close()
        window = nil
    }

    // 监听窗口关闭，确保释放强引用并清理，防范野指针
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - Helper UI Components (对齐 HTML 极简设计)

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.8))
            .kerning(1.5)
            .padding(.leading, 4)
            .padding(.bottom, 2)
    }
}

struct SettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.appBorder, lineWidth: 1)
        )
    }
}

struct SettingsRow<RightContent: View>: View {
    let title: String
    let subtitle: String?
    let rightContent: RightContent
    
    init(title: String, subtitle: String? = nil, @ViewBuilder rightContent: () -> RightContent) {
        self.title = title
        self.subtitle = subtitle
        self.rightContent = rightContent()
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
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
        .padding(.vertical, 12)
    }
}

struct KbdKeyView: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(Color.appText.opacity(0.8))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.kbdBackground)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}

// MARK: - Settings Main View

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var isRecordingHotkey: Bool = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKeyCode: UInt16 = 0
    @State private var hotkeyMonitor: Any? = nil
    
    @State private var isAccessibilityAuthorized = false
    @State private var isFullDiskAccessAuthorized = false
    
    let permissionTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // 1. Appearance Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "APPEARANCE".localized())
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsRow(title: "外观主题".localized(), subtitle: "选择您偏好的界面显示模式".localized()) {
                                Picker("", selection: $settings.themeMode) {
                                    ForEach(ThemeMode.allCases) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                                .labelsHidden()
                            }
                            
                            Divider()
                                .background(Color.appBorder)
                                .padding(.horizontal, 16)
                            
                            SettingsRow(title: "语言".localized(), subtitle: "选择界面的显示语言".localized()) {
                                Picker("", selection: $settings.language) {
                                    ForEach(Language.allCases) { lang in
                                        Text(lang.displayName).tag(lang)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                                .labelsHidden()
                            }
                        }
                    }
                }
                
                // 2. Typography Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "TYPOGRAPHY".localized())
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsRow(title: "编辑器字体".localized(), subtitle: "预览和编辑 Markdown 与代码时采用的等宽字体".localized()) {
                                Picker("", selection: $settings.editorFont) {
                                    Text("System Default (Inter)".localized()).tag("System Default (Inter)")
                                    Text("SF Pro Display").tag("SF Pro Display")
                                    Text("JetBrains Mono").tag("JetBrains Mono")
                                }
                                .frame(width: 180)
                                .labelsHidden()
                            }
                            
                            Divider()
                                .background(Color.appBorder)
                                .padding(.horizontal, 16)
                            
                            SettingsRow(title: "字体大小".localized()) {
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
                
                // 3. Keybindings Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "KEYBINDINGS".localized())
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsRow(title: "全局快捷预览".localized(), subtitle: "点击右侧键帽录制自定义组合快捷键".localized()) {
                                if isRecordingHotkey {
                                    Text("请在键盘上按下新快捷键...".localized())
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.12))
                                        .cornerRadius(4)
                                } else {
                                    Button(action: { isRecordingHotkey = true }) {
                                        HStack(spacing: 4) {
                                            ForEach(hotkeyKeyNames, id: \.self) { key in
                                                KbdKeyView(key: key)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Divider()
                                .background(Color.appBorder)
                                .padding(.horizontal, 16)
                            
                            SettingsRow(title: "进入编辑模式".localized()) {
                                HStack(spacing: 4) {
                                    KbdKeyView(key: "⌘")
                                    KbdKeyView(key: "E")
                                }
                            }
                            
                            Divider()
                                .background(Color.appBorder)
                                .padding(.horizontal, 16)
                            
                            SettingsRow(title: "保存文件修改".localized()) {
                                HStack(spacing: 4) {
                                    KbdKeyView(key: "⌘")
                                    KbdKeyView(key: "S")
                                }
                            }
                        }
                    }
                }
                
                // 4. System Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "SYSTEM".localized())
                    SettingsCard {
                        VStack(spacing: 0) {
                            SettingsRow(title: "开机自启动".localized(), subtitle: "在您登录 macOS 系统时自动静默启动 Quick Cookies".localized()) {
                                Toggle("", isOn: $settings.launchAtLogin)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                            }
                            
                            Divider()
                                .background(Color.appBorder)
                                .padding(.horizontal, 16)
                            
                            // 辅助功能权限
                            SettingsRow(title: "辅助功能权限".localized(), subtitle: "用于全局快捷键与高级动画定位".localized()) {
                                if isAccessibilityAuthorized {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("已授权".localized())
                                            .foregroundColor(.green)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                } else {
                                    Button(action: {
                                        HotkeyManager.shared.requestAccessibilityPermission()
                                    }) {
                                        Text("去授权".localized())
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            Divider()
                                .background(Color.appBorder)
                                .padding(.horizontal, 16)
                            
                            // 所有文件夹访问权限 (FDA)
                            SettingsRow(title: "所有文件夹访问".localized(), subtitle: "授权完全磁盘访问，消除系统安全弹窗".localized()) {
                                if isFullDiskAccessAuthorized {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("已授权".localized())
                                            .foregroundColor(.green)
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                } else {
                                    Button(action: {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Text("去授权".localized())
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
                
                // 5. Restore Button
                HStack {
                    Spacer()
                    Button("恢复默认设置".localized()) {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    Spacer()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48) // 留出顶部标题栏区域的空间
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
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
    
    private func checkPermissions() {
        isAccessibilityAuthorized = AXIsProcessTrusted()
        isFullDiskAccessAuthorized = checkFDA()
    }
    
    private func checkFDA() -> Bool {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        return FileManager.default.isReadableFile(atPath: path)
    }

    private var hotkeyKeyNames: [String] {
        let modifiers = settings.hotkeyModifiers
        if settings.hotkeyKeyCode == 0 && modifiers == [.option] {
            return ["⌥", "⌥"]
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
        
        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecordingHotkey {
                // 忽略单独的修饰键
                let keyCode = event.keyCode
                if keyCode == 54 || keyCode == 55 || // Cmd (右、左)
                   keyCode == 58 || keyCode == 61 || // Option (左、右)
                   keyCode == 56 || keyCode == 60 || // Shift (左、右)
                   keyCode == 59 || keyCode == 62 {  // Control (左、右)
                    return nil
                }

                // 提取核心修饰键，过滤掉设备无关掩码，保证匹配一致性
                let coreFlags: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
                recordedModifiers = event.modifierFlags.intersection(coreFlags)
                recordedKeyCode = event.keyCode

                // 保存
                settings.saveHotkey(modifiers: recordedModifiers, keyCode: recordedKeyCode)
                isRecordingHotkey = false

                // 重新注册热键
                HotkeyManager.shared.registerWithSettings {
                    QuickLookOverlay.shared.showFromFinder()
                }

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
        settings.fontSize = 14
        settings.showLineNumbers = true
        settings.themeMode = .system
        
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        if preferredLanguage.hasPrefix("zh") {
            settings.language = .zhHans
        } else {
            settings.language = .en
        }
        
        settings.editorFont = "System Default (Inter)"
        settings.launchAtLogin = false

        // 重新注册热键
        HotkeyManager.shared.registerWithSettings {
            QuickLookOverlay.shared.showFromFinder()
        }
    }
}