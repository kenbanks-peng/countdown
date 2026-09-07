import Foundation

struct CountdownConfiguration {
    let greenNotificationURL: URL?
    let yellowNotificationURL: URL?
    let redNotificationURL: URL?
    let alarmNotificationURL: URL?
    let clockEnabled: Bool
    let currentTimeoutEnabled: Bool
    let autosetEnabled: Bool
    let reminderEnabled: Bool
    let reminderTime: Int
    let alarmEnabled: Bool
    let pomodoroFocusMinutes: Int
    let pomodoroRestMinutes: Int
    let pomodoroLongRestMinutes: Int

    init(
        alarmNotificationURL: URL?,
        greenNotificationURL: URL? = nil,
        yellowNotificationURL: URL? = nil,
        redNotificationURL: URL? = nil,
        clockEnabled: Bool = true,
        currentTimeoutEnabled: Bool = true,
        autosetEnabled: Bool = false,
        reminderEnabled: Bool = true,
        reminderTime: Int = 5,
        alarmEnabled: Bool = true,
        pomodoroFocusMinutes: Int = 25,
        pomodoroRestMinutes: Int = 5,
        pomodoroLongRestMinutes: Int = 15
    ) {
        self.greenNotificationURL = greenNotificationURL
        self.yellowNotificationURL = yellowNotificationURL
        self.redNotificationURL = redNotificationURL
        self.alarmNotificationURL = alarmNotificationURL
        self.clockEnabled = clockEnabled
        self.currentTimeoutEnabled = currentTimeoutEnabled
        self.autosetEnabled = autosetEnabled
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime > 0 && reminderTime.isMultiple(of: 5) ? reminderTime : 5
        self.alarmEnabled = alarmEnabled
        let focus = (1...59).contains(pomodoroFocusMinutes) ? pomodoroFocusMinutes : 25
        let rest = (1...59).contains(pomodoroRestMinutes) ? pomodoroRestMinutes : 5
        let longRest = (1...59).contains(pomodoroLongRestMinutes) ? pomodoroLongRestMinutes : 15
        let valid = focus + max(rest, longRest) <= 60
        self.pomodoroFocusMinutes = valid ? focus : 25
        self.pomodoroRestMinutes = valid ? rest : 5
        self.pomodoroLongRestMinutes = valid ? longRest : 15
    }

    static let `default` = load()

    static func saveEnablement(_ key: String, enabled: Bool) {
        let configurationFile = CountdownConfigurationFile.default
        var lines = configurationFile.lines()
        let section = section(forEnablementKey: key)
        configurationFile.replaceOrInsert(key: key, value: String(enabled), in: section, lines: &lines)
        configurationFile.write(lines)
    }

    static func load(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CountdownConfiguration {
        let configurationFile = CountdownConfigurationFile(fileManager: fileManager, environment: environment)
        guard let contents = configurationFile.contents() else {
            return CountdownConfiguration(alarmNotificationURL: nil)
        }

        let alarmNotificationURL = configurationFile.soundURL(for: "alarm_notification", in: contents)
        return CountdownConfiguration(
            alarmNotificationURL: alarmNotificationURL,
            greenNotificationURL: configurationFile.soundURL(for: "green_notification", in: contents) ?? alarmNotificationURL,
            yellowNotificationURL: configurationFile.soundURL(for: "yellow_notification", in: contents) ?? alarmNotificationURL,
            redNotificationURL: configurationFile.soundURL(for: "red_notification", in: contents) ?? alarmNotificationURL,
            clockEnabled: configurationFile.boolValue(for: "clock_enabled", in: contents) ?? true,
            currentTimeoutEnabled: configurationFile.boolValue(for: "current_timeout_enabled", in: contents) ?? true,
            autosetEnabled: configurationFile.boolValue(for: "autoset_enabled", in: contents) ?? false,
            reminderEnabled: configurationFile.boolValue(for: "reminder_enabled", in: contents) ?? true,
            reminderTime: configurationFile.intValue(for: "reminder_time", in: contents) ?? 5,
            alarmEnabled: configurationFile.boolValue(for: "alarm_enabled", in: contents) ?? true,
            pomodoroFocusMinutes: configurationFile.intValue(for: "focus", in: contents, section: "pomodoro") ?? 25,
            pomodoroRestMinutes: configurationFile.intValue(for: "rest", in: contents, section: "pomodoro") ?? 5,
            pomodoroLongRestMinutes: configurationFile.intValue(for: "long-rest", in: contents, section: "pomodoro") ?? 15
        )
    }

    private static func section(forEnablementKey key: String) -> String {
        key.hasPrefix("clock_") || key == "current_timeout_enabled" || key == "autoset_enabled"
            ? "display"
            : "notifications"
    }
}

/// Reads and updates the supported fields in the user configuration file.
private struct CountdownConfigurationFile {
    static let `default` = CountdownConfigurationFile()

    private let url: URL

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let directory: URL
        if let configHome = environment["XDG_CONFIG_HOME"], !configHome.isEmpty {
            directory = URL(fileURLWithPath: configHome, isDirectory: true)
        } else {
            directory = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        url = directory
            .appendingPathComponent("countdown", isDirectory: true)
            .appendingPathComponent("config.toml", isDirectory: false)
    }

    func contents() -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    func lines() -> [String] {
        contents()?
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init) ?? []
    }

    func write(_ lines: [String]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            // The setting stays active until the next launch when the file is not writable.
        }
    }

    func replaceOrInsert(key: String, value: String, in section: String, lines: inout [String]) {
        guard let sectionIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "[\(section)]" }) else {
            if !lines.isEmpty, !lines.last!.isEmpty {
                lines.append("")
            }
            lines.append("[\(section)]")
            lines.append("\(key) = \(value)")
            return
        }

        let nextSectionIndex = lines[(sectionIndex + 1)...].firstIndex { line in
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            return trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]")
        } ?? lines.endIndex
        if let keyIndex = lines[sectionIndex + 1..<nextSectionIndex].firstIndex(where: { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("\(key) =")
        }) {
            lines[keyIndex] = "\(key) = \(value)"
        } else {
            lines.insert("\(key) = \(value)", at: nextSectionIndex)
        }
    }

    func soundURL(for key: String, in contents: String) -> URL? {
        guard let soundPath = stringValue(for: key, in: contents) else { return nil }
        return URL(fileURLWithPath: soundPath, relativeTo: url.deletingLastPathComponent())
    }

    func boolValue(for key: String, in contents: String) -> Bool? {
        guard let value = value(for: key, in: contents) else { return nil }
        switch value.lowercased() {
        case "true": return true
        case "false": return false
        default: return nil
        }
    }

    func intValue(for key: String, in contents: String, section: String? = nil) -> Int? {
        guard let value = value(for: key, in: contents, section: section) else { return nil }
        return Int(value.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? "")
    }

    private func stringValue(for key: String, in contents: String) -> String? {
        guard let value = value(for: key, in: contents),
              value.count >= 2, value.first == "\"", value.last == "\""
        else { return nil }
        return String(value.dropFirst().dropLast())
    }

    private func value(for key: String, in contents: String, section: String? = nil) -> String? {
        var currentSection = ""
        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let header = trimmedLine.split(separator: "#", maxSplits: 1).first?.trimmingCharacters(in: .whitespaces) ?? ""
            if header.hasPrefix("["), header.hasSuffix("]") {
                currentSection = String(header.dropFirst().dropLast())
                continue
            }
            if let section, section != currentSection { continue }
            guard !trimmedLine.hasPrefix("#"),
                  let equalsIndex = trimmedLine.firstIndex(of: "=")
            else { continue }

            let candidateKey = trimmedLine[..<equalsIndex].trimmingCharacters(in: .whitespaces)
            guard candidateKey == key else { continue }
            return String(trimmedLine[trimmedLine.index(after: equalsIndex)...]
                .trimmingCharacters(in: .whitespaces))
        }
        return nil
    }
}
