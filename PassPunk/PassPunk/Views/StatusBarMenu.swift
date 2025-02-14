import Cocoa

@objc protocol StatusBarMenuDelegate: AnyObject {
    @objc func openSettings()
    @objc func performManualCheck()
}

class StatusBarMenu {
    weak var delegate: StatusBarMenuDelegate?
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Status: Connected", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(StatusBarMenuDelegate.openSettings),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)
        
        let checkNowItem = NSMenuItem(
            title: "Check Now",
            action: #selector(StatusBarMenuDelegate.performManualCheck),
            keyEquivalent: "r"
        )
        menu.addItem(checkNowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
        
        return menu
    }
}
