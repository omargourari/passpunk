import Cocoa
import SystemConfiguration
import Network
import Darwin.POSIX.net
import SwiftUI

@objc protocol StatusBarMenuDelegate: AnyObject {
    @objc func openSettings()
    @objc func quitApp()
}

@MainActor
final class StatusBarMenu: @unchecked Sendable {
    weak var delegate: StatusBarMenuDelegate?
    @Published var isVPNActive: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var connectionStatus: VPNStatus = .disconnected
    private var longPressTimer: Timer?
    private var animationTimer: Timer?
    private var rotationAngle: CGFloat = 0
    private var statusBarItem: NSStatusItem?
    
    static let shared = StatusBarMenu()
    
    init() {
        startVPNCheck()
    }
    
    private func startVPNCheck() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task {
                try? await self?.checkVPNStatus()
            }
        }
    }
    
    func checkVPNStatus() async throws {
        do {
            let status = try await VPNManager.shared.checkVPNStatus()
            await MainActor.run {
                self.isVPNActive = status
                self.connectionStatus = status ? .connected : .disconnected
                if let button = statusBarItem?.button {
                    updateIcon(button)
                }
            }
        } catch {
            await MainActor.run {
                self.isVPNActive = false
                self.connectionStatus = .disconnected
                if let button = statusBarItem?.button {
                    updateIcon(button)
                }
            }
        }
    }
    
    func setupStatusBarButton(_ button: NSStatusBarButton) {
        // Salva il riferimento allo statusBarItem
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Configura il gesture recognizer per il long press
        let pressGesture = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        pressGesture.minimumPressDuration = 0.3
        button.addGestureRecognizer(pressGesture)
        
        // Configura il click normale
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        
        // Imposta l'icona iniziale e il colore
        let image = NSImage(systemSymbolName: "network", accessibilityDescription: "PassPunk")
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = .systemRed
        
        updateIcon(button)
    }
    
    private func updateIcon(_ button: NSStatusBarButton) {
        let image = NSImage(systemSymbolName: "network", accessibilityDescription: "PassPunk")
        image?.isTemplate = true
        button.image = image
        
        if isAuthenticating {
            startIconAnimation(button)
        } else {
            stopIconAnimation()
            button.contentTintColor = isVPNActive ? .systemGreen : .systemRed
        }
    }
    
    private func startIconAnimation(_ button: NSStatusBarButton) {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.rotationAngle += .pi / 8
                
                let image = NSImage(systemSymbolName: "network", accessibilityDescription: "PassPunk")
                image?.isTemplate = true
                
                let rotatedImage = image?.rotated(by: self.rotationAngle)
                button.image = rotatedImage
                button.contentTintColor = .systemBlue
            }
        }
    }
    
    private func stopIconAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        rotationAngle = 0
    }
    
    @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.startVPNAuthentication()
                }
            }
        case .ended, .cancelled:
            longPressTimer?.invalidate()
            longPressTimer = nil
        default:
            break
        }
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        longPressTimer?.invalidate()
        longPressTimer = nil
        delegate?.openSettings()
    }
    
    private func startVPNAuthentication() {
        isAuthenticating = true
        if let button = statusBarItem?.button {
            updateIcon(button)
        }
        
        Task {
            do {
                try await VPNManager.shared.authenticate()
                await MainActor.run {
                    self.isAuthenticating = false
                    self.isVPNActive = true
                    if let button = statusBarItem?.button {
                        updateIcon(button)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isAuthenticating = false
                    if let button = statusBarItem?.button {
                        updateIcon(button)
                    }
                }
            }
        }
    }
}

// Estensione per la rotazione dell'immagine
extension NSImage {
    func rotated(by angle: CGFloat) -> NSImage {
        let size = self.size
        let newImage = NSImage(size: size)
        
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        
        let transform = NSAffineTransform()
        transform.translateX(by: size.width / 2, yBy: size.height / 2)
        transform.rotate(byDegrees: angle * 180 / .pi)
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        
        draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        
        return newImage
    }
}
