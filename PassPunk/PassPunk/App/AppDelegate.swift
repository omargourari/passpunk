import Foundation
import Cocoa
import Security
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, StatusBarMenuDelegate {
    var statusBarItem: NSStatusItem!
    var statusBarMenu: StatusBarMenu!
    private var periodicTimer: Timer?
    private var settingsWindowController: NSWindowController?
    private var settingsWindow: NSWindow?
    
    // Add this notification name
    static let checkStatusChanged = Notification.Name("CheckStatusChanged")
    
    // Add required override init
    override init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()

        // Nascondi l'icona dal Dock
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PassPunk")
        }
        
        statusBarMenu = StatusBarMenu()
        statusBarMenu.delegate = self
        
        // Setup click handling
        if let button = statusBarItem.button {
            statusBarMenu.setupStatusBarButton(button)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func openSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let mainWindow = MainWindow()
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow?.center()
        settingsWindow?.contentView = NSHostingView(rootView: mainWindow)
        settingsWindow?.title = "PassPunk Manager"
        settingsWindow?.delegate = self
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc @Sendable func performManualCheck() {
        Task {
            do {
                // Specify the type explicitly to resolve ambiguity
                try await VPNManager.shared.authenticate()
                try await PasswordManager.shared.checkAndUpdatePassword()
            } catch {
                print("Error during manual check: \(error)")
                
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Error"
                    alert.informativeText = "An error occurred during the check: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
    
    func performPeriodicChecks() async {
        do {
            // Update these calls as well
            try await VPNManager.shared.authenticate()
            try await PasswordManager.shared.checkAndUpdatePassword()
        } catch {
            print("Error updating password: \(error)")
        }
    }
}

// Update window delegate extension
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindowController?.window {
            settingsWindowController = nil
        }
    }
}
