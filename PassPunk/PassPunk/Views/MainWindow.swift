struct MainWindow: View {
    // Manteniamo gli stessi state e property wrapper
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
    
    @StateObject private var statusBarMenu = StatusBarMenu.shared
    
    // Il resto del codice rimane lo stesso della SettingsView
    // Riferimento alle linee 27-366 del file originale
} 