import Foundation
import Testing
@testable import Countdown

struct NotificationConfigurationTests {
    @Test
    func notificationFontDefaultsToSystem() throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil).notificationFont.isEmpty)
        #expect(try load("").notificationFont.isEmpty)
        #expect(try load("[pomodoro]\nnotification_font = \"Impact\"").notificationFont.isEmpty)
    }

    @Test
    func notificationFontUsesNotificationSection() throws {
        let config = try load("""
        notification_font = "Arial"
        [notifications]
        notification_font = " Impact " # Installed font
        notification_font = "Arial"
        [pomodoro]
        notification_font = "Arial"
        """)
        #expect(config.notificationFont == "Impact")
    }

    @Test(arguments: ["", "Impact", "123", "\"Impact", "\"Impact\" invalid", "\"\"", "\"   \""])
    func invalidOrEmptyFontUsesSystem(value: String) throws {
        #expect(try load("[notifications]\nnotification_font = \(value)").notificationFont.isEmpty)
    }

    @Test
    func defaultFontIs144Points() throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil).notificationFontSizePt == 144)
        #expect(try load("").notificationFontSizePt == 144)
    }

    @Test(arguments: ["", "invalid", "0", "-1", "nan", "inf", "1e999", "\"180\""])
    func invalidFontSizeUsesDefault(value: String) throws {
        #expect(try load("[notifications]\nnotification_font_size_pt = \(value)").notificationFontSizePt == 144)
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity])
    func initializerRejectsInvalidFontSize(value: Double) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationFontSizePt: value).notificationFontSizePt == 144)
    }

    @Test
    func fontSizeUsesNotificationSectionAndIsIndependentOfWindowScales() throws {
        let config = try load("""
        size = 2
        compact_size = 0.5
        notification_font_size_pt = 90
        [notifications]
        notification_enabled = false
        notification_font_size_pt = 180.5 # Points
        [pomodoro]
        notification_font_size_pt = 12
        """)
        #expect(config.notificationFontSizePt == 180.5)
        #expect(!config.notificationEnabled)
        #expect(config.size == 2)
        #expect(config.compactSize == 0.5)
        #expect(try load("[pomodoro]\nnotification_font_size_pt = 12").notificationFontSizePt == 144)
    }

    @Test
    func fontAlphaDefaultsToOpaque() throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil).notificationFontAlpha == 1)
        #expect(try load("").notificationFontAlpha == 1)
        #expect(try load("[pomodoro]\nnotification_font_alpha = 0.5").notificationFontAlpha == 1)
    }

    @Test(arguments: [0.0, 0.1, 0.5, 1.0])
    func fontAlphaUsesFirstValueInNotificationSection(value: Double) throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationFontAlpha: value).notificationFontAlpha == value)
        let config = try load("""
        notification_font_alpha = 0.9
        [notifications]
        notification_font_alpha = \(value) # Peak opacity
        notification_font_alpha = 0.9
        [pomodoro]
        notification_font_alpha = 0.9
        """)
        #expect(config.notificationFontAlpha == value)
    }

    @Test(arguments: ["", "invalid", "-0.1", "1.1", "nan", "inf", "-inf", "1e999", "\"0.5\""])
    func invalidFontAlphaUsesDefault(value: String) throws {
        #expect(try load("""
        [notifications]
        notification_font_alpha = \(value)
        notification_font_alpha = 0.5
        """).notificationFontAlpha == 1)
    }

    @Test(arguments: [-0.1, 1.1, Double.nan, Double.infinity, -Double.infinity])
    func initializerRejectsInvalidFontAlpha(value: Double) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationFontAlpha: value).notificationFontAlpha == 1)
    }

    @Test
    func defaultFadeTimeIsOneAndAHalfSeconds() throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil).notificationFadeTimeSeconds == 1.5)
        #expect(try load("").notificationFadeTimeSeconds == 1.5)
    }

    @Test(arguments: ["", "invalid", "-1", "nan", "inf", "1e999", "\"2\""])
    func invalidFadeTimeUsesDefault(value: String) throws {
        #expect(try load("[notifications]\nnotification_fade_time_seconds = \(value)").notificationFadeTimeSeconds == 1.5)
    }

    @Test(arguments: [-1.0, Double.nan, Double.infinity, -Double.infinity])
    func initializerRejectsInvalidFadeTime(value: Double) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationFadeTimeSeconds: value).notificationFadeTimeSeconds == 1.5)
    }

    @Test(arguments: [0.0, 0.25, 2.0])
    func fadeTimeAcceptsNonnegativeSeconds(value: Double) throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationFadeTimeSeconds: value).notificationFadeTimeSeconds == value)
        let config = try load("""
        notification_fade_time_seconds = 99
        [notifications]
        notification_fade_time_seconds = \(value)
        notification_fade_time_seconds = 99
        [pomodoro]
        notification_fade_time_seconds = 99
        """)
        #expect(config.notificationFadeTimeSeconds == value)
        #expect(try load("[pomodoro]\nnotification_fade_time_seconds = 99").notificationFadeTimeSeconds == 1.5)
    }

    @Test
    func invalidFirstFadeTimeDoesNotFallThrough() throws {
        #expect(try load("""
        [notifications]
        notification_fade_time_seconds = invalid
        notification_fade_time_seconds = 2
        """).notificationFadeTimeSeconds == 1.5)
    }

    @Test
    func fontVariationsDefaultToUnspecified() throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil).notificationFontVariations == NotificationFontVariations())
        #expect(try load("").notificationFontVariations == NotificationFontVariations())
    }

    @Test
    func fontVariationsUseFirstValueInNotificationSection() throws {
        let config = try load("""
        notification_font_weight = 100
        [notifications]
        notification_font_weight = 650.5 # OpenType weight
        notification_font_weight = 900
        notification_font_width = 85.5
        notification_font_optical_size_pt = 48
        [pomodoro]
        notification_font_width = 120
        """)
        #expect(config.notificationFontVariations == NotificationFontVariations(weight: 650.5, width: 85.5, opticalSize: 48))
        #expect(try load("[pomodoro]\nnotification_font_weight = 700").notificationFontVariations.weight == nil)
    }

    @Test(arguments: ["", "invalid", "0", "-1", "nan", "inf", "1e999", "\"600\""])
    func invalidFontVariationsKeepDefaults(value: String) throws {
        let config = try load("""
        [notifications]
        notification_font_weight = \(value)
        notification_font_weight = 600
        notification_font_width = \(value)
        notification_font_optical_size_pt = \(value)
        """)
        #expect(config.notificationFontVariations == NotificationFontVariations())
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity, -Double.infinity])
    func initializerRejectsInvalidFontVariations(value: Double) {
        #expect(NotificationFontVariations(weight: value, width: value, opticalSize: value) == NotificationFontVariations())
    }

    private func load(_ contents: String) throws -> CountdownConfiguration {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try contents.write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        return CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
    }
}
