import Foundation

/// Duration mode stores allocations. Clock mode also stores its fixed schedule.
struct CountdownSettings: Codable {
    var mode: CountdownMode = .timer
    var focusDuration: TimeInterval = 25 * 60
    var restDuration: TimeInterval = 5 * 60
    var isPaused: Bool?
    var longRestDuration: TimeInterval?
    var pomodoroClockSchedule: PomodoroClockSchedule?
}

/// Stores app settings separately from the Timer mode session.
struct CountdownSettingsStore {
    let fileManager: FileManager
    let stateDirectory: URL

    func load(defaults: CountdownSettings = CountdownSettings()) -> CountdownSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              var settings = try? JSONDecoder().decode(CountdownSettings.self, from: data),
              settings.focusDuration.isFinite, settings.restDuration.isFinite,
              settings.focusDuration >= 60, settings.restDuration >= 60,
              settings.focusDuration + settings.restDuration <= 3_600
        else { return defaults }
        let longRest = settings.longRestDuration ?? defaults.longRestDuration ?? 900
        guard longRest.isFinite, longRest >= 60,
              settings.focusDuration + longRest <= 3_600 else { return defaults }
        settings.longRestDuration = longRest
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
