import Cocoa
import FinderSync

class QuickCookiesFinderSync: FIFinderSync {

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = FinderSyncMonitoringPolicy.monitoredDirectoryURLs()
    }
    
    // MARK: - Menu and Action
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Only show contextual menu for file/directory selections
        guard menuKind == .contextualMenuForItems else { return nil }
        
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let isChinese = preferredLanguage.hasPrefix("zh")
        let title = isChinese ? "用 Quick Cookies 预览" : "Preview with Quick Cookies"
        
        let menu = NSMenu(title: "")
        let menuItem = NSMenuItem(title: title, action: #selector(triggerPreview(_:)), keyEquivalent: "")
        
        // Attempt to load MenuBarIcon if it is compiled in assets
        if let iconImage = NSImage(named: "MenuBarIcon") {
            menuItem.image = iconImage
        }
        
        menu.addItem(menuItem)
        return menu
    }
    
    @objc func triggerPreview(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(),
              let firstURL = items.first else {
            return
        }
        
        // Construct query parameters and trigger custom url scheme
        var components = URLComponents()
        components.scheme = "quickcookies"
        components.host = "preview"
        components.queryItems = [URLQueryItem(name: "path", value: firstURL.path)]
        
        guard let url = components.url else { return }
        
        // Invoke asynchronously on main thread
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }
}
