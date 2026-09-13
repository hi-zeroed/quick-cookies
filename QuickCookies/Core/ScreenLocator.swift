import AppKit

public protocol ScreenLocating {
    func targetScreen(mouseLocation: NSPoint, screens: [NSScreen]) -> NSScreen?
}

public struct ActiveScreenLocator: ScreenLocating {
    public static let shared = ActiveScreenLocator()

    public init() {}

    public func targetScreen(mouseLocation: NSPoint, screens: [NSScreen]) -> NSScreen? {
        screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    public static func targetScreen(
        mouseLocation: NSPoint = NSEvent.mouseLocation,
        screens: [NSScreen] = NSScreen.screens,
        mainScreen: NSScreen? = NSScreen.main
    ) -> NSScreen {
        screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? mainScreen
            ?? screens.first
            ?? NSScreen()
    }
}
