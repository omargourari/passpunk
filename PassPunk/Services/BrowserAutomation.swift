import Foundation

@MainActor  // Rende la classe thread-safe usando MainActor
final class BrowserAutomation: @unchecked Sendable {
    static let shared = BrowserAutomation()
    
    private init() {}
    
    func getPasswordExpiryDays() throws -> Int {
        // Logica temporanea: restituisce i giorni rimanenti basati sull'ultima modifica
        if let lastUpdate = UserDefaults.standard.object(forKey: "LastUpdateTime") as? Date {
            let calendar = Calendar.current
            let expiryDate = calendar.date(byAdding: .day, value: 90, to: lastUpdate) ?? Date()
            let components = calendar.dateComponents([.day], from: Date(), to: expiryDate)
            return max(0, components.day ?? 0)
        }
        return 0
    }
}
