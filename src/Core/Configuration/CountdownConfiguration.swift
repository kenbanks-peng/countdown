import Foundation

struct CountdownConfiguration {
    let greenNotificationURL: URL?
    let yellowNotificationURL: URL?
    let redNotificationURL: URL?
    let alarmNotificationURL: URL?
    let popupTime: Int
    let pomodoroCycles: Int
    let pomodoroFocusMinutes: Int
    let pomodoroRestMinutes: Int
    let pomodoroLongRestMinutes: Int

    init(
        alarmNotificationURL: URL?,
        greenNotificationURL: URL? = nil,
        yellowNotificationURL: URL? = nil,
        redNotificationURL: URL? = nil,
        popupTime: Int = 5,
        pomodoroFocusMinutes: Int = 25,
        pomodoroRestMinutes: Int = 5,
        pomodoroLongRestMinutes: Int = 15,
        pomodoroCycles: Int = 4
    ) {
        self.pomodoroCycles = PomodoroModel.validCycles(pomodoroCycles)
        self.greenNotificationURL = greenNotificationURL
        self.yellowNotificationURL = yellowNotificationURL
        self.redNotificationURL = redNotificationURL
        self.alarmNotificationURL = alarmNotificationURL
        self.popupTime = popupTime > 0 && popupTime.isMultiple(of: 5) ? popupTime : 5
        let focus = (1...59).contains(pomodoroFocusMinutes) ? pomodoroFocusMinutes : 25
        let rest = (1...59).contains(pomodoroRestMinutes) ? pomodoroRestMinutes : 5
        let longRest = (1...60).contains(pomodoroLongRestMinutes) ? pomodoroLongRestMinutes : 15
        let valid = focus + rest <= 60
        self.pomodoroFocusMinutes = valid ? focus : 25
        self.pomodoroRestMinutes = valid ? rest : 5
        self.pomodoroLongRestMinutes = valid ? longRest : 15
    }

    static let `default` = load()

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
            popupTime: configurationFile.intValue(for: "popup_time", in: contents) ?? 5,
            pomodoroFocusMinutes: configurationFile.intValue(for: "focus", in: contents, section: "pomodoro") ?? 25,
            pomodoroRestMinutes: configurationFile.intValue(for: "rest", in: contents, section: "pomodoro") ?? 5,
            pomodoroLongRestMinutes: configurationFile.intValue(for: "long-rest", in: contents, section: "pomodoro") ?? 15,
            pomodoroCycles: configurationFile.intValue(for: "cycles", in: contents, section: "pomodoro") ?? 4
        )
    }

}

/// Reads the supported fields in the user configuration file.
private struct CountdownConfigurationFile {
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

    func soundURL(for key: String, in contents: String) -> URL? {
        guard let soundPath = stringValue(for: key, in: contents) else { return nil }
        return URL(fileURLWithPath: soundPath, relativeTo: url.deletingLastPathComponent())
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
