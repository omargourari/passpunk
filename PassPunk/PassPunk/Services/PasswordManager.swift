import Foundation
import AppKit
//@testable import PassPunk // Remove this - we're not importing a module

class PasswordManager {
    static let shared = try! PasswordManager()
    private let keychain = KeychainManager.shared

    private init() throws {
        // Initialization
    }

    func checkAndUpdatePassword() async throws {
        print("Starting password check process...")

        // Use AppleScript to tell VPNManager to authenticate
        try await authenticateWithVPNManager()
        print("VPN connected successfully (via VPNManager)")

        let currentPassword = try getCurrentPassword()

        if currentPassword.isEmpty {
            throw PasswordError.invalidPassword
        }

        await MainActor.run {
            UserDefaults.standard.set(Date(), forKey: "LastUpdateTime")
        }

        print("Password check completed")
    }

    func updatePassword(_ newPassword: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try keychain.savePassword(newPassword, forAccount: "passpunk_main")
    }

    func getCurrentPassword() throws -> String {
        try keychain.getPassword(forAccount: "passpunk_main")
    }

    func checkPasswords() async {
        print("Checking passwords...")

        do {
            try await checkAndUpdatePassword()

            await MainActor.run {
                let successAlert = NSAlert()
                successAlert.messageText = "Controllo Completato"
                successAlert.informativeText = "Il controllo delle password è stato completato con successo"
                successAlert.alertStyle = .informational
                successAlert.runModal()
            }

        } catch {
            print("Errore durante il controllo: \(error)")

            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Errore"

                if let passwordError = error as? PasswordError {
                    alert.informativeText = passwordError.localizedDescription
                } else {
                    alert.informativeText = error.localizedDescription
                }

                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }

    private func authenticateWithVPNManager() async throws {
        let scriptSource = """
        tell application "Bita"
            startVPN
        end tell
        """

        return try await withCheckedThrowingContinuation { continuation in
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: scriptSource) {
                let _: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                    continuation.resume(throwing: PasswordError.vpnError) // Or a more specific error
                } else {
                    // If no error, assume success.  You might want to add more robust checking
                    // by having VPNManager return a value from the AppleScript.
                    continuation.resume()
                }
            } else {
                continuation.resume(throwing: PasswordError.vpnError) // Script compilation failed
            }
        }
    }
}

enum PasswordError: Error {
    case invalidPassword
    case networkError
    case vpnError

    var localizedDescription: String {
        switch self {
        case .invalidPassword:
            return "Password non valida o mancante"
        case .networkError:
            return "Errore di rete durante il controllo"
        case .vpnError:
            return "Errore di connessione VPN"
        }
    }
}
