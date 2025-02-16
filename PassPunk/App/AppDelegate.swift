import Foundation
import Cocoa
import Security
import SwiftUI
import os.log

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, StatusBarMenuDelegate {
    private var mainAppView: NSWindow?
    private var mainAppViewController: NSWindowController?
    private let statusBarController = StatusBarController.shared
    private let logger = Logger(subsystem: "com.passpunk.PassPunk", category: "AppDelegate")
    
    // Add this notification name
    static let checkStatusChanged = Notification.Name("CheckStatusChanged")
    
    // Add required override init
    override init() {
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        
        Task {
            do {
                try await FirstLaunchManager.shared.checkFirstLaunch()
            } catch {
                logger.error("Error during first launch setup: \(error.localizedDescription)")
            }
        }
    }
    
    private func openMainAppView() {
        if let existingWindow = mainAppView {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let mainView = MainAppView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.contentView = NSHostingView(rootView: mainView)
        window.title = "PassPunk"
        window.delegate = self
        
        // Create a window controller to manage the window lifecycle
        let windowController = NSWindowController(window: window)
        mainAppViewController = windowController
        mainAppView = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func openSettings() {
        openMainAppView()
    }
    
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func performManualCheck() {
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
    
    private func setupStatusBar() {
        // Initialize status bar using the shared controller
        statusBarController.configureStatusBar(delegate: self)
    }
}

// Update window delegate extension
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == mainAppView {
            // Clean up references
            mainAppView = nil
            mainAppViewController = nil
        }
    }
}
