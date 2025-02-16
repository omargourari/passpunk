import Cocoa
import SwiftUI

class StatusBarController: ObservableObject {
    static let shared = StatusBarController()
    
    @Published var isVPNActive: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var connectionStatus: VPNStatus = .disconnected
    
    private var statusBarItem: NSStatusItem?
    private var statusCheckTimer: Timer?
    private weak var menuDelegate: StatusBarMenuDelegate?
    
    private init() {
        setupInitialStatusBar()
        startVPNCheck()
    }
    
    private func setupInitialStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            let image = NSImage(systemSymbolName: "network", accessibilityDescription: "PassPunk")
            image?.isTemplate = true
            button.image = image
            updateIcon(button)
        }
    }
    
    func configureStatusBar(delegate: StatusBarMenuDelegate) {
        self.menuDelegate = delegate
        if let button = statusBarItem?.button {
            updateIcon(button)
        }
    }
    
    private func startVPNCheck() {
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                await self?.checkVPNStatus()
            }
        }
    }
    
    @MainActor
    private func checkVPNStatus() async {
        do {
            let status = try await VPNManager.shared.checkVPNStatus()
            self.isVPNActive = status
            self.connectionStatus = status ? .connected : .disconnected
            if let button = statusBarItem?.button {
                updateIcon(button)
            }
        } catch {
            self.isVPNActive = false
            self.connectionStatus = .disconnected
            if let button = statusBarItem?.button {
                updateIcon(button)
            }
        }
    }
    
    private func updateIcon(_ button: NSStatusBarButton) {
        button.contentTintColor = isVPNActive ? .systemGreen : .systemRed
    }
} 