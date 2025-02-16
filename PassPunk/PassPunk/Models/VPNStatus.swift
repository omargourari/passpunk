import SwiftUI

enum VPNStatus {
    case connected
    case disconnected
    case connecting
    
    var description: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        }
    }
    
    var color: Color {
        switch self {
        case .connected: return .green
        case .disconnected: return .red
        case .connecting: return .orange
        }
    }
} 
