import Foundation

/// Stores the selected Countdown mode and configured Pomodoro durations, not activity.
struct CountdownSettings: Codable {
    var mode: CountdownMode = .timer
    var focusDuration: TimeInterval = 25 * 60
    var breakDuration: TimeInterval = 5 * 60
}

/// Stores app settings separately from the Timer mode session.
struct CountdownSettingsStore {
    let fileManager: FileManager
    let stateDirectory: URL

    func load() -> CountdownSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(CountdownSettings.self, from: data),
              settings.focusDuration.isFinite, settings.breakDuration.isFinite,
              settings.focusDuration >= 60, settings.breakDuration >= 60,
              settings.focusDuration + settings.breakDuration <= 3_600
        else { return CountdownSettings() }
        return settings
    }

    func save(_ settings: CountdownSettings) {
        do {
            try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            // In-memory use continues; a failed write does not promise persistence.
        }
    }

    private var settingsURL: URL {
        stateDirectory.appendingPathComponent("settings.json", isDirectory: false)
    }
}
