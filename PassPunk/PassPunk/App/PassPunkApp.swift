import SwiftUI

@main
struct PassPunkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainAppView()
                .frame(minWidth: 650, minHeight: 520)
        }
    }
} 