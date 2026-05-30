import Foundation
import Combine
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var localFlagsChangedMonitor: Any?
    private var onKeyDown: (() -> Void)?

    // 双击 Option 检测
    private var lastOptionPressTime: Date?
    private var isOptionPressed: Bool = false

    private init() {}

    /// 注册组合快捷键监听
    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping () -> Void) {
        unregister()

        onKeyDown = handler

        // 1. 全局监听（当其他 App 处于前台时）
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
            }
        }

        // 2. 本地监听（当 QuickPeek 本身处于前台时，比如预览窗口已聚焦）
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
                return nil // 消耗事件，不继续向上传播
            }
            return event
        }

        print("Hotkey registered: modifiers=\(modifiers), keyCode=\(keyCode)")
    }

    private func matchEvent(_ event: NSEvent, modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        let coreFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventModifiers = event.modifierFlags.intersection(coreFlags)
        return eventModifiers == modifiers && event.keyCode == keyCode
    }

    /// 注册双击 Option 触发（保留作为辅助触发方式，或配合未来切换）
    func registerDoubleOptionPress(handler: @escaping () -> Void) {
        unregister()

        onKeyDown = handler

        // 1. 全局监听 (当其他 App 处于前台时)
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, handler: handler)
        }

        // 2. 本地监听 (当本 App 处于前台聚焦时)
        localFlagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, handler: handler)
            return event
        }

        print("Double-Option hotkey registered (Global & Local)")
    }

    private func handleFlagsChanged(_ event: NSEvent, handler: @escaping () -> Void) {
        let optionPressed = event.modifierFlags.contains(.option)

        if optionPressed && !self.isOptionPressed {
            self.isOptionPressed = true
            let currentTime = Date()

            if let lastTime = self.lastOptionPressTime {
                let interval = currentTime.timeIntervalSince(lastTime)
                if interval < Constants.doublePressInterval {
                    DispatchQueue.main.async {
                        handler()
                    }
                    self.lastOptionPressTime = nil
                } else {
                    self.lastOptionPressTime = currentTime
                }
            } else {
                self.lastOptionPressTime = currentTime
            }
        }

        if !optionPressed && self.isOptionPressed {
            self.isOptionPressed = false
        }
    }

    /// 使用当前设置注册热键
    func registerWithSettings(handler: @escaping () -> Void) {
        let settings = Settings.shared
        
        // 智能路由：如果 keyCode == 0 且修饰键中包含 Option，则注册为双击 Option 模式
        if settings.hotkeyKeyCode == 0 && settings.hotkeyModifiers.contains(.option) {
            registerDoubleOptionPress(handler: handler)
        } else {
            // 否则注册为常规的组合快捷键模式（如 Cmd + Shift + Space 等）
            registerHotkey(
                modifiers: settings.hotkeyModifiers,
                keyCode: settings.hotkeyKeyCode,
                handler: handler
            )
        }
    }

    /// 移除热键监听
    func unregister() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = flagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            flagsChangedMonitor = nil
        }
        if let monitor = localFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
            localFlagsChangedMonitor = nil
        }
        onKeyDown = nil
        lastOptionPressTime = nil
        isOptionPressed = false
    }

    /// 检查是否需要 Accessibility 权限
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 请求 Accessibility 权限
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    deinit {
        unregister()
    }
}