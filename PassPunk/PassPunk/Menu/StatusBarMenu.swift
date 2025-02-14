import Cocoa

protocol StatusBarMenuDelegate: AnyObject {
    func performManualCheck()
    func openSettings()
}

class StatusBarMenu {
    weak var delegate: StatusBarMenuDelegate?
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Add menu items
        let checkNowItem = NSMenuItem(title: "Check Now", action: #selector(StatusBarMenu.checkNowClicked(_:)), keyEquivalent: "")
        checkNowItem.target = self
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(StatusBarMenu.settingsClicked(_:)), keyEquivalent: ",")
        settingsItem.target = self
        
        menu.addItem(checkNowItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        
        return menu
    }
    
    @objc private func checkNowClicked(_ sender: Any) {
        delegate?.performManualCheck()
    }
    
    @objc private func settingsClicked(_ sender: Any) {
        delegate?.openSettings()
    }
} 