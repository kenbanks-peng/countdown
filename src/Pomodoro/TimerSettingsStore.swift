import Foundation

/// Only timer selection and configured allocations cross a Pomodoro restart.
struct TimerSettings: Codable {
    var mode: TimerMode = .countdown
    var focusDuration: TimeInterval = 25 * 60
    var breakDuration: TimeInterval = 5 * 60
}

/// Uses its own file, never the Countdown session record.
struct TimerSettingsStore {
    let fileManager: FileManager
    let stateDirectory: URL

    func load() -> TimerSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(TimerSettings.self, from: data),
              settings.focusDuration.isFinite, settings.breakDuration.isFinite,
              settings.focusDuration >= 60, settings.breakDuration >= 60,
              settings.focusDuration + settings.breakDuration <= 3_600
        else { return TimerSettings() }
        return settings
    }

    func save(_ settings: TimerSettings) {
        do {
            try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            // In-memory use continues; a failed write does not promise persistence.
        }
    }

    private var settingsURL: URL {
        stateDirectory.appendingPathComponent("timer-settings.json", isDirectory: false)
    }
}
