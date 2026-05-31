import SwiftUI
import AppKit

class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.title = "QuickPeek 设置"
        panel.level = .normal

        let view = SettingsView()
        let hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView

        panel.center()
        panel.makeKeyAndOrderFront(nil)

        window = panel
    }

    func close() {
        window?.close()
        window = nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @State private var isRecordingHotkey: Bool = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKeyCode: UInt16 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 快捷键设置
            GroupBox(label: Text("快捷键")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("触发快捷键:")
                        Spacer()

                        if isRecordingHotkey {
                            Text("按下新快捷键...")
                                .foregroundColor(.secondary)
                        } else {
                            Button(hotkeyDisplay) {
                                isRecordingHotkey = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let conflict = checkHotkeyConflict() {
                        Text(conflict)
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                .padding()
            }

            // 外观设置
            GroupBox(label: Text("外观")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("字体大小:")
                        Spacer()
                        Slider(value: $settings.fontSize, in: 10...24, step: 1)
                            .frame(width: 100)
                        Text("\(Int(settings.fontSize))")
                    }

                    HStack {
                        Text("外观主题:")
                        Spacer()
                        Picker("", selection: $settings.themeMode) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }

                    Toggle("显示行号", isOn: $settings.showLineNumbers)
                }
                .padding()
            }

            Spacer()

            // 底部按钮
            HStack {
                Spacer()
                Button("重置默认") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            setupHotkeyRecording()
        }
    }

    private var hotkeyDisplay: String {
        let modifiers = settings.hotkeyModifiers
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.shift) { parts.append("⇧") }

        // KeyCode 转名称
        let keyName = keyCodeToName(settings.hotkeyKeyCode)
        parts.append(keyName)

        return parts.joined()
    }

    private func keyCodeToName(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 51: return "Delete"
        case 50: return "`"
        default:
            // 字母键
            if keyCode >= 0 && keyCode <= 25 {
                let letter = Character(UnicodeScalar(Int(UnicodeScalar("A").value) + Int(keyCode))!)
                return String(letter)
            }
            return "Key\(keyCode)"
        }
    }

    private func setupHotkeyRecording() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecordingHotkey {
                // 忽略单独的修饰键
                if event.keyCode == 54 || event.keyCode == 55 || // Cmd
                   event.keyCode == 58 || event.keyCode == 59 || // Option
                   event.keyCode == 56 || event.keyCode == 57 || // Shift
                   event.keyCode == 59 || event.keyCode == 62 {   // Control
                    return nil
                }

                recordedModifiers = event.modifierFlags
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

    private func checkHotkeyConflict() -> String? {
        // 简单检查常见冲突
        let modifiers = settings.hotkeyModifiers
        let keyCode = settings.hotkeyKeyCode

        if modifiers.contains(.command) && keyCode == 49 { // Cmd+Space
            return "可能与 Spotlight 冲突"
        }

        if modifiers.contains(.control) && keyCode == 49 { // Ctrl+Space
            return "可能与输入法切换冲突"
        }

        return nil
    }

    private func resetToDefaults() {
        settings.saveHotkey(
            modifiers: Constants.defaultHotkeyModifiers,
            keyCode: Constants.defaultHotkeyKeyCode
        )
        settings.fontSize = 14
        settings.showLineNumbers = true
        settings.themeMode = .system

        // 重新注册热键
        HotkeyManager.shared.registerWithSettings {
            QuickLookOverlay.shared.showFromFinder()
        }
    }
}