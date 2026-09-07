import Foundation

/// Resolves the state directory used by Countdown and its modes.
enum CountdownStateDirectory {
    static func resolve(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let stateHome = environment["XDG_STATE_HOME"], !stateHome.isEmpty {
            return URL(fileURLWithPath: stateHome, isDirectory: true)
                .appendingPathComponent("countdown", isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/state/countdown", isDirectory: true)
    }
}
