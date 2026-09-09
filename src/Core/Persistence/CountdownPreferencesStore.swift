import Foundation

/// Persistent menu choices, separate from user configuration and timer progress.
struct CountdownPreferences {
    var showsRemainingMinutes = true
    var autoRepeatEnabled = false
    var notificationEnabled = true
    var alarmEnabled = true
}

struct CountdownPreferencesStore {
    var fileManager: FileManager = .default
    var stateDirectory: URL = CountdownStateDirectory.resolve()

    func load() -> CountdownPreferences {
        let values = readValues()
        return CountdownPreferences(
            showsRemainingMinutes: values["current_timeout_enabled"] ?? true,
            autoRepeatEnabled: values["auto_repeat_enabled"] ?? false,
            notificationEnabled: values["notification_enabled"] ?? true,
            alarmEnabled: values["alarm_enabled"] ?? true
        )
    }

    func saveEnablement(_ key: String, enabled: Bool) {
        var values = readValues()
        values[key] = enabled
        preferencesFile.save(values)
    }

    private var preferencesFile: JSONStateFile<[String: Bool]> {
        JSONStateFile(fileManager: fileManager, directory: stateDirectory, name: "features.json")
    }

    private func readValues() -> [String: Bool] {
        preferencesFile.load() ?? [:]
    }
}
