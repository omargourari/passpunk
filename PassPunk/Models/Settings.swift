import Foundation

struct Settings: Codable {
    var vpnUsername: String
    var browserType: BrowserType
    var checkInterval: TimeInterval
    var defaultPasswordComment: String
    
    enum BrowserType: String, Codable {
        case chrome
        case safari
        case firefox
    }
    
    static let shared = Settings(
        vpnUsername: "",
        browserType: .chrome,
        checkInterval: 1800,
        defaultPasswordComment: "Routine password check"
    )
    
    init(vpnUsername: String = "",
         browserType: BrowserType = .chrome,
         checkInterval: TimeInterval = 1800,
         defaultPasswordComment: String = "Routine password check") {
        self.vpnUsername = vpnUsername
        self.browserType = browserType
        self.checkInterval = checkInterval
        self.defaultPasswordComment = defaultPasswordComment
    }
}
