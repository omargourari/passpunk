import SwiftUI

struct SettingsView: View {
    @AppStorage("vpnUsername") private var vpnUsername: String = ""
    @AppStorage("browserType") private var browserType: Settings.BrowserType = .chrome
    @AppStorage("checkInterval") private var checkInterval: Double = 1800
    @AppStorage("defaultPasswordComment") private var defaultPasswordComment: String = ""
    @State private var launchAtLogin: Bool = LaunchAgentManager.shared.isLaunchAgentInstalled()
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
            Form {
                Section("VPN Settings") {
                    TextField("VPN Username", text: $vpnUsername)
                    SecureField("VPN Password", text: .constant(""))
                        .textContentType(.password)
                }
                
                Section("Browser Settings") {
                    Picker("Browser", selection: $browserType) {
                        Text("Chrome").tag(Settings.BrowserType.chrome)
                        Text("Safari").tag(Settings.BrowserType.safari)
                        Text("Firefox").tag(Settings.BrowserType.firefox)
                    }
                }
                
                Section("Check Settings") {
                    Picker("Check Interval", selection: $checkInterval) {
                        Text("30 minutes").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                    }
                }
                
                Section("Password Settings") {
                    TextField("Default Password Comment", text: $defaultPasswordComment)
                }
                
                Section("Startup Settings") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { 
                            do {
                                if launchAtLogin {
                                    try LaunchAgentManager.shared.installLaunchAgent()
                                } else {
                                    try LaunchAgentManager.shared.uninstallLaunchAgent()
                                }
                            } catch {
                                print("Failed to configure launch agent: \(error)")
                                launchAtLogin = LaunchAgentManager.shared.isLaunchAgentInstalled()
                            }
                        }
                }
            }
        }
        .padding()
    }
}

// Aggiungi il preview
#Preview {
    SettingsView()
}
