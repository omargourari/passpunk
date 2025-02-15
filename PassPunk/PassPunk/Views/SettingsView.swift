import SwiftUI
import Security

struct SettingsView: View {
    @AppStorage("vpnUsername") private var vpnUsername: String = ""
    @State private var vpnPassword: String = ""
    @AppStorage("browserType") private var browserType: Settings.BrowserType = .chrome
    @AppStorage("checkInterval") private var checkInterval: Double = 1800
    @AppStorage("defaultPasswordComment") private var defaultPasswordComment: String = ""
    @State private var launchAtLogin: Bool = LaunchAgentManager.shared.isLaunchAgentInstalled()
    
    @State private var lastUpdateTime: String = "Never"
    @State private var vpnStatus: String = "Disconnected"
    @State private var checkStatus: CheckStatus = .idle
    @State private var remainingTime: Int = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let statusTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    private let keychainService = "com.passpunk.vpn"
    private let keychainAccount = "vpnpassword"
    
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var statusBarMenu = StatusBarMenu.shared
    
    enum CheckStatus {
        case idle
        case inProgress
        
        var description: String {
            switch self {
            case .idle: return "Last check completed"
            case .inProgress: return "Check in progress"
            }
        }
    }
    
    init() {
        // Carica la password dal Keychain all'inizializzazione
        _vpnPassword = State(initialValue: loadPasswordFromKeychain() ?? "")
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Status Section
            GroupBox {
                HStack(spacing: 16) {
                    // VPN Status
                    StatusItem(
                        title: "VPN",
                        value: vpnStatus
                    )
                    
                    Divider()
                    
                    // Password Expiry
                    StatusItem(
                        title: "Password Expires in",
                        value: "\(passwordExpiryDays) days"  // Dovrai aggiungere questa proprietà
                    )
                    
                    Divider()
                    
                    // Next Check Timer
                    StatusItem(
                        title: "Next Check in",
                        value: formatTime(remainingTime)
                    )
                }
                .padding(.vertical, 12)
            }
            
            // VPN Settings Section
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Virtual Private Network (VPN)")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("VPN Username", text: $vpnUsername)
                            .textFieldStyle(CustomTextFieldStyle())
                            .onChange(of: vpnUsername) { oldValue, newValue in
                                do {
                                    try VPNManager.shared.saveCredentials(username: newValue, password: vpnPassword)
                                } catch {
                                    print("Error saving VPN credentials: \(error)")
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        SecureField("VPN Password", text: $vpnPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                            .onChange(of: vpnPassword) { oldValue, newValue in
                                do {
                                    try VPNManager.shared.saveCredentials(username: vpnUsername, password: newValue)
                                } catch {
                                    print("Error saving VPN credentials: \(error)")
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check Interval")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $checkInterval) {
                            Text("15 minutes").tag(900.0)
                            Text("30 minutes").tag(1800.0)
                            Text("1 hour").tag(3600.0)
                            Text("3 hours").tag(10800.0)
                            Text("6 hours").tag(21600.0)
                            Text("12 hours").tag(43200.0)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(.vertical, 12)
            }
            
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(CustomToggleStyle())
                .onChange(of: launchAtLogin) { oldValue, newValue in 
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
                .padding(.horizontal)
            
            // Administrator Settings Section
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Administrator Password")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .padding(.bottom, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Browser for Password Retrieval")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Picker("", selection: $browserType) {
                            Text("Chrome").tag(Settings.BrowserType.chrome)
                            Text("Safari").tag(Settings.BrowserType.safari)
                            Text("Firefox").tag(Settings.BrowserType.firefox)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Password Check Message")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("Enter message", text: $defaultPasswordComment)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                .padding(.vertical, 12)
            }
            
            Spacer()
            
            // Bottom Buttons
            HStack {
                Button(action: {
                    Task {
                        try await VPNManager.shared.authenticate()
                    }
                }) {
                    Text("Enable VPN")
                        .frame(minWidth: 100)
                }
                .buttonStyle(CustomButtonStyle())
                
                Button(action: {
                    // Implementa il refresh della password
                }) {
                    Text("Renew Admin Password")
                        .frame(minWidth: 100)
                }
                .buttonStyle(CustomButtonStyle())
                
                Spacer()
                
                Button("Quit PassPunk") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(CustomButtonStyle())
            }
            .padding(.horizontal)
        }
        .padding(20)
        .frame(minWidth: 650, minHeight: 780)
        .onAppear {
            if let credentials = try? VPNManager.shared.getCredentials() {
                vpnUsername = credentials.username
                vpnPassword = credentials.password
            }
            updateStatus()
        }
        .onReceive(statusTimer) { _ in
            updateStatus()
        }
        .onReceive(timer) { _ in
            updateRemainingTime()
        }
    }
    
    private func updateStatus() {
        // Update VPN status using the shared instance
        vpnStatus = statusBarMenu.isVPNActive ? "Connected" : "Disconnected"
        
        // Update last check time
        if let lastUpdate = UserDefaults.standard.object(forKey: "LastUpdateTime") as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastUpdateTime = formatter.string(from: lastUpdate)
        }
    }
    
    private func updateRemainingTime() {
        if checkStatus == .inProgress {
            remainingTime -= 1
            if remainingTime <= 0 {
                checkStatus = .idle
                remainingTime = Int(checkInterval)
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func savePasswordToKeychain(_ password: String) {
        let passwordData = password.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: passwordData
        ]
        
        // Prima rimuovi la password esistente
        SecItemDelete(query as CFDictionary)
        
        // Poi salva la nuova password
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error saving password to Keychain: \(status)")
        }
    }
    
    private func loadPasswordFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let passwordData = result as? Data,
              let password = String(data: passwordData, encoding: .utf8)
        else {
            return nil
        }
        
        return password
    }
}

// Stili personalizzati
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(8)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(.separatorColor), lineWidth: 0.5)
            )
    }
}

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: configuration.$isOn)
        }
    }
}

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlAccentColor))
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct StatusItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }
}

// Custom section style
struct CustomFormSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
    }
}

// Preview
#Preview {
    SettingsView()
        .frame(width: 400, height: 500)
}
