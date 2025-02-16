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
        print("StatusBarController: Initializing...")
        setupInitialStatusBar()
        if statusBarItem?.button == nil {
            print("StatusBarController: Failed to create status bar item")
        } else {
            print("StatusBarController: Status bar item created successfully")
        }
        startVPNCheck()
    }
    
    private func setupInitialStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem?.button {
            let image: NSImage?
            if let systemImage = NSImage(systemSymbolName: "network", accessibilityDescription: "PassPunk") {
                image = systemImage
            } else {
                // Fallback to a custom image or another system symbol
                image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "PassPunk")
            }
            
            image?.isTemplate = true
            button.image = image
            updateIcon(button)
        } else {
            print("Failed to create status bar button")
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
        if isAuthenticating {
            button.contentTintColor = .systemBlue
        } else {
            button.contentTintColor = isVPNActive ? .systemGreen : .systemRed
        }
        
        // Ensure the image is visible
        button.image?.size = NSSize(width: 18, height: 18)
        button.image?.isTemplate = true
    }
} 