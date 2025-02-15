import Foundation
import AppKit

class PasswordManager {
    static let shared = try! PasswordManager()
    private let keychain = KeychainManager.shared

    private init() throws {
        // Initialization
    }

    func checkAndUpdatePassword() async throws {
        print("Starting password check process...")

        // Use VPNManager to authenticate
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
        // Use VPNManager instead of AppleScript
        try await VPNManager.shared.authenticate()
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
