import Foundation
import Testing
@testable import Countdown

struct CountdownConfigurationFileTests {
    @Test
    func firstMatchingValuesAndSectionScopeRemainUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try """
        [unrelated]
        focus = 59
        rest = 44
        popup_time = 10
        [pomodoro] # Minutes
        focus = 20 # First focus wins.
        focus = 30
        [pomodoro]
        focus = 40
        long-rest = 60
        [notifications]
        popup_time = 15
        alarm_notification = "sounds/alarm.mp3"
        green_notification = "sounds/green.mp3"
        red_notification = "invalid.mp3" # Quoted sound values require a closing quote.
        """.write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        let config = CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
        #expect(config.pomodoroFocusMinutes == 20)
        #expect(config.pomodoroRestMinutes == 5) // No fallback to an unrelated section.
        #expect(config.pomodoroLongRestMinutes == 60)
        #expect(config.popupIntervalMinutes == 10) // Notification lookup remains unscoped.
        #expect(config.greenNotificationURL?.standardizedFileURL == configDirectory.appendingPathComponent("sounds/green.mp3"))
        #expect(config.alarmNotificationURL?.standardizedFileURL == configDirectory.appendingPathComponent("sounds/alarm.mp3"))
        #expect(config.yellowNotificationURL == config.alarmNotificationURL)
        #expect(config.redNotificationURL == config.alarmNotificationURL)
    }

    @Test
    func invalidFirstValuesDoNotFallThroughToLaterDuplicates() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try """
        [pomodoro]
        focus = invalid
        focus = 20
        [notifications]
        popup_time = invalid
        popup_time = 15
        alarm_notification = "first.mp3"
        alarm_notification = "second.mp3"
        """.write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let config = CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
        #expect(config.pomodoroFocusMinutes == 25)
        #expect(config.popupIntervalMinutes == 5)
        #expect(config.alarmNotificationURL?.lastPathComponent == "first.mp3")
    }
}
