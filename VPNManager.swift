import Foundation
import Cocoa
import Security

class VPNManager {
    static let shared = VPNManager()

    private init() {}

    enum VPNError: Error {
        case credentialsNotFound
        case applicationNotFound
        case authenticationFailed
        case scriptError(String)
    }

    func authenticate() async throws {
        guard let credentials = try getCredentials() else {
            throw VPNError.credentialsNotFound
        }

        try startVPN() // Ensure the VPN application is running before login
        try await performLogin(with: credentials)
    }

    private func getCredentials() throws -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DeloitteVPN",
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let existingItem = item as? [String: Any],
              let passwordData = existingItem[kSecValueData as String] as? Data,
              let password = String(data: passwordData, encoding: .utf8),
              let account = existingItem[kSecAttrAccount as String] as? String
        else {
            return nil
        }

        return (username: account, password: password)
    }

    func saveCredentials(username: String, password: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DeloitteVPN"
        ]
        SecItemDelete(query as CFDictionary)

        let credentials: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "DeloitteVPN",
            kSecAttrAccount as String: username,
            kSecValueData as String: password.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(credentials as CFDictionary, nil)
        if status != errSecSuccess {
            throw VPNError.scriptError("Errore nel salvataggio delle credenziali")
        }
    }

    func startVPN() throws {
        guard let vpnURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.f5.epi") else {
            throw VPNError.applicationNotFound
        }

        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = ["-a", vpnURL.path, "--background"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw VPNError.scriptError("Errore nell'avvio dell'applicazione VPN")
        }
    }

    private func performLogin(with credentials: (username: String, password: String)) async throws {
        let script = """
        tell application "System Events"
            tell process "F5 Networks VPN"
                delay 2

                repeat until (exists window 1)
                    delay 0.5
                end repeat

                if exists (text field 1 of window 1) then
                    click text field 1 of window 1
                    delay 0.5
                    keystroke "\(credentials.username)"
                    delay 0.5
                    keystroke tab
                    delay 0.5
                    keystroke "\(credentials.password)"
                    delay 0.5

                    if exists button "Logon" of window 1 then
                        click button "Logon" of window 1
                    else
                        keystroke return
                    end if
                end if
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let _ = scriptObject.executeAndReturnError(&error)
            if let error = error {
                throw VPNError.scriptError("Errore nell'esecuzione dello script: \(error)")
            }
        }
    }
}