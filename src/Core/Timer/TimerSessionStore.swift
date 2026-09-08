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
struct TimerSessionStore {
    static let `default` = TimerSessionStore()

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
        sessionFile.load()
    }

    func save(_ session: TimerSession) {
        sessionFile.save(session)
    }

    func remove() {
        sessionFile.remove()
    }

    private var sessionFile: JSONStateFile<TimerSession> {
        JSONStateFile(fileManager: fileManager, directory: stateDirectory, name: "session.json")
    }
}
