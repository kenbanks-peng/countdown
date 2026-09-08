import Foundation
import Testing
@testable import Countdown

struct ReminderConfigurationTests {
    @Test
    func defaultFontIs144Points() throws {
        #expect(CountdownConfiguration(alarmNotificationURL: nil).reminderFontSizePt == 144)
        #expect(try load("").reminderFontSizePt == 144)
    }

    @Test(arguments: ["", "invalid", "0", "-1", "nan", "inf", "1e999", "\"180\""])
    func invalidFontSizeUsesDefault(value: String) throws {
        #expect(try load("[notifications]\nreminder_font_size_pt = \(value)").reminderFontSizePt == 144)
    }

    @Test(arguments: [0.0, -1, Double.nan, Double.infinity])
    func initializerRejectsInvalidFontSize(value: Double) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, reminderFontSizePt: value).reminderFontSizePt == 144)
    }

    @Test
    func fontSizeUsesNotificationSectionAndIsIndependentOfWindowScales() throws {
        let config = try load("""
        size = 2
        compact_size = 0.5
        reminder_font_size_pt = 90
        [notifications]
        reminder_notification_enabled = false
        reminder_font_size_pt = 180.5 # Points
        [pomodoro]
        reminder_font_size_pt = 12
        """)
        #expect(config.reminderFontSizePt == 180.5)
        #expect(!config.reminderNotificationEnabled)
        #expect(config.size == 2)
        #expect(config.compactSize == 0.5)
        #expect(try load("[pomodoro]\nreminder_font_size_pt = 12").reminderFontSizePt == 144)
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
