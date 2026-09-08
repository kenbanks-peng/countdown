import Foundation

/// Stores the selected mode and the fixed Pomodoro schedule.
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
        guard var settings = settingsFile.load(),
              settings.focusDuration.isFinite, settings.restDuration.isFinite,
              settings.focusDuration >= 60, settings.restDuration >= 60,
              settings.focusDuration + settings.restDuration <= 3_600
        else { return defaults }
        let longRest = settings.longRestDuration ?? defaults.longRestDuration ?? 1_200
        guard longRest.isFinite, longRest >= 60,
              longRest <= 3_600 else { return defaults }
        settings.longRestDuration = longRest
        return settings
    }

    func save(_ settings: CountdownSettings) {
        settingsFile.save(settings)
    }

    private var settingsFile: JSONStateFile<CountdownSettings> {
        JSONStateFile(fileManager: fileManager, directory: stateDirectory, name: "settings.json")
    }
}
