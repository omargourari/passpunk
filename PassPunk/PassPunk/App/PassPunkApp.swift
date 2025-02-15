import SwiftUI

@main
struct PassPunkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
                .frame(width: 400, height: 300)
        }
    }
} 