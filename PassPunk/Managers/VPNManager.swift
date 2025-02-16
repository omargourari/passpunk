import Foundation
import Cocoa
import Security
import os.log
import LocalAuthentication
import ApplicationServices
import SwiftUI
import CoreGraphics

@available(macOS 15.0, *)
@MainActor
final class VPNManager: @unchecked Sendable, ObservableObject {
    static let shared = VPNManager()
    private let logger = Logger(subsystem: "com.passpunk.PassPunk", category: "VPNManager")
    private let defaults = UserDefaults.standard
    
    private let vpnUsernameKey = "vpn_username"
    private let vpnPasswordKey = "vpn_password"
    
    @Published private(set) var connectionState: VPNStatus = .disconnected
    @Published private(set) var isAuthenticating: Bool = false
    
    private init() {
        logger.info("VPNManager initialized")
    }

    enum VPNError: Error {
        case credentialsNotFound
        case applicationNotFound
        case authenticationFailed
        case scriptError(String)
        case windowNotFound
        case accessibilityError
    }
    
    func authenticate() async throws {
        self.connectionState = .connecting
        
        logger.info("Starting VPN authentication process")
        
        guard try getCredentials() != nil else {
            self.connectionState = .disconnected
            logger.error("Failed to retrieve VPN credentials")
            throw VPNError.credentialsNotFound
        }
        
        do {
            logger.info("Attempting to start VPN application")
            try await startVPN()
            self.connectionState = .connected
            logger.info("VPN application started successfully")
        } catch {
            self.connectionState = .disconnected
            logger.error("VPN authentication failed: \(error.localizedDescription)")
            throw error
        }
    }

    func getCredentials() throws -> (username: String, password: String)? {
        logger.debug("Attempting to retrieve VPN credentials from UserDefaults")
        
        guard let username = defaults.string(forKey: vpnUsernameKey),
              let password = defaults.string(forKey: vpnPasswordKey),
              !username.isEmpty,
              !password.isEmpty else {
            logger.error("Credentials not found or empty in UserDefaults")
            return nil
        }
        
        logger.debug("VPN credentials retrieved successfully")
        return (username: username, password: password)
    }

    func saveCredentials(username: String, password: String) throws {
        logger.info("Saving VPN credentials for user: \(username)")
        defaults.set(username, forKey: vpnUsernameKey)
        defaults.set(password, forKey: vpnPasswordKey)
        defaults.synchronize()
        
        // Verify immediately after saving
        guard let savedCredentials = try getCredentials(),
              savedCredentials.username == username,
              savedCredentials.password == password else {
            logger.error("Credential verification failed immediately after saving")
            throw VPNError.credentialsNotFound
        }
        
        logger.info("VPN credentials saved and verified successfully")
    }

    @MainActor
    func startVPN() async throws {
        logger.info("Starting VPN connection process")
        
        // Check if VPN is already running
        if let vpnApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5networks.EdgeClient" }) {
            logger.info("VPN application already running")
            return
        }
        
        // Launch VPN application
        guard let vpnURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.f5networks.EdgeClient") else {
            throw VPNError.applicationNotFound
        }
        
        try await launchVPNApplication(at: vpnURL)
        try await waitForVPNWindow()
        try await performLogin()
    }
    
    private func sleep(_ duration: TimeInterval) async throws {
        // Backwards compatible sleep implementation
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }

    private func launchVPNApplication(at url: URL) async throws {
        if let vpnApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5networks.EdgeClient" }) {
            _ = vpnApp // Silence unused warning
        }
        
        try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
        try await Task.sleep(for: .seconds(10))
    }
    
    private func waitForVPNWindow() async throws {
        while true {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5networks.EdgeClient" }) {
                if app.isActive {
                    return
                }
            }
            try await Task.sleep(for: .seconds(5))
        }
    }
    
    func performLogin() async throws {
        logger.info("Starting VPN login process")
        
        guard let credentials = try getCredentials() else {
            logger.error("Failed to retrieve VPN credentials")
            throw VPNError.credentialsNotFound
        }
        logger.info("VPN credentials retrieved successfully")
        
        do {
            // Enter credentials using CGEvent instead of AppleScript
            logger.info("Attempting to enter VPN credentials")
            try await enterCredentials(username: credentials.username, password: credentials.password)
            logger.info("Credentials entered successfully")
            
            // Wait for 2FA prompt
            logger.info("Waiting for 2FA prompt...")
            try await Task.sleep(for: .seconds(5))
            logger.info("2FA wait completed")
            
            // Show 2FA modal and handle input
            logger.info("Showing 2FA modal")
            let twoFactorCode = try await showTwoFactorModal()
            logger.info("2FA code received: \(twoFactorCode.prefix(2))***") // Only log first 2 digits for security
            
            logger.info("Attempting to enter 2FA code")
            try await enterTwoFactorCode(twoFactorCode)
            logger.info("2FA code entered successfully")
            
            // Wait for connection
            logger.info("Waiting for VPN connection to establish")
            try await waitForConnection()
            logger.info("VPN connection established successfully")
        } catch {
            logger.error("VPN login failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func showTwoFactorModal() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let workItem = DispatchWorkItem {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
                    styleMask: [.titled],
                    backing: .buffered,
                    defer: false
                )
                
                let twoFactorView = TwoFactorView(
                    onComplete: { code in
                        window.close()
                        continuation.resume(returning: code)
                    }
                )
                
                window.contentView = NSHostingView(rootView: twoFactorView)
                window.center()
                window.level = .floating
                window.isMovableByWindowBackground = false
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                
                // Position window on active space and screen
                if let screen = NSScreen.main {
                    window.setFrameOrigin(NSPoint(
                        x: screen.frame.midX - window.frame.width/2,
                        y: screen.frame.midY - window.frame.height/2
                    ))
                }
                
                window.makeKeyAndOrderFront(nil)
            }
            
            DispatchQueue.main.async(execute: workItem)
        }
    }

    private func enterCredentials(username: String, password: String) async throws {
        logger.info("Starting credentials entry process")
        
        // Wait for application to be active (reduced wait time)
        logger.debug("Waiting for application to be active...")
        try await sleep(1)
        
        // Helper function for keyboard events
        func postKey(_ key: CGKeyCode, flags: CGEventFlags = []) {
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
            keyDown?.flags = flags
            keyUp?.flags = flags
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            usleep(10000) // Small delay between keystrokes
        }
        
        // Function to type text
        func typeText(_ text: String) {
            for char in text {
                var keyCode: CGKeyCode = 0
                var flags: CGEventFlags = []
                
                switch char {
                case "A"..."Z":
                    keyCode = CGKeyCode(char.asciiValue! - 65 + 0x00)
                    flags = .maskShift
                case "a"..."z":
                    keyCode = CGKeyCode(char.asciiValue! - 97 + 0x00)
                case "0"..."9":
                    keyCode = CGKeyCode(char.asciiValue! - 48 + 0x12)
                case "@":
                    keyCode = 0x00  // 'A' key
                    flags = .maskShift
                case ".":
                    keyCode = 0x2F
                default:
                    continue
                }
                
                postKey(keyCode, flags: flags)
            }
        }
        
        // Select and enter username
        postKey(0x00, flags: .maskCommand)  // Command-A
        typeText(username)
        
        // Move to password field
        postKey(0x30)  // Tab
        
        // Select and enter password
        postKey(0x00, flags: .maskCommand)  // Command-A
        typeText(password)
        
        // Make sure we're still in the password field
        try await Task.sleep(for: .seconds(0.5))
        
        // Press Enter twice with a small delay
        postKey(0x24)  // Return key
        try await Task.sleep(for: .seconds(0.2))
        postKey(0x24)  // Return key again
        
        // Wait for processing
        try await Task.sleep(for: .seconds(2))
    }

    private func enterTwoFactorCode(_ code: String) async throws {
        logger.info("Entering 2FA code")
        
        // Wait for the window to be ready
        try await sleep(1)
        
        // Create a stable event source
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw VPNError.scriptError("Failed to create event source")
        }
        
        // Function to post keyboard events safely
        func postKey(_ key: CGKeyCode, flags: CGEventFlags = []) {
            guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: key, keyDown: false) else {
                return
            }
            
            keyDown.flags = flags
            keyUp.flags = flags
            
            keyDown.post(tap: .cghidEventTap)
            usleep(50000) // 50ms delay
            keyUp.post(tap: .cghidEventTap)
            usleep(50000) // 50ms delay
        }
        
        // Type each digit of the 2FA code
        for char in code {
            if let ascii = char.asciiValue {
                let keyCode = CGKeyCode(ascii - 48 + 0x12) // Convert number to keycode
                postKey(keyCode)
                try await Task.sleep(for: .milliseconds(100))
            }
        }
        
        // Press Return key to submit
        try await Task.sleep(for: .seconds(0.5))
        postKey(0x24) // Return key
        
        // Wait for processing
        try await Task.sleep(for: .seconds(2))
    }

    private func waitForConnection() async throws {
        // Implementation of waitForConnection
        throw VPNError.scriptError("Connection wait not implemented")
    }

    func checkVPNStatus() async throws -> Bool {
        // Implement VPN status check
        let checkScript = """
        tell application "System Events"
            tell process "F5 Networks VPN"
                if exists (button "Disconnect" of window 1) then
                    return true
                end if
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: checkScript) {
            let result = scriptObject.executeAndReturnError(&error).booleanValue
            return result
        }
        return false
    }

    private func findLoginButton() async throws -> CGRect {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5networks.EdgeClient" }) else {
            throw VPNError.applicationNotFound
        }
        _ = app // Silence unused warning
        try await sleep(2)
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var windowList: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(systemWideElement, "AXWindows" as CFString, &windowList)
        
        guard error == .success,
              let windows = windowList as? [AXUIElement] else {
            throw VPNError.windowNotFound
        }
        
        for window in windows {
            var title: CFTypeRef?
            let titleError = AXUIElementCopyAttributeValue(window, "AXTitle" as CFString, &title)
            
            if titleError == .success,
               let windowTitle = title as? String,
               windowTitle.contains("F5") {
                var buttonRef: CFTypeRef?
                let buttonError = AXUIElementCopyAttributeValue(window, "AXButtons" as CFString, &buttonRef)
                
                if buttonError == .success,
                   let buttons = buttonRef as? [AXUIElement] {
                    for button in buttons {
                        var buttonTitle: CFTypeRef?
                        let buttonTitleError = AXUIElementCopyAttributeValue(button, "AXTitle" as CFString, &buttonTitle)
                        
                        if buttonTitleError == .success,
                           let title = buttonTitle as? String,
                           title.lowercased() == "login" {
                            var position: CFTypeRef?
                            var size: CFTypeRef?
                            
                            AXUIElementCopyAttributeValue(button, "AXPosition" as CFString, &position)
                            AXUIElementCopyAttributeValue(button, "AXSize" as CFString, &size)
                            
                            if let positionValue = position as? NSValue,
                               let sizeValue = size as? NSValue {
                                let point = positionValue.pointValue
                                let size = sizeValue.sizeValue
                                return CGRect(x: point.x, y: point.y, width: size.width, height: size.height)
                            }
                        }
                    }
                }
            }
        }
        
        throw VPNError.windowNotFound
    }

    private func clickLoginButton() async throws {
        logger.info("Attempting to click login button")
        
        // Attendi che l'interfaccia sia pronta dopo l'inserimento delle credenziali
        try await Task.sleep(for: .seconds(1))
        
        // Cerca il pulsante Logon usando l'accessibilità
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5.vpn.client" }) else {
            logger.error("F5 VPN application not found")
            throw VPNError.applicationNotFound
        }
        
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        guard appRef != nil else {
            throw VPNError.accessibilityError
        }
        
        // Fix accessibility constants
        let kAXButtonsAttribute = "AXButtons"
        
        var buttonsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appRef, kAXButtonsAttribute as CFString, &buttonsRef)
        
        guard let buttonsArray = buttonsRef as? [AXUIElement] else {
            logger.error("No buttons found")
            throw VPNError.windowNotFound
        }
        
        for button in buttonsArray {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(button, kAXTitleAttribute as CFString, &title)
            
            if let buttonTitle = title as? String,
               buttonTitle.lowercased() == "logon" {
                logger.info("Found Logon button, attempting to press")
                var press = AXUIElementPerformAction(button, kAXPressAction as CFString)
                if press == .success {
                    logger.info("Successfully pressed Logon button")
                    return
                }
                
                // Fallback: prova a cliccare usando le coordinate
                var position: CFTypeRef?
                var size: CFTypeRef?
                AXUIElementCopyAttributeValue(button, kAXPositionAttribute as CFString, &position)
                AXUIElementCopyAttributeValue(button, kAXSizeAttribute as CFString, &size)
                
                if let positionValue = position as? NSValue,
                   let sizeValue = size as? NSValue {
                    let point = positionValue.pointValue
                    let size = sizeValue.sizeValue
                    let clickPoint = CGPoint(
                        x: point.x + size.width/2,
                        y: point.y + size.height/2
                    )
                    
                    logger.info("Attempting mouse click at: \(String(describing: clickPoint))")
                    
                    let source = CGEventSource(stateID: .hidSystemState)
                    let click = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: clickPoint, mouseButton: .left)
                    let release = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: clickPoint, mouseButton: .left)
                    
                    click?.post(tap: .cghidEventTap)
                    try await Task.sleep(for: .milliseconds(100))
                    release?.post(tap: .cghidEventTap)
                    
                    return
                }
            }
        }
        
        logger.error("Login button not found")
        throw VPNError.windowNotFound
    }
}
