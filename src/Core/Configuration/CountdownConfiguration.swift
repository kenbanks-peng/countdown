import Foundation

struct CountdownConfiguration {
    let notificationEnabled: Bool
    let reminderNotificationEnabled: Bool
    let audioNotificationEnabled: Bool
    let alarmEnabled: Bool
    let size: Double
    let compactSize: Double
    let greenNotificationURL: URL?
    let yellowNotificationURL: URL?
    let redNotificationURL: URL?
    let alarmNotificationURL: URL?
    static let defaultReminderFontSizePt: Double = 144
    let reminderFontSizePt: Double
    let reminderTimeSeconds: Int
    let reminderIntervalMinutes: Int
    let pomodoroFocusPeriodsPerCycle: Int
    let pomodoroFocusMinutes: Int
    let pomodoroRestMinutes: Int
    let pomodoroLongRestMinutes: Int

    init(
        alarmNotificationURL: URL?,
        greenNotificationURL: URL? = nil,
        yellowNotificationURL: URL? = nil,
        redNotificationURL: URL? = nil,
        reminderTimeSeconds: Int = 5,
        reminderFontSizePt: Double = CountdownConfiguration.defaultReminderFontSizePt,
        reminderIntervalMinutes: Int = 15,
        pomodoroFocusMinutes: Int = 25,
        pomodoroRestMinutes: Int = 5,
        pomodoroLongRestMinutes: Int = 20,
        pomodoroFocusPeriodsPerCycle: Int = 4,
        size: Double = 1,
        compactSize: Double = 1,
        notificationEnabled: Bool = true,
        reminderNotificationEnabled: Bool = true,
        audioNotificationEnabled: Bool = true,
        alarmEnabled: Bool = true
    ) {
        self.notificationEnabled = notificationEnabled
        self.reminderNotificationEnabled = reminderNotificationEnabled
        self.audioNotificationEnabled = audioNotificationEnabled
        self.alarmEnabled = alarmEnabled
        self.size = size.isFinite && size > 0 ? size : 1
        self.compactSize = compactSize.isFinite && compactSize > 0 ? compactSize : 1
        self.pomodoroFocusPeriodsPerCycle = PomodoroModel.normalizedFocusPeriodCount(pomodoroFocusPeriodsPerCycle)
        self.greenNotificationURL = greenNotificationURL
        self.yellowNotificationURL = yellowNotificationURL
        self.redNotificationURL = redNotificationURL
        self.alarmNotificationURL = alarmNotificationURL
        self.reminderFontSizePt = reminderFontSizePt.isFinite && reminderFontSizePt > 0
            ? reminderFontSizePt : Self.defaultReminderFontSizePt
        self.reminderTimeSeconds = reminderTimeSeconds > 0 ? reminderTimeSeconds : 5
        let interval = max(5, reminderIntervalMinutes)
        let roundedDown = interval - interval % 5
        self.reminderIntervalMinutes = interval % 5 >= 3 && roundedDown <= Int.max - 5 ? roundedDown + 5 : roundedDown
        let focus = (1...59).contains(pomodoroFocusMinutes) ? pomodoroFocusMinutes : 25
        let rest = (1...59).contains(pomodoroRestMinutes) ? pomodoroRestMinutes : 5
        let longRest = (1...60).contains(pomodoroLongRestMinutes) ? pomodoroLongRestMinutes : 20
        let valid = focus + rest <= 60
        self.pomodoroFocusMinutes = valid ? focus : 25
        self.pomodoroRestMinutes = valid ? rest : 5
        self.pomodoroLongRestMinutes = valid ? longRest : 20
    }

    static let `default` = load()

    static func load(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CountdownConfiguration {
        let configurationFile = CountdownConfigurationFile(fileManager: fileManager, environment: environment)
        let alarmNotificationURL = configurationFile.soundURL(for: "alarm_audio", defaultName: "alarm.mp3")
        return CountdownConfiguration(
            alarmNotificationURL: alarmNotificationURL,
            greenNotificationURL: configurationFile.soundURL(for: "green_audio", defaultName: "green.mp3"),
            yellowNotificationURL: configurationFile.soundURL(for: "yellow_audio", defaultName: "yellow.mp3"),
            redNotificationURL: configurationFile.soundURL(for: "red_audio", defaultName: "red.mp3"),
            reminderTimeSeconds: configurationFile.intValue(for: "notification_time_in_seconds", section: "notifications") ?? 5,
            reminderFontSizePt: configurationFile.doubleValue(for: "reminder_font_size_pt", section: "notifications") ?? Self.defaultReminderFontSizePt,
            reminderIntervalMinutes: configurationFile.intValue(for: "notification_interval_in_minutes", section: "notifications") ?? 15,
            pomodoroFocusMinutes: configurationFile.intValue(for: "focus", section: "pomodoro") ?? 25,
            pomodoroRestMinutes: configurationFile.intValue(for: "rest", section: "pomodoro") ?? 5,
            pomodoroLongRestMinutes: configurationFile.intValue(for: "long-rest", section: "pomodoro") ?? 20,
            pomodoroFocusPeriodsPerCycle: configurationFile.intValue(for: "cycles", section: "pomodoro") ?? 4,
            size: configurationFile.doubleValue(for: "size") ?? 1,
            compactSize: configurationFile.doubleValue(for: "compact_size") ?? 1,
            notificationEnabled: configurationFile.boolValue(for: "notification_enabled") ?? true,
            reminderNotificationEnabled: configurationFile.boolValue(for: "reminder_notification_enabled") ?? true,
            audioNotificationEnabled: configurationFile.boolValue(for: "audio_notification_enabled") ?? true,
            alarmEnabled: configurationFile.boolValue(for: "alarm_enabled") ?? true
        )
    }

}
