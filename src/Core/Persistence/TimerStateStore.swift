import Foundation

struct TimerSession: Codable {
    enum Status: String, Codable { case active, prepared }

    let status: Status
    let duration: TimeInterval
    let remaining: TimeInterval
    let endDate: Date?
    let savedAt: Date
    var pausedAt: Date? = nil
}

/// Stores only the Timer mode session.
struct TimerStateStore {
    static let `default` = TimerStateStore()

    let fileManager: FileManager
    let stateDirectory: URL

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        stateDirectory = CountdownStateDirectory.resolve(fileManager: fileManager, environment: environment)
    }

    func load() -> TimerSession? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? JSONDecoder().decode(TimerSession.self, from: data)
    }

    func save(_ session: TimerSession) {
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
