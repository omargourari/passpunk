import Foundation
import Cocoa
import os.log

@available(macOS 15.0, *)
class FirstLaunchManager: @unchecked Sendable {
    static let shared = FirstLaunchManager()
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.passpunk.PassPunk", category: "FirstLaunchManager")
    private let vpnManager = VPNManager.shared
    
    private let firstLaunchKey = "hasLaunchedBefore"
    private let accessibilityEnabled = "accessibilityPermissionGranted"
    
    private init() {}
    
    func checkFirstLaunch() async throws {
        if !defaults.bool(forKey: firstLaunchKey) {
            logger.info("First launch detected - starting onboarding process")
            try await performFirstLaunchSetup()
        }
    }
    
    private func performFirstLaunchSetup() async throws {
        logger.info("Starting first launch setup")
        
        // Richiedi permessi di accessibilità
        if !checkAccessibilityPermissions() {
            try await requestAccessibilityPermissions()
        }
        
        // Mostra dialog per le credenziali VPN
        try await showCredentialsDialog()
        
        // Marca come primo avvio completato
        defaults.set(true, forKey: firstLaunchKey)
        defaults.synchronize()
        
        logger.info("First launch setup completed successfully")
    }
    
    private func checkAccessibilityPermissions() -> Bool {
        let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        let options = [checkOptPrompt: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func requestAccessibilityPermissions() async throws {
        logger.info("Requesting accessibility permissions")
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Permessi di Accessibilità Richiesti"
                alert.informativeText = """
                    PassPunk necessita dei permessi di accessibilità per funzionare correttamente con F5 VPN.
                    
                    1. Clicca "Apri Impostazioni"
                    2. Sblocca il lucchetto se necessario
                    3. Seleziona PassPunk nella lista
                    4. Riavvia PassPunk dopo aver concesso i permessi
                    """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Apri Impostazioni")
                alert.addButton(withTitle: "Annulla")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let prefpaneURL = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")
                    NSWorkspace.shared.open(prefpaneURL)
                    
                    // Apri direttamente il pannello Privacy & Security
                    let script = """
                    tell application "System Preferences"
                        activate
                        set current pane to pane id "com.apple.preference.security"
                        delay 1
                        tell application "System Events"
                            tell process "System Preferences"
                                click button "Privacy" of toolbar 1 of window 1
                                delay 0.5
                                select row 2 of table 1 of scroll area 1 of group 1 of window 1
                            end tell
                        end tell
                    end tell
                    """
                    
                    var error: NSDictionary?
                    if let scriptObject = NSAppleScript(source: script) {
                        scriptObject.executeAndReturnError(&error)
                    }
                }
                
                continuation.resume()
            }
        }
    }
    
    private func showCredentialsDialog() async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Configurazione VPN"
                alert.informativeText = "Inserisci le tue credenziali VPN"
                alert.alertStyle = .informational
                
                let stackView = NSStackView()
                stackView.orientation = .vertical
                stackView.spacing = 8
                
                let usernameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                
                stackView.addArrangedSubview(usernameField)
                stackView.addArrangedSubview(passwordField)
                
                alert.accessoryView = stackView
                alert.addButton(withTitle: "Salva")
                alert.addButton(withTitle: "Annulla")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn && 
                   !usernameField.stringValue.isEmpty && 
                   !passwordField.stringValue.isEmpty {
                    do {
                        try self.vpnManager.saveCredentials(
                            username: usernameField.stringValue,
                            password: passwordField.stringValue
                        )
                        
                        // Verify credentials were saved
                        if let _ = try self.vpnManager.getCredentials() {
                            self.logger.info("Credentials saved and verified")
                            continuation.resume()
                        } else {
                            self.logger.error("Credentials verification failed")
                            let error = NSError(
                                domain: "com.passpunk.PassPunk",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to verify saved credentials"]
                            )
                            continuation.resume(throwing: error)
                        }
                    } catch {
                        self.logger.error("Failed to save credentials: \(error)")
                        self.showError(message: "Failed to save credentials: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    private func showError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
} 
