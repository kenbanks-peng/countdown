import Foundation

struct CountdownConfiguration {
    let testEnabled: Bool
    let notificationEnabled: Bool
    let notificationAudioEnabled: Bool
    let alarmEnabled: Bool
    let size: Double
    let compactSize: Double
    let greenNotificationURL: URL?
    let yellowNotificationURL: URL?
    let redNotificationURL: URL?
    let alarmNotificationURL: URL?
    static let defaultNotificationFontSizePt: Double = 144
    let notificationFontSizePt: Double
    let notificationFontAlpha: Double
    let notificationFont: String
    let notificationFontVariations: NotificationFontVariations
    static let defaultNotificationFadeTimeSeconds: Double = 1.5
    let notificationFadeTimeSeconds: Double
    let notificationFadeIn: NotificationFadeCurve
    let notificationFadeOut: NotificationFadeCurve
    let notificationTimeSeconds: Double
    let notificationIntervalMinutes: Int
    let pomodoroFocusPeriodsPerCycle: Int
    let pomodoroFocusMinutes: Int
    let pomodoroRestMinutes: Int
    let pomodoroLongRestMinutes: Int

    init(
        alarmNotificationURL: URL?,
        greenNotificationURL: URL? = nil,
        yellowNotificationURL: URL? = nil,
        redNotificationURL: URL? = nil,
        notificationTimeSeconds: Double = 5,
        notificationFadeTimeSeconds: Double = CountdownConfiguration.defaultNotificationFadeTimeSeconds,
        notificationFadeIn: NotificationFadeCurve = .easeIn,
        notificationFadeOut: NotificationFadeCurve = .easeOut,
        notificationFontSizePt: Double = CountdownConfiguration.defaultNotificationFontSizePt,
        notificationFontAlpha: Double = 1,
        notificationFont: String = "",
        notificationFontVariations: NotificationFontVariations = NotificationFontVariations(),
        notificationIntervalMinutes: Int = 15,
        pomodoroFocusMinutes: Int = 25,
        pomodoroRestMinutes: Int = 5,
        pomodoroLongRestMinutes: Int = 20,
        pomodoroFocusPeriodsPerCycle: Int = 4,
        size: Double = 1,
        compactSize: Double = 1,
        notificationEnabled: Bool = true,
        notificationAudioEnabled: Bool = true,
        alarmEnabled: Bool = true,
        testEnabled: Bool = false
    ) {
        self.testEnabled = testEnabled
        self.notificationEnabled = notificationEnabled
        self.notificationAudioEnabled = notificationAudioEnabled
        self.alarmEnabled = alarmEnabled
        self.size = size.isFinite && size > 0 ? size : 1
        self.compactSize = compactSize.isFinite && compactSize > 0 ? compactSize : 1
        self.pomodoroFocusPeriodsPerCycle = PomodoroModel.normalizedFocusPeriodCount(pomodoroFocusPeriodsPerCycle)
        self.greenNotificationURL = greenNotificationURL
        self.yellowNotificationURL = yellowNotificationURL
        self.redNotificationURL = redNotificationURL
        self.alarmNotificationURL = alarmNotificationURL
        self.notificationFontAlpha = notificationFontAlpha.isFinite && (0...1).contains(notificationFontAlpha)
            ? notificationFontAlpha : 1
        self.notificationFont = notificationFont.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notificationFontVariations = notificationFontVariations
        self.notificationFontSizePt = notificationFontSizePt.isFinite && notificationFontSizePt > 0
            ? notificationFontSizePt : Self.defaultNotificationFontSizePt
        self.notificationFadeTimeSeconds = notificationFadeTimeSeconds.isFinite && notificationFadeTimeSeconds >= 0
            ? notificationFadeTimeSeconds : Self.defaultNotificationFadeTimeSeconds
        self.notificationFadeIn = notificationFadeIn
        self.notificationFadeOut = notificationFadeOut
        self.notificationTimeSeconds = notificationTimeSeconds.isFinite && notificationTimeSeconds >= 0
            ? notificationTimeSeconds : 5
        let interval = max(5, notificationIntervalMinutes)
        let roundedDown = interval - interval % 5
        self.notificationIntervalMinutes = interval % 5 >= 3 && roundedDown <= Int.max - 5 ? roundedDown + 5 : roundedDown
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
            notificationTimeSeconds: configurationFile.doubleValue(for: "notification_time_seconds", section: "notifications") ?? 5,
            notificationFadeTimeSeconds: configurationFile.doubleValue(for: "notification_fade_time_seconds", section: "notifications") ?? Self.defaultNotificationFadeTimeSeconds,
            notificationFadeIn: configurationFile.stringValue(for: "notification_fade_in", section: "notifications")
                .flatMap(NotificationFadeCurve.init(rawValue:)) ?? .easeIn,
            notificationFadeOut: configurationFile.stringValue(for: "notification_fade_out", section: "notifications")
                .flatMap(NotificationFadeCurve.init(rawValue:)) ?? .easeOut,
            notificationFontSizePt: configurationFile.doubleValue(for: "notification_font_size_pt", section: "notifications") ?? Self.defaultNotificationFontSizePt,
            notificationFontAlpha: configurationFile.doubleValue(for: "notification_font_alpha", section: "notifications") ?? 1,
            notificationFont: configurationFile.stringValue(for: "notification_font", section: "notifications") ?? "",
            notificationFontVariations: NotificationFontVariations(
                weight: configurationFile.doubleValue(for: "notification_font_weight", section: "notifications"),
                width: configurationFile.doubleValue(for: "notification_font_width", section: "notifications"),
                opticalSize: configurationFile.doubleValue(for: "notification_font_optical_size_pt", section: "notifications"),
                slant: configurationFile.doubleValue(for: "notification_font_slant_degrees", section: "notifications")
            ),
            notificationIntervalMinutes: configurationFile.intValue(for: "notification_interval_minutes", section: "notifications") ?? 15,
            pomodoroFocusMinutes: configurationFile.intValue(for: "focus", section: "pomodoro") ?? 25,
            pomodoroRestMinutes: configurationFile.intValue(for: "rest", section: "pomodoro") ?? 5,
            pomodoroLongRestMinutes: configurationFile.intValue(for: "long-rest", section: "pomodoro") ?? 20,
            pomodoroFocusPeriodsPerCycle: configurationFile.intValue(for: "cycles", section: "pomodoro") ?? 4,
            size: configurationFile.doubleValue(for: "size") ?? 1,
            compactSize: configurationFile.doubleValue(for: "compact_size") ?? 1,
            notificationEnabled: configurationFile.boolValue(for: "notification_enabled") ?? true,
            notificationAudioEnabled: configurationFile.boolValue(for: "notification_audio_enabled") ?? true,
            alarmEnabled: configurationFile.boolValue(for: "alarm_enabled") ?? true,
            testEnabled: configurationFile.boolValue(for: "test", section: "") ?? false
        )
    }

}
