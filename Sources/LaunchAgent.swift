import Foundation

enum LaunchAgentDomain: String, CaseIterable, Codable {
    case user = "User"
    case local = "Local"
    case system = "System"

    var launchctlDomain: String {
        switch self {
        case .user:
            return "gui/\(LaunchAgentPaths.currentUserID)"
        case .local:
            return "gui/\(LaunchAgentPaths.currentUserID)"
        case .system:
            return "system"
        }
    }

    var searchPath: String {
        switch self {
        case .user:
            return LaunchAgentPaths.userAgents
        case .local:
            return LaunchAgentPaths.localAgents
        case .system:
            return LaunchAgentPaths.systemAgents
        }
    }

    var displayPath: String {
        searchPath
    }
}

enum LaunchAgentLoadedState: String {
    case loaded = "Loaded"
    case unloaded = "Unloaded"
    case unknown = "Unknown"
}

struct LaunchAgent: Identifiable, Hashable {
    let id: String
    let label: String
    let plistPath: String
    let domain: LaunchAgentDomain
    let program: String?
    let watchPaths: [String]
    let runAtLoad: Bool
    let keepAlive: Bool
    let loadedState: LaunchAgentLoadedState
    let plistSource: String
    let rawPlist: String

    var fileName: String {
        URL(fileURLWithPath: plistPath).lastPathComponent
    }
}

enum LaunchAgentAction: String {
    case start = "Start"
    case stop = "Stop"
    case restart = "Restart"
}

enum LaunchAgentError: LocalizedError {
    case commandFailed(String)
    case invalidPlist(String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            return message
        case .invalidPlist(let path):
            return "Unable to read plist at \(path)."
        }
    }
}

enum LaunchAgentPaths {
    static let userAgents = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
    static let localAgents = "/Library/LaunchAgents"
    static let systemAgents = "/System/Library/LaunchAgents"
    static let currentUserID = String(getuid())
}
