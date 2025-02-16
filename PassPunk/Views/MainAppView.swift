import SwiftUI
import Security
import PassPunk

struct MainAppView: View {
    @AppStorage("vpnUsername") private var vpnUsername: String = ""
    @State private var vpnPassword: String = ""
    @AppStorage("browserType") private var browserType: Settings.BrowserType = .chrome
    @AppStorage("checkInterval") private var checkInterval: Double = 1800
    @AppStorage("defaultPasswordComment") private var defaultPasswordComment: String = ""
    @State private var launchAtLogin: Bool = LaunchAgentManager.shared.isLaunchAgentInstalled()
    
    @State private var lastUpdateTime: String = "Never"
    @State private var checkStatus: CheckStatus = .idle
    @State private var remainingTime: Int = 0
    
    @State private var passwordExpiryDays: Int = 0
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let statusTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    private let keychainService = "com.passpunk.vpn"
    private let keychainAccount = "vpnpassword"
    
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var statusBarController = StatusBarController.shared
    @StateObject private var vpnManager = VPNManager.shared
    
    init() {
        _vpnPassword = State(initialValue: loadPasswordFromKeychain() ?? "")
        
        // Ensure VPN credentials are saved if they exist
        if let password = loadPasswordFromKeychain(),
           !password.isEmpty,
           let username = UserDefaults.standard.string(forKey: "vpnUsername"),
           !username.isEmpty {
            try? VPNManager.shared.saveCredentials(username: username, password: password)
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Status Section
            HStack(spacing: 16) {
                // VPN Status
                StatusTag(
                    title: "VPN",
                    status: statusBarController.connectionStatus
                )
                
                Rectangle()
                    .frame(width: 1, height: 30)
                    .foregroundColor(Color(nsColor: .separatorColor))
                
                // Password Expiry
                StatusItem(
                    title: "Password Expires in",
                    value: "\(passwordExpiryDays) days"
                )
                
                Rectangle()
                    .frame(width: 1, height: 30)
                    .foregroundColor(Color(nsColor: .separatorColor))
                
                // Next Check Timer
                StatusItem(
                    title: "Next Check in",
                    value: formatTime(remainingTime)
                )
            }
            .padding(.vertical, 8)
            
            // Nuova struttura per i blocchi principali
            VStack(spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    // VPN Section
                    GroupBox("Private Network") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Username")
                                    .frame(width: 80, alignment: .leading)
                                TextField("VPN Username", text: $vpnUsername)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            HStack {
                                Text("Password")
                                    .frame(width: 80, alignment: .leading)
                                SecureField("VPN Password", text: $vpnPassword)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                        }
                        .padding(12)
                    }
                    
                    // Admin Password Section
                    GroupBox("Admin Password") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Renew Motivation")
                                    .frame(width: 120, alignment: .leading)
                                TextField("Default message", text: $defaultPasswordComment)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                        }
                        .padding(12)
                    }
                }
                
                // Settings Section
                GroupBox("Settings") {
                    VStack(spacing: 12) {
                        // Check Interval
                        HStack {
                            Text("Check-in Interval")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                IntervalButton(title: "30m", interval: 1800, selectedInterval: $checkInterval)
                                IntervalButton(title: "1h", interval: 3600, selectedInterval: $checkInterval)
                                IntervalButton(title: "2h", interval: 7200, selectedInterval: $checkInterval)
                            }
                        }
                        
                        // Browser Selection
                        HStack {
                            Text("Browser for Password Retrieval")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 8) {
                                BrowserButton(type: .chrome, selectedType: $browserType)
                                BrowserButton(type: .safari, selectedType: $browserType)
                            }
                        }
                        
                        // Launch at Login
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .toggleStyle(CustomToggleStyle())
                    }
                    .padding(12)
                }
            }
            
            Spacer()
            
            // Bottom Buttons
            HStack {
                // VPN Button
                vpnButton
                
                // Admin Password Button
                Button(action: {
                    // Implementa il refresh della password
                }) {
                    Text("Renew Admin Password")
                        .frame(minWidth: 100)
                }
                .buttonStyle(VPNButtonStyle(
                    isEnabled: statusBarController.connectionStatus == .connected,
                    isVPNButton: false
                ))
                
                Spacer()
                
                Button("Quit PassPunk") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(VPNButtonStyle(
                    isEnabled: true,
                    isVPNButton: false
                ))
            }
            .padding(.horizontal)
        }
        .padding(20)
        .frame(minWidth: 650, minHeight: 520)
        .onAppear {
            if let credentials = try? VPNManager.shared.getCredentials() {
                vpnUsername = credentials.username
                vpnPassword = credentials.password
            } else if !vpnUsername.isEmpty && !vpnPassword.isEmpty {
                // If we have credentials in the view but not in VPNManager, save them
                try? VPNManager.shared.saveCredentials(username: vpnUsername, password: vpnPassword)
            }
            updateStatus()
        }
        .onReceive(statusTimer) { _ in
            updateStatus()
        }
        .onReceive(timer) { _ in
            updateRemainingTime()
        }
        .onDisappear {
            // Clean up any observers or timers
            timer.upstream.connect().cancel()
            statusTimer.upstream.connect().cancel()
        }
    }
    
    private func updateStatus() {
        // Update VPN status using the shared instance
        statusBarController.connectionStatus = vpnManager.connectionState
        
        // Update password expiry days
        if let expiryDays = try? BrowserAutomation.shared.getPasswordExpiryDays() {
            passwordExpiryDays = expiryDays
        }
        
        // Update last check time
        if let lastCheck = UserDefaults.standard.object(forKey: "lastCheckTime") as? Date {
            lastUpdateTime = formatDate(lastCheck)
        }
        
        // Calculate remaining time
        if checkStatus == .idle {
            let lastCheckTime = UserDefaults.standard.object(forKey: "lastCheckTime") as? Date ?? Date()
            let nextCheckTime = lastCheckTime.addingTimeInterval(checkInterval)
            remainingTime = Int(nextCheckTime.timeIntervalSince(Date()))
            if remainingTime < 0 {
                remainingTime = 0
            }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
    
    private var vpnButton: some View {
        Button(action: {
            Task {
                do {
                    try await vpnManager.authenticate()
                } catch {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "VPN Error"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        }) {
            if vpnManager.isAuthenticating || vpnManager.connectionState == .connecting {
                ConnectingText()
            } else {
                Text(getVPNButtonText())
            }
        }
        .buttonStyle(VPNButtonStyle(isEnabled: !vpnManager.isAuthenticating, isVPNButton: true))
        .disabled(vpnManager.isAuthenticating)
    }
    
    private func getVPNButtonText() -> String {
        if vpnManager.isAuthenticating {
            return "Connecting..."
        }
        
        switch vpnManager.connectionState {
        case .connected:
            return "Disable VPN"
        case .disconnected:
            return "Enable VPN"
        case .connecting:
            return "Connecting..."
        }
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
    func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        HStack {
            configuration.label
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: configuration.$isOn)
                .labelsHidden()
        }
    }
}

struct CustomButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct DisabledButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.disabledControlTextColor).opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(6)
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

struct StatusTag: View {
    let title: String
    let status: VPNStatus
    @State private var dotOffset: CGFloat = 0
    
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text(status.description)
                    .font(.system(size: 13, weight: .medium))
                
                if status == .connecting {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white)
                                .frame(width: 4, height: 4)
                                .opacity(dotOffset == CGFloat(index) ? 1 : 0.3)
                        }
                    }
                    .onReceive(timer) { _ in
                        withAnimation {
                            dotOffset = (dotOffset + 1).truncatingRemainder(dividingBy: 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color)
            .foregroundColor(.white)
            .cornerRadius(4)
        }
    }
}

#Preview {
    MainAppView()
        .frame(width: 400, height: 500)
}

struct IntervalButton: View {
    let title: String
    let interval: Double
    @Binding var selectedInterval: Double
    
    var body: some View {
        Button(action: {
            selectedInterval = interval
        }) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(TagButtonStyle(isSelected: selectedInterval == interval))
    }
}

struct BrowserButton: View {
    let type: Settings.BrowserType
    @Binding var selectedType: Settings.BrowserType
    
    var title: String {
        switch type {
        case .chrome: return "Chrome"
        case .safari: return "Safari"
        case .firefox: return "Firefox"
        }
    }
    
    var body: some View {
        Button(action: {
            selectedType = type
        }) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(TagButtonStyle(isSelected: selectedType == type))
    }
}

struct TagButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color(.separatorColor), lineWidth: 0.5)
            )
    }
}

struct VPNButtonStyle: ButtonStyle {
    let isEnabled: Bool
    let isVPNButton: Bool
    
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(getBackgroundColor())
            .foregroundColor(.white)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1.0)
    }
    
    private func getBackgroundColor() -> Color {
        if isVPNButton {
            return isEnabled ? Color.accentColor : Color(.disabledControlTextColor).opacity(0.3)
        } else {
            return isEnabled ? Color.accentColor : Color(.disabledControlTextColor).opacity(0.3)
        }
    }
}

struct ConnectingText: View {
    @State private var dotsOffset: Int = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Connecting")
            HStack(spacing: 2) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .opacity(index == dotsOffset ? 1 : 0.3)
                }
            }
            .padding(.leading, 4)
        }
    }
}
