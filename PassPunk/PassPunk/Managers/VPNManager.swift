import Foundation
import Cocoa
import Security
import os.log
import LocalAuthentication
import ApplicationServices

class VPNManager {
    static let shared = VPNManager()
    private let logger = Logger(subsystem: "com.passpunk.PassPunk", category: "VPNManager")
    private let defaults = UserDefaults.standard
    
    private let vpnUsernameKey = "vpn_username"
    private let vpnPasswordKey = "vpn_password"
    
    private init() {
        logger.info("VPNManager initialized")
    }

    enum VPNError: Error {
        case credentialsNotFound
        case applicationNotFound
        case authenticationFailed
        case scriptError(String)
    }

    func authenticate() async throws {
        logger.info("Starting VPN authentication process")

        guard let credentials = try getCredentials() else {
            logger.error("Failed to retrieve VPN credentials")
            throw VPNError.credentialsNotFound
        }
        logger.info("VPN credentials retrieved successfully")

        do {
            logger.info("Attempting to start VPN application")
            try await startVPN()
            logger.info("VPN application started successfully")

            logger.info("Initiating login process")
            try await performLogin(with: credentials)
            logger.info("VPN login completed successfully")
        } catch {
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
            return nil
        }
        
        return (username: username, password: password)
    }

    func saveCredentials(username: String, password: String) throws {
        logger.info("Saving VPN credentials for user: \(username)")
        defaults.set(username, forKey: vpnUsernameKey)
        defaults.set(password, forKey: vpnPasswordKey)
        logger.info("VPN credentials saved successfully")
    }

    @MainActor
    func startVPN() async throws {
        logger.info("Looking for F5 VPN application")
        
        // Controlla se l'app è già in esecuzione
        if let vpnApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5networks.EdgeClient" }) {
            logger.info("F5 VPN application is already running")
            vpnApp.activate(options: [])
            return
        }
        
        guard let vpnURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.deloitte.EdgeClient") else {
            logger.error("F5 VPN application not found")
            throw VPNError.applicationNotFound
        }

        // Nascondi la finestra delle impostazioni
        if let window = NSApplication.shared.windows.first(where: { $0.title == "PassPunk Settings" }) {
            window.orderOut(nil)
        }

        logger.debug("Launching F5 VPN application at path: \(vpnURL.path)")
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", vpnURL.path]

        do {
            try process.run()
            logger.debug("VPN process launched, waiting for completion")
            
            // Replace Thread.sleep with Task.sleep
            try await Task.sleep(for: .seconds(2))
            
            // Porta l'applicazione VPN in primo piano
            if let vpnApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.deloitte.EdgeClient" }) {
                vpnApp.activate(options: [])
            }
            
            logger.info("VPN application launched successfully")
        } catch {
            logger.error("Failed to launch VPN application: \(error.localizedDescription)")
            throw VPNError.scriptError("Errore nell'avvio dell'applicazione VPN")
        }
    }

    private func performLogin(with credentials: (username: String, password: String)) async throws {
        logger.info("Starting VPN login automation")
        
        // Check automation permissions and wait for user to grant them if needed
        var retryCount = 0
        let maxRetries = 3
        
        while retryCount < maxRetries {
            let trusted = AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
            ] as CFDictionary)
            
            if trusted {
                break
            }
            
            logger.warning("Waiting for automation permissions (attempt \(retryCount + 1)/\(maxRetries))")
            try await Task.sleep(for: .seconds(5))
            retryCount += 1
        }
        
        // Verify permissions one final time
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary)
        
        if !trusted {
            logger.error("Automation permissions not granted after \(maxRetries) attempts")
            throw VPNError.authenticationFailed
        }
        
        // Wait for VPN application window to be available (increased timeout)
        var windowRetryCount = 0
        let maxWindowRetries = 20  // 100 seconds total wait time
        var vpnWindowFound = false
        var loginFieldsFound = false
        
        while windowRetryCount < maxWindowRetries {
            if let vpnApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.f5.epi" }) {
                vpnApp.activate()
                
                // Check if the login fields exist using AppleScript
                let checkScript = """
                tell application "System Events"
                    tell process "BIG-IP Edge Client"
                        if exists window 1 then
                            if exists text field 1 of window 1 then
                                -- Clear existing text
                                set value of text field 1 of window 1 to ""
                                set value of text field 2 of window 1 to ""
                                log "Login fields found and cleared"
                                return true
                            end if
                        end if
                    end tell
                end tell
                """
                
                if let checkObject = NSAppleScript(source: checkScript) {
                    var checkError: NSDictionary?
                    logger.debug("Executing login fields check script")
                    let result = checkObject.executeAndReturnError(&checkError).booleanValue
                    if result {
                        logger.info("Login fields found and cleared successfully")
                        loginFieldsFound = true
                        vpnWindowFound = true
                        break
                    } else {
                        logger.warning("Login fields not found in current window")
                        if let error = checkError {
                            logger.error("Script error: \(error)")
                        }
                    }
                }
            }
            
            logger.warning("Waiting for VPN login fields (attempt \(windowRetryCount + 1)/\(maxWindowRetries))")
            try await Task.sleep(for: .seconds(5))
            windowRetryCount += 1
        }
        
        if !vpnWindowFound || !loginFieldsFound {
            logger.error("VPN login fields not found after \(maxWindowRetries) attempts")
            throw VPNError.authenticationFailed
        }
        
        logger.info("VPN login fields found, proceeding with credentials")
        
        // Enter credentials
        let loginScript = """
        tell application "System Events"
            tell process "BIG-IP Edge Client"
                set frontmost to true
                delay 1
                keystroke "\(credentials.username)"
                delay 0.5
                keystroke tab
                delay 0.5
                keystroke "\(credentials.password)"
                delay 0.5
                keystroke return
            end tell
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: loginScript) {
            _ = scriptObject.executeAndReturnError(&error)
            if error != nil {
                logger.error("Failed to enter credentials: \(String(describing: error))")
                throw VPNError.scriptError("Failed to enter credentials")
            }
        }
        
        // Wait for 2FA prompt (up to 45 seconds)
        try await Task.sleep(for: .seconds(5))
        
        // Request 2FA code from user
        let twoFactorCode = try await VPNService.shared.requestTwoFactorCode()
        
        // Enter 2FA code
        let twoFactorScript = """
        tell application "System Events"
            tell process "F5 Networks VPN"
                set frontmost to true
                delay 1
                keystroke "\(twoFactorCode)"
                delay 0.5
                keystroke return
            end tell
        end tell
        """
        
        if let scriptObject = NSAppleScript(source: twoFactorScript) {
            _ = scriptObject.executeAndReturnError(&error)
            if error != nil {
                logger.error("Failed to enter 2FA code: \(String(describing: error))")
                throw VPNError.scriptError("Failed to enter 2FA code")
            }
        }
        
        // Wait for connection to be established
        var connectionRetryCount = 0
        let maxConnectionRetries = 12  // 60 seconds total wait time
        
        while connectionRetryCount < maxConnectionRetries {
            if try await checkVPNStatus() {
                logger.info("VPN connection established successfully")
                return
            }
            try await Task.sleep(for: .seconds(5))
            connectionRetryCount += 1
        }
        
        logger.error("VPN connection failed to establish after timeout")
        throw VPNError.authenticationFailed
    }

    private func checkVPNStatus() async throws -> Bool {
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
}
