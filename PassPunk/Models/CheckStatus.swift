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