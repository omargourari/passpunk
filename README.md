# PassPunk

PassPunk is a macOS utility designed to automate VPN authentication and password management for corporate environments. It runs in the background and provides easy access through the menu bar.

## Features

- Automated VPN connection management
- Two-factor authentication handling
- Password expiration monitoring
- Status monitoring through menu bar icon
- Manual and automatic password renewal
- Secure credential storage

## User Guide

### Installation
Download and install PassPunk. On first launch, you'll be prompted to enter your VPN credentials and to enable accessibility tools access to the app.

### Menu Bar Interface
- Green icon: VPN connected
- Red icon: VPN disconnected
- Blue animated icon: Authentication in progress
- Click: Open application window
- Long press (3s): Initiate VPN connection and admin password expiry time check

### Main Window
- Monitor VPN connection status
- View password expiration countdown
- Configure check intervals
- Manually trigger password renewal
- Update VPN credentials

## Technical Documentation
****
### Architecture Overview
PassPunk follows a modular architecture with clear separation of concerns:
- UI Layer (SwiftUI views)
- Business Logic (Managers)
- Services Layer
- Data Persistence (Keychain)

### Core Components

#### App Foundation
- `PassPunkApp.swift` (lines 1-13): Main app entry point, configures window group and app delegate
- `AppDelegate.swift` (lines 1-115): Manages application lifecycle and status bar integration

#### Views
- `MainAppView.swift` (lines 55-564): Main settings window interface
- `TwoFactorView.swift` (lines 1-101): 2FA input modal with paste support

#### Controllers
- `StatusBarController.swift` (lines 1-66): Manages menu bar icon and status updates
- `StatusBarMenu.swift` (lines 1-184): Handles menu bar interactions and VPN status monitoring

#### Managers
- `VPNManager.swift` (lines 174-213): Core VPN authentication and connection management
- `FirstLaunchManager.swift` (lines 98-120): Handles initial setup and credential collection
- `KeychainManager.swift` (lines 1-57): Secure credential storage

#### Services
- `VPNService.swift` (lines 1-55): VPN connection monitoring and reconnection logic

### Implementation Details

#### VPN Authentication Flow
1. Status check initiated (manual/automatic)
2. VPN connection verified
3. If disconnected:
   - Retrieve credentials from Keychain
   - Submit login form
   - Handle 2FA if required
   - Monitor connection status

#### Two-Factor Authentication
Custom modal implementation with features:
- Individual digit input fields
- Clipboard paste support
- Auto-advancement
- Automatic submission

#### Security Considerations
- Credentials stored in Keychain
- Password encryption at rest
- Secure window management
- Protected clipboard handling

### Planned Features
- Certificate-based authentication
- Multiple VPN profile support
- Advanced password policies
- Network condition monitoring

### Empty Files (Planned)
- `NetworkMonitor.swift`: Future implementation for network state monitoring
- `CertificateManager.swift`: Planned support for certificate-based authentication
- `LogManager.swift`: Structured logging implementation
- `PreferencesManager.swift`: User preferences persistence

## Contributing
Contributions welcome. Please follow the existing code style and include appropriate tests.

## License
Proprietary software. All rights reserved. 