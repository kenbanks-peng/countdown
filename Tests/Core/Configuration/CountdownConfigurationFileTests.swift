import Foundation
import Testing
@testable import Countdown

struct CountdownConfigurationFileTests {
    private func load(_ contents: String?) throws -> CountdownConfiguration {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        if let contents {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            try contents.write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        }
        return CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
    }

    @Test(arguments: [nil, "", "[notifications]\nnotification_enabled = invalid\nnotification_audio_enabled = \"false\"\nalarm_enabled = FALSE\nnotification_time_seconds = invalid\nnotification_marks_minutes = invalid"] as [String?])
    func missingAndInvalidValuesUseDefaults(contents: String?) throws {
        let config = try load(contents)
        #expect(config.size == 1)
        #expect(config.compactSize == 1)
        #expect(config.notificationEnabled)
        #expect(config.notificationAudioEnabled)
        #expect(config.alarmEnabled)
        #expect(config.notificationTimeSeconds == 5)
        #expect(config.notificationIntervalMinutes == 15)
        #expect(config.pomodoroFocusMinutes == 25)
        #expect(config.pomodoroRestMinutes == 5)
        #expect(config.pomodoroLongRestMinutes == 20)
        #expect(config.pomodoroFocusPeriodsPerCycle == 4)
        #expect(config.greenNotificationURL?.lastPathComponent == "green.mp3")
        #expect(config.yellowNotificationURL?.lastPathComponent == "yellow.mp3")
        #expect(config.redNotificationURL?.lastPathComponent == "red.mp3")
        #expect(config.alarmNotificationURL?.lastPathComponent == "alarm.mp3")
    }

    @Test(arguments: ["", "[notifications]\nalarm_message = invalid", "[notifications]\nalarm_message = \"   \""])
    func missingOrInvalidAlarmMessageIsEmpty(contents: String) throws {
        #expect(try load(contents).alarmMessage == "")
    }

    @Test
    func alarmMessageUsesNotificationSectionAndFirstValue() throws {
        let config = try load("""
        alarm_message = "WRONG"
        [notifications]
        alarm_message = " DONE " # Timeout label
        alarm_message = "SECOND"
        """)
        #expect(config.alarmMessage == "DONE")
        #expect(CountdownConfiguration(alarmNotificationURL: nil).alarmMessage == "")
    }

    @Test(arguments: ["0", "0.0", "0.1", "0.5", "1", "1.0", "5"])
    func notificationDurationPreservesNonnegativeSeconds(seconds: String) throws {
        let config = try load("[notifications]\nnotification_time_seconds = \(seconds)")
        #expect(config.notificationTimeSeconds == Double(seconds))
    }

    @Test(arguments: ["-1", "-0.1", "inf", "-inf", "nan", "\"0.1\""])
    func invalidNotificationDurationsUseDefault(seconds: String) throws {
        let config = try load("[notifications]\nnotification_time_seconds = \(seconds)")
        #expect(config.notificationTimeSeconds == 5)
    }

    @Test(arguments: ["", "test = false", "test = invalid", "test = \"true\"", "[notifications]\ntest = true"])
    func testMenuIsDisabledUnlessExplicitlyEnabled(contents: String) throws {
        #expect(!CountdownConfiguration(alarmNotificationURL: nil).testEnabled)
        #expect(try !load(contents).testEnabled)
    }

    @Test
    func testMenuUsesTopLevelFirstValue() throws {
        #expect(try load("test = true # Show the menu\ntest = false\n[notifications]\ntest = false").testEnabled)
        #expect(try !load("test = invalid\ntest = true").testEnabled)
    }

    @Test
    func valuesUseTheirOwnSectionsAndFirstDuplicate() throws {
        let config = try load("""
        size = 1.5
        compact_size = 0.8
        [unrelated]
        notification_enabled = true
        notification_time_seconds = 99
        green_audio = "wrong.mp3"
        focus = 59
        [notifications]
        notification_enabled = false # Master control
        notification_enabled = true
        notification_audio_enabled = false
        alarm_enabled = false
        notification_time_seconds = 7
        notification_marks_minutes = 8
        alarm_audio = "/tmp/alarm.mp3"
        green_audio = "sounds/green.mp3" # Relative path
        red_audio = invalid
        [pomodoro]
        focus = 20
        focus = 30
        long-rest = 60
        """)
        #expect(config.size == 1.5)
        #expect(config.compactSize == 0.8)
        #expect(!config.notificationEnabled)
        #expect(!config.notificationAudioEnabled)
        #expect(!config.alarmEnabled)
        #expect(config.notificationTimeSeconds == 7)
        #expect(config.notificationIntervalMinutes == 10)
        #expect(config.pomodoroFocusMinutes == 20)
        #expect(config.pomodoroRestMinutes == 5)
        #expect(config.pomodoroLongRestMinutes == 60)
        #expect(config.greenNotificationURL?.standardizedFileURL.path.hasSuffix("/countdown/sounds/green.mp3") == true)
        #expect(config.alarmNotificationURL?.path == "/tmp/alarm.mp3")
        #expect(config.yellowNotificationURL?.lastPathComponent == "yellow.mp3")
        #expect(config.redNotificationURL?.lastPathComponent == "red.mp3")
    }

    @Test(arguments: ["[1, 5, 15, 30, 45]", "[45, 5, 1, 30, 15, 5,] # Marks", "[\n1, # One minute\n5, 15,\n30, 45,\n]"])
    func arraysPreserveExactMarks(value: String) throws {
        let config = try load("[notifications]\nnotification_marks_minutes = \(value)")
        #expect(config.notificationMarksMinutes == [1, 5, 15, 30, 45])
    }

    @Test(arguments: ["[1, invalid]", "[1, 2.5]", "[1, -5]", "[1,,5]", "[,]", "[\"1\"]", "[1, 5", "[1] trailing", "[999999999999999999999999]"])
    func invalidArraysUseDefaultInterval(value: String) throws {
        let config = try load("[notifications]\nnotification_marks_minutes = \(value)\nnotification_marks_minutes = [30]\nnotification_audio_enabled = false")
        #expect(config.notificationMarksMinutes == nil)
        #expect(config.notificationIntervalMinutes == 15)
        #expect(!config.notificationAudioEnabled)
    }

    @Test
    func arraysUseTheirOwnSectionAndFirstValue() throws {
        let config = try load("[unrelated]\nnotification_marks_minutes = [45]\n[notifications]\nnotification_marks_minutes = [0, 1, 1]\nnotification_marks_minutes = [30]")
        #expect(config.notificationMarksMinutes == [0, 1])
        #expect(try load("[notifications]\nnotification_marks_minutes = []").notificationMarksMinutes == [])
        #expect(try load("[notifications]\nnotification_marks_minutes = 15").notificationMarksMinutes == nil)
        #expect(try load("[notifications]\nnotification_interval_minutes = 30").notificationIntervalMinutes == 15)
    }

    @Test
    func invalidFirstValuesDoNotFallThrough() throws {
        let config = try load("""
        [notifications]
        notification_enabled = invalid
        notification_enabled = false
        notification_time_seconds = invalid
        notification_time_seconds = 9
        notification_marks_minutes = invalid
        notification_marks_minutes = 30
        alarm_audio = "first.mp3"
        alarm_audio = "second.mp3"
        """)
        #expect(config.notificationEnabled)
        #expect(config.notificationTimeSeconds == 5)
        #expect(config.notificationIntervalMinutes == 15)
        #expect(config.alarmNotificationURL?.lastPathComponent == "first.mp3")
    }
}
