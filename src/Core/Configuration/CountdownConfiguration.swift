import Foundation

struct CountdownConfiguration {
    let testEnabled: Bool
    let alarmMessage: String
    static let defaultSizePx: Double = 220
    static let defaultCompactSizePx: Double = 32
    let sizePx: Double
    let compactSizePx: Double
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
    let notificationHoldTimeSeconds: Double
    let notificationIntervalMinutes: Int
    /// Exact remaining-minute marks, or nil to use the repeating interval.
    let notificationMarksMinutes: [Int]?
    let pomodoroFocusPeriodsPerCycle: Int
    let pomodoroFocusMinutes: Int
    let pomodoroRestMinutes: Int
    let pomodoroLongRestMinutes: Int

    init(
        alarmNotificationURL: URL?,
        notificationHoldTimeSeconds: Double = 5,
        notificationFadeTimeSeconds: Double = CountdownConfiguration.defaultNotificationFadeTimeSeconds,
        notificationFadeIn: NotificationFadeCurve = .easeIn,
        notificationFadeOut: NotificationFadeCurve = .easeOut,
        notificationFontSizePt: Double = CountdownConfiguration.defaultNotificationFontSizePt,
        notificationFontAlpha: Double = 1,
        notificationFont: String = "",
        notificationFontVariations: NotificationFontVariations = NotificationFontVariations(),
        notificationIntervalMinutes: Int = 15,
        notificationMarksMinutes: [Int]? = nil,
        pomodoroFocusMinutes: Int = 25,
        pomodoroRestMinutes: Int = 5,
        pomodoroLongRestMinutes: Int = 20,
        pomodoroFocusPeriodsPerCycle: Int = PomodoroModel.defaultFocusPeriodsPerCycle,
        sizePx: Double = CountdownConfiguration.defaultSizePx,
        compactSizePx: Double = CountdownConfiguration.defaultCompactSizePx,
        alarmMessage: String = "",
        testEnabled: Bool = false
    ) {
        self.testEnabled = testEnabled
        self.alarmMessage = alarmMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sizePx = sizePx.isFinite && sizePx > 0 ? sizePx : Self.defaultSizePx
        self.compactSizePx = compactSizePx.isFinite && compactSizePx > 0 ? compactSizePx : Self.defaultCompactSizePx
        self.pomodoroFocusPeriodsPerCycle = PomodoroModel.normalizedFocusPeriodCount(pomodoroFocusPeriodsPerCycle)
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
        self.notificationHoldTimeSeconds = notificationHoldTimeSeconds.isFinite && notificationHoldTimeSeconds >= 0
            ? notificationHoldTimeSeconds : 5
        self.notificationMarksMinutes = notificationMarksMinutes.flatMap { marks in
            marks.allSatisfy { $0 >= 0 } ? Array(Set(marks)).sorted() : nil
        }
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
        let alarmNotificationURL = configurationFile.soundURL(for: "alarm_audio", defaultName: "alarm.mp3", section: "alarm")
        return CountdownConfiguration(
            alarmNotificationURL: alarmNotificationURL,
            notificationHoldTimeSeconds: configurationFile.doubleValue(for: "notification_hold_time_seconds", section: "notifications") ?? 5,
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
            notificationIntervalMinutes: configurationFile.intValue(for: "notification_marks_minutes", section: "notifications") ?? 15,
            notificationMarksMinutes: configurationFile.intArrayValue(for: "notification_marks_minutes", section: "notifications"),
            pomodoroFocusMinutes: configurationFile.intValue(for: "focus", section: "pomodoro") ?? 25,
            pomodoroRestMinutes: configurationFile.intValue(for: "rest", section: "pomodoro") ?? 5,
            pomodoroLongRestMinutes: configurationFile.intValue(for: "long-rest", section: "pomodoro") ?? 20,
            pomodoroFocusPeriodsPerCycle: configurationFile.intValue(for: "cycles", section: "pomodoro") ?? PomodoroModel.defaultFocusPeriodsPerCycle,
            sizePx: configurationFile.doubleValue(for: "size_px") ?? Self.defaultSizePx,
            compactSizePx: configurationFile.doubleValue(for: "compact_size_px") ?? Self.defaultCompactSizePx,
            alarmMessage: configurationFile.stringValue(for: "alarm_message", section: "alarm") ?? "",
            testEnabled: configurationFile.boolValue(for: "test", section: "") ?? false
        )
    }

}
