import Foundation
import Cocoa
import Security
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var statusBarMenu: StatusBarMenu!
    private var periodicTimer: Timer?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        
        // Wrap the call to startPeriodicChecks in a Task
        Task {
            await startPeriodicChecks()
        }

        // Nascondi l'icona dal Dock
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "PassPunk")
        }
        
        statusBarMenu = StatusBarMenu()
        statusBarMenu.delegate = self
        statusBarItem.menu = statusBarMenu.createMenu()
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.center()
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.title = "Settings"
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc @Sendable func performManualCheck() {
        Task {
            do {
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
    
    func startPeriodicChecks() async {
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.performManualCheck()
            }
        }
    }
    
    func performPeriodicChecks() async {
        do {
            try await VPNManager.shared.authenticate()
            try await PasswordManager.shared.checkAndUpdatePassword()
        } catch {
            print("Error updating password: \(error)")
        }
    }
}

extension AppDelegate: StatusBarMenuDelegate {
    // I metodi sono già implementati
}
