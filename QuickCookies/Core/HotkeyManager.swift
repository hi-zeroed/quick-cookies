import Foundation
import Combine
import AppKit

typealias HotkeyAction = @MainActor @Sendable () -> Void

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    private var flagsChangedMonitor: Any?
    private var localFlagsChangedMonitor: Any?
    private var onKeyDown: HotkeyAction?

    // 剪贴板透视独立快捷键
    private var clipboardEventMonitor: Any?
    private var localClipboardEventMonitor: Any?
    private var onClipboardKeyDown: HotkeyAction?

    // 分享卡片独立快捷键 (⌃⌥C)
    private var shareCardEventMonitor: Any?
    private var localShareCardEventMonitor: Any?
    private var onShareCardKeyDown: HotkeyAction?

    // 双击修饰键检测
    private var lastModifierPressTime: Date?
    private var isModifierPressed: Bool = false

    private init() {}

    /// 注册组合快捷键监听
    func registerHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping HotkeyAction) {
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

        // 2. 本地监听（当 QuickCookies 本身处于前台时）
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
                return nil
            }
            return event
        }
    }

    private func matchEvent(_ event: NSEvent, modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        let coreFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        let eventModifiers = event.modifierFlags.intersection(coreFlags)
        return eventModifiers == modifiers && event.keyCode == keyCode
    }

    /// 注册双击修饰键（如 Command/Option）触发
    func registerDoubleModifierPress(modifier: NSEvent.ModifierFlags, handler: @escaping HotkeyAction) {
        unregister()

        onKeyDown = handler

        // 1. 全局监听 (当其他 App 处于前台时)
        flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, modifier: modifier, handler: handler)
        }

        // 2. 本地监听 (当本 App 处于前台聚焦时)
        localFlagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event, modifier: modifier, handler: handler)
            return event
        }
    }

    private func handleFlagsChanged(_ event: NSEvent, modifier: NSEvent.ModifierFlags, handler: @escaping HotkeyAction) {
        let coreFlags: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        let eventModifiers = event.modifierFlags.intersection(coreFlags)
        
        let modifierPressed = eventModifiers == modifier

        if modifierPressed && !self.isModifierPressed {
            self.isModifierPressed = true
            let currentTime = Date()

            if let lastTime = self.lastModifierPressTime {
                let interval = currentTime.timeIntervalSince(lastTime)
                if interval < Constants.doublePressInterval {
                    DispatchQueue.main.async {
                        handler()
                    }
                    self.lastModifierPressTime = nil
                } else {
                    self.lastModifierPressTime = currentTime
                }
            } else {
                self.lastModifierPressTime = currentTime
            }
        }

        if !modifierPressed && self.isModifierPressed {
            self.isModifierPressed = false
        }
    }

    /// 使用当前设置注册热键
    func registerWithSettings(handler: @escaping HotkeyAction) {
        let settings = Settings.shared
        
        // 智能路由：如果 keyCode == 0 且修饰键中包含 Command 或 Option，则注册为对应的双击模式
        if settings.hotkeyKeyCode == 0 {
            if settings.hotkeyModifiers.contains(.command) {
                registerDoubleModifierPress(modifier: .command, handler: handler)
            } else if settings.hotkeyModifiers.contains(.option) {
                registerDoubleModifierPress(modifier: .option, handler: handler)
            } else {
                // 兜底默认双击 command
                registerDoubleModifierPress(modifier: .command, handler: handler)
            }
        } else {
            // 否则注册为常规的组合快捷键模式（如 Cmd + Shift + Space 等）
            registerHotkey(
                modifiers: settings.hotkeyModifiers,
                keyCode: settings.hotkeyKeyCode,
                handler: handler
            )
        }
    }

    /// 注册剪贴板透视独立快捷键监听
    func registerClipboardHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping HotkeyAction) {
        unregisterClipboardHotkey()

        onClipboardKeyDown = handler

        // 1. 全局监听（当其他 App 处于前台时）
        clipboardEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
            }
        }

        // 2. 本地监听（当 QuickCookies 本身处于前台时）
        localClipboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
                return nil
            }
            return event
        }
    }

    /// 使用当前设置注册剪贴板快捷键
    func registerClipboardWithSettings(handler: @escaping HotkeyAction) {
        let settings = Settings.shared
        registerClipboardHotkey(
            modifiers: settings.clipboardHotkeyModifiers,
            keyCode: settings.clipboardHotkeyKeyCode,
            handler: handler
        )
    }

    /// 移除剪贴板快捷键监听
    func unregisterClipboardHotkey() {
        if let monitor = clipboardEventMonitor {
            NSEvent.removeMonitor(monitor)
            clipboardEventMonitor = nil
        }
        if let monitor = localClipboardEventMonitor {
            NSEvent.removeMonitor(monitor)
            localClipboardEventMonitor = nil
        }
        onClipboardKeyDown = nil
    }

    /// 注册直接分享卡片独立快捷键监听 (⌃⌥C)
    func registerShareCardHotkey(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, handler: @escaping HotkeyAction) {
        unregisterShareCardHotkey()

        onShareCardKeyDown = handler

        // 1. 全局监听（当其他 App 处于前台时）
        shareCardEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
            }
        }

        // 2. 本地监听（当 QuickCookies 本身处于前台时）
        localShareCardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if self.matchEvent(event, modifiers: modifiers, keyCode: keyCode) {
                DispatchQueue.main.async {
                    handler()
                }
                return nil
            }
            return event
        }
    }

    /// 使用当前设置注册直接分享卡片快捷键
    func registerShareCardWithSettings(handler: @escaping HotkeyAction) {
        let settings = Settings.shared
        registerShareCardHotkey(
            modifiers: settings.shareCardHotkeyModifiers,
            keyCode: settings.shareCardHotkeyKeyCode,
            handler: handler
        )
    }

    /// 移除直接分享卡片快捷键监听
    func unregisterShareCardHotkey() {
        if let monitor = shareCardEventMonitor {
            NSEvent.removeMonitor(monitor)
            shareCardEventMonitor = nil
        }
        if let monitor = localShareCardEventMonitor {
            NSEvent.removeMonitor(monitor)
            localShareCardEventMonitor = nil
        }
        onShareCardKeyDown = nil
    }

    /// 移除常规热键监听
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
        lastModifierPressTime = nil
        isModifierPressed = false
    }

    deinit {
        unregister()
        unregisterClipboardHotkey()
        unregisterShareCardHotkey()
    }
}
