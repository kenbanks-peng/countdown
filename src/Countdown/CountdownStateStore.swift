import Foundation

struct CountdownSession: Codable {
    enum Status: String, Codable { case active, prepared }

    let status: Status
    let duration: TimeInterval
    let remaining: TimeInterval
    let endDate: Date?
    let savedAt: Date
}

/// Stores the countdown session independently from the countdown lifecycle.
struct CountdownStateStore {
    static let `default` = CountdownStateStore()

    private let fileManager: FileManager
    private let stateDirectory: URL

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        if let stateHome = environment["XDG_STATE_HOME"], !stateHome.isEmpty {
            stateDirectory = URL(fileURLWithPath: stateHome, isDirectory: true)
                .appendingPathComponent("countdown", isDirectory: true)
        } else {
            stateDirectory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/state/countdown", isDirectory: true)
        }
    }

    func load() -> CountdownSession? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? JSONDecoder().decode(CountdownSession.self, from: data)
    }

    func save(_ session: CountdownSession) {
        do {
            try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL, options: .atomic)
        } catch {
            // A countdown can continue when the state file is not writable.
        }
    }

    func remove() {
        try? fileManager.removeItem(at: sessionURL)
    }

    private var sessionURL: URL {
        stateDirectory.appendingPathComponent("session.json", isDirectory: false)
    }
}
