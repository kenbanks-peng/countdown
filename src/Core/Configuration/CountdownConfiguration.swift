import Foundation

struct CountdownConfiguration {
    let size: Double
    let compactSize: Double
    let greenNotificationURL: URL?
    let yellowNotificationURL: URL?
    let redNotificationURL: URL?
    let alarmNotificationURL: URL?
    let popupIntervalMinutes: Int
    let pomodoroFocusPeriodsPerCycle: Int
    let pomodoroFocusMinutes: Int
    let pomodoroRestMinutes: Int
    let pomodoroLongRestMinutes: Int

    init(
        alarmNotificationURL: URL?,
        greenNotificationURL: URL? = nil,
        yellowNotificationURL: URL? = nil,
        redNotificationURL: URL? = nil,
        popupIntervalMinutes: Int = 5,
        pomodoroFocusMinutes: Int = 25,
        pomodoroRestMinutes: Int = 5,
        pomodoroLongRestMinutes: Int = 15,
        pomodoroFocusPeriodsPerCycle: Int = 4,
        size: Double = 1,
        compactSize: Double = 1
    ) {
        self.size = size.isFinite && size > 0 ? size : 1
        self.compactSize = compactSize.isFinite && compactSize > 0 ? compactSize : 1
        self.pomodoroFocusPeriodsPerCycle = PomodoroModel.normalizedFocusPeriodCount(pomodoroFocusPeriodsPerCycle)
        self.greenNotificationURL = greenNotificationURL
        self.yellowNotificationURL = yellowNotificationURL
        self.redNotificationURL = redNotificationURL
        self.alarmNotificationURL = alarmNotificationURL
        self.popupIntervalMinutes = popupIntervalMinutes > 0 && popupIntervalMinutes.isMultiple(of: 5) ? popupIntervalMinutes : 5
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
        guard let configurationFile = CountdownConfigurationFile(fileManager: fileManager, environment: environment) else {
            return CountdownConfiguration(alarmNotificationURL: nil)
        }

        let alarmNotificationURL = configurationFile.soundURL(for: "alarm_notification")
        return CountdownConfiguration(
            alarmNotificationURL: alarmNotificationURL,
            greenNotificationURL: configurationFile.soundURL(for: "green_notification") ?? alarmNotificationURL,
            yellowNotificationURL: configurationFile.soundURL(for: "yellow_notification") ?? alarmNotificationURL,
            redNotificationURL: configurationFile.soundURL(for: "red_notification") ?? alarmNotificationURL,
            popupIntervalMinutes: configurationFile.intValue(for: "popup_time") ?? 5,
            pomodoroFocusMinutes: configurationFile.intValue(for: "focus", section: "pomodoro") ?? 25,
            pomodoroRestMinutes: configurationFile.intValue(for: "rest", section: "pomodoro") ?? 5,
            pomodoroLongRestMinutes: configurationFile.intValue(for: "long-rest", section: "pomodoro") ?? 15,
            pomodoroFocusPeriodsPerCycle: configurationFile.intValue(for: "cycles", section: "pomodoro") ?? 4,
            size: configurationFile.doubleValue(for: "size") ?? 1,
            compactSize: configurationFile.doubleValue(for: "compact_size") ?? 1
        )
    }

}
