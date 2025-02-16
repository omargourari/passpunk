import Foundation

enum LaunchAgentError: Error {
    case homeDirectoryNotFound
    case launchAgentsFolderNotFound
    case failedToCreateLaunchAgentsFolder
    case failedToCopyLaunchAgent
    case failedToRemoveLaunchAgent
}

class LaunchAgentManager {
    static let shared = LaunchAgentManager()
    
    private let launchAgentFileName = "com.passpunk.launcher.plist"
    private var launchAgentURL: URL? {
        guard let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path as String? else {
            return nil
        }
        return URL(fileURLWithPath: "\(homeDirectory)/Library/LaunchAgents/\(launchAgentFileName)")
    }
    
    private init() {}
    
    func installLaunchAgent() throws {
        guard let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path as String? else {
            throw LaunchAgentError.homeDirectoryNotFound
        }
        
        let launchAgentsPath = "\(homeDirectory)/Library/LaunchAgents"
        let fileManager = FileManager.default
        
        // Crea la cartella LaunchAgents se non esiste
        if !fileManager.fileExists(atPath: launchAgentsPath) {
            do {
                try fileManager.createDirectory(atPath: launchAgentsPath, withIntermediateDirectories: true)
            } catch {
                throw LaunchAgentError.failedToCreateLaunchAgentsFolder
            }
        }
        
        guard let launchAgentDestination = launchAgentURL else {
            throw LaunchAgentError.launchAgentsFolderNotFound
        }
        
        // Ottieni il percorso del file plist all'interno del bundle dell'applicazione
        guard let bundlePath = Bundle.main.path(forResource: "com.passpunk.launcher", ofType: "plist") else {
            throw LaunchAgentError.failedToCopyLaunchAgent
        }
        
        do {
            // Se esiste già un vecchio launch agent, rimuovilo
            if fileManager.fileExists(atPath: launchAgentDestination.path) {
                try fileManager.removeItem(at: launchAgentDestination)
            }
            
            // Copia il nuovo launch agent
            try fileManager.copyItem(atPath: bundlePath, toPath: launchAgentDestination.path)
            
            // Carica il launch agent
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["load", launchAgentDestination.path]
            try process.run()
            process.waitUntilExit()
            
        } catch {
            throw LaunchAgentError.failedToCopyLaunchAgent
        }
    }
    
    func uninstallLaunchAgent() throws {
        guard let launchAgentPath = launchAgentURL else {
            throw LaunchAgentError.launchAgentsFolderNotFound
        }
        
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: launchAgentPath.path) {
            do {
                // Scarica il launch agent
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                process.arguments = ["unload", launchAgentPath.path]
                try process.run()
                process.waitUntilExit()
                
                // Rimuovi il file
                try fileManager.removeItem(at: launchAgentPath)
            } catch {
                throw LaunchAgentError.failedToRemoveLaunchAgent
            }
        }
    }
    
    func isLaunchAgentInstalled() -> Bool {
        guard let launchAgentPath = launchAgentURL?.path else {
            return false
        }
        return FileManager.default.fileExists(atPath: launchAgentPath)
    }
}
