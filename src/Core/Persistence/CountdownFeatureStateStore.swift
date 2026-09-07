import Foundation

/// Persistent menu choices, separate from user configuration and timer progress.
struct CountdownFeatureState {
    var clockEnabled = true
    var currentTimeoutEnabled = true
    var autosetEnabled = false
    var reminderEnabled = true
    var alarmEnabled = true
}

struct CountdownFeatureStateStore {
    var fileManager: FileManager = .default
    var stateDirectory: URL = CountdownStateDirectory.resolve()

    func load() -> CountdownFeatureState {
        let values = readValues()
        return CountdownFeatureState(
            clockEnabled: values["clock_enabled"] ?? true,
            currentTimeoutEnabled: values["current_timeout_enabled"] ?? true,
            autosetEnabled: values["autoset_enabled"] ?? false,
            reminderEnabled: values["reminder_enabled"] ?? true,
            alarmEnabled: values["alarm_enabled"] ?? true
        )
    }

    func saveEnablement(_ key: String, enabled: Bool) {
        var values = readValues()
        values[key] = enabled
        do {
            try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(values)
            try data.write(to: url, options: .atomic)
        } catch {
            // The choice remains active in memory if the state file is not writable.
        }
    }

    private var url: URL {
        stateDirectory.appendingPathComponent("features.json", isDirectory: false)
    }

    private func readValues() -> [String: Bool] {
        guard let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: Bool].self, from: data)
        else { return [:] }
        return values
    }
}
