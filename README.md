# PassPunk

PassPunk is a macOS utility designed to automate VPN authentication and password management for corporate environments. It runs in the background and provides easy access through the menu bar.

## System Requirements
- macOS 15.0 or later
- F5 VPN Client installed
- Administrative privileges for password management

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

#### System Requirements
- Minimum macOS Version: 15.0
- Target macOS Version: 15.0+
- Required Permissions: 
  - Accessibility
  - Keychain Access
  - Automation

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

## Technical Analysis

### Core Components Analysis

#### VPNManager (VPNManager.swift)
```swift:PassPunk/Managers/VPNManager.swift
startLine: 10
endLine: 56
```
- Singleton pattern implementation
- Handles VPN authentication and connection management
- Uses async/await for asynchronous operations
- Implements comprehensive error handling
- Uses system logging for debugging
- Manages connection state through @Published properties

Key Concerns:
- Heavy reliance on UserDefaults for credential storage
- Complex UI automation logic
- Polling-based window detection
- Multiple responsibilities (authentication, UI automation, credential management)

#### FirstLaunchManager (FirstLaunchManager.swift)
```swift:PassPunk/Managers/FirstLaunchManager.swift
startLine: 5
endLine: 40
```
- Handles first-time setup flow
- Manages accessibility permissions
- Handles VPN credential collection
- Uses continuation-based async/await patterns

Areas for Improvement:
- UserDefaults for persistent storage
- Mixed UI and business logic
- Limited error recovery mechanisms
- Synchronous accessibility checks

#### AppDelegate (AppDelegate.swift)
```swift:PassPunk/App/AppDelegate.swift
startLine: 7
endLine: 30
```
- Manages application lifecycle
- Handles status bar integration
- Coordinates periodic checks
- Manages window lifecycle

Technical Debt:
- Direct manager instantiation
- Print statements for error logging
- Manual window management
- Limited error handling in periodic checks

### Architecture Patterns

1. **Singleton Usage**
   - VPNManager.shared
   - FirstLaunchManager.shared
   - StatusBarController.shared
   Potential Issues:
   - Global state management
   - Testing difficulties
   - Tight coupling

2. **Asynchronous Patterns**
   - Extensive use of async/await
   - Continuation-based asynchronous UI
   - Task-based background operations
   Implementation Concerns:
   - Mixed usage of DispatchQueue and async/await
   - Potential race conditions in state management
   - Limited cancellation handling

3. **Error Handling**
   - Custom VPNError enum
   - Try-catch blocks
   - Error logging
   Improvements Needed:
   - More granular error types
   - Better error recovery mechanisms
   - Structured logging

4. **UI Automation**
   - CGEvent-based keyboard input
   - Accessibility API usage
   - Mouse click simulation
   Risks:
   - OS version dependency
   - Fragile UI automation
   - Limited error recovery

### Critical Paths

1. **VPN Authentication Flow**
```swift:PassPunk/Managers/VPNManager.swift
startLine: 91
endLine: 172
```
   - Application launch
   - Window detection
   - Credential input
   - 2FA handling
   - Connection verification

2. **First Launch Setup**
```swift:PassPunk/Managers/FirstLaunchManager.swift
startLine: 24
endLine: 40
```
   - Permission checks
   - Credential collection
   - Initial configuration

3. **Periodic Check Mechanism**
```swift:PassPunk/App/AppDelegate.swift
startLine: 90
endLine: 98
```
   - VPN authentication
   - Password verification
   - Error handling

### Security Considerations

1. **Credential Management**
   - Stored in UserDefaults (security risk)
   - Plain text password handling
   - Limited encryption

2. **Accessibility Permissions**
   - Full system accessibility required
   - Potential security implications
   - Limited scope control

3. **Automation Security**
   - CGEvent injection
   - System-wide accessibility
   - Keyboard event simulation

### Performance Considerations

1. **Resource Usage**
   - Continuous polling for window detection
   - Multiple async tasks
   - UI automation overhead

2. **Memory Management**
   - Window reference handling
   - Task lifecycle management
   - Resource cleanup

3. **Response Time**
   - Sleep delays in automation
   - Window detection latency
   - Authentication timeouts

### Recommendations

1. **Immediate Improvements**
   - Move credentials to Keychain
   - Implement proper logging strategy
   - Add timeout handling
   - Improve error recovery

2. **Architecture Refactoring**
   - Split VPNManager responsibilities
   - Create dedicated UI automation service
   - Implement proper dependency injection
   - Add middleware for error handling

3. **Security Enhancements**
   - Implement secure credential storage
   - Add encryption for sensitive data
   - Improve permission management
   - Add security logging

4. **Performance Optimization**
   - Replace polling with notifications
   - Optimize sleep durations
   - Implement proper resource cleanup
   - Add performance monitoring

## Architettura e Design Patterns

### Gestione della Concorrenza

1. **MainActor e Isolamento**
   - Tutte le classi che gestiscono l'UI o lo stato dell'applicazione sono annotate con `@MainActor`
   - Le classi singleton implementano `@unchecked Sendable` per la sicurezza della concorrenza
   - Le operazioni asincrone sono eseguite in `Task` blocks con isolamento `@MainActor` quando necessario

2. **Gestione del Ciclo di Vita**
   - I timer e le risorse devono essere correttamente invalidati nel `deinit`
   - Le operazioni di cleanup devono essere eseguite nel contesto appropriato (MainActor vs background)
   - Attenzione ai potenziali memory leaks nei cicli di riferimento con timer e closure

3. **Pattern Delegate**
   - Uso di weak references per evitare retain cycles
   - Protocolli delegate sono marcati come `@objc` quando necessario per l'interoperabilità
   - I delegate sono utilizzati per la comunicazione tra componenti mantenendo un basso accoppiamento

4. **Gestione dello Stato**
   - Stato centralizzato attraverso singleton thread-safe
   - Notifiche per comunicare cambiamenti di stato tra componenti
   - Uso di `@Published` per proprietà osservabili in SwiftUI

5. **Error Handling**
   - Errori tipizzati per domini specifici (VPN, Keychain, etc.)
   - Gestione consistente degli errori attraverso `do-catch`
   - Propagazione appropriata degli errori attraverso i livelli dell'applicazione

6. **Separazione delle Responsabilità**
   - Chiara separazione tra UI (Views), logica di business (Managers) e dati (Models)
   - Componenti modulari con interfacce ben definite
   - Evitare dipendenze circolari tra componenti

### Punti di Attenzione

- La gestione dei timer e delle risorse nel `deinit` deve essere rivista per garantire l'esecuzione nel contesto corretto
- Potenziale introduzione di un pattern di state management più strutturato
- Migliorare la gestione delle dipendenze tra componenti
- Considerare l'uso di dependency injection per facilitare i test
- Implementare logging consistente attraverso l'applicazione
- Aggiungere test unitari per la logica di business critica 