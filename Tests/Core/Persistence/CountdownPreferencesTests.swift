import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownPreferencesTests {
    @Test
    func stateDirectoryUsesXDGOrDefault() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fallback = home.appendingPathComponent(".local/state/countdown", isDirectory: true)
        #expect(CountdownStateDirectory.resolve(environment: [:]) == fallback)
        #expect(CountdownStateDirectory.resolve(environment: ["XDG_STATE_HOME": ""]) == fallback)
        #expect(CountdownStateDirectory.resolve(environment: ["XDG_STATE_HOME": "/tmp/custom-state"])
            == URL(fileURLWithPath: "/tmp/custom-state/countdown", isDirectory: true))
    }

    @Test(arguments: [true, false])
    func menuChangesPersistWithoutChangingConfiguration(alarmEnabled: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("config/countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let configURL = configDirectory.appendingPathComponent("config.toml")
        let contents = """
        [display]
        current_timeout_enabled = true
        [notifications]
        reminder_notification_enabled = true
        audio_notification_enabled = false
        alarm_enabled = true
        notification_time_seconds = 5
        notification_interval_minutes = 15
        alarm_audio = "alarm.mp3"
        """
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        let configuration = CountdownConfiguration.load(environment: [
            "XDG_CONFIG_HOME": directory.appendingPathComponent("config").path
        ])
        #expect(configuration.reminderIntervalMinutes == 15)
        #expect(configuration.alarmNotificationURL?.standardizedFileURL
            == configDirectory.appendingPathComponent("alarm.mp3"))
        let timerStore = TimerSessionStore(environment: ["XDG_STATE_HOME": directory.appendingPathComponent("state").path])
        let stateStore = CountdownPreferencesStore(stateDirectory: timerStore.stateDirectory)
        stateStore.saveEnablement("alarm_enabled", enabled: alarmEnabled)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        func controller() -> CountdownController {
            CountdownController(
                sessionStore: timerStore, configuration: configuration,
                playSound: { _ in sounds += 1 }, now: { now }
            )
        }
        let original = controller()
        original.selectMode(.countdown)
        original.reminders.setReminderEnabled(false)
        original.timer.setRemainingMinutesVisible(false)
        original.timer.setAutoSetToNextHourEnabled(true)
        original.save()
        let savedFeatures = try JSONDecoder().decode(
            [String: Bool].self,
            from: Data(contentsOf: timerStore.stateDirectory.appendingPathComponent("features.json"))
        )
        #expect(savedFeatures["reminder_enabled"] == false)
        let restored = controller()
        #expect(!restored.mode.isClockEnabled)
        #expect(!restored.reminders.isReminderEnabled)
        #expect(!restored.timer.showsRemainingMinutes)
        #expect(restored.timer.isAutoSetToNextHourEnabled)
        #expect(stateStore.load().alarmEnabled == alarmEnabled)
        restored.timer.setAutoSetToNextHourEnabled(false)
        restored.adjustTimerDuration(by: -3_600)
        restored.adjustTimerDuration(by: 60)
        now += 60
        restored.update()
        #expect(restored.timer.completionCount == 1)
        #expect(sounds == (alarmEnabled ? 1 : 0))
        #expect(try String(contentsOf: configURL, encoding: .utf8) == contents)
    }

    @Test(arguments: [nil, "{}", "invalid", "{\"alarm_enabled\":false}", "{\"alarm_enabled\":\"invalid\"}"] as [String?])
    func missingPartialOrInvalidStateUsesDefaults(contents: String?) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        if let contents {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try contents.write(to: directory.appendingPathComponent("features.json"), atomically: true, encoding: .utf8)
        }
        let state = CountdownPreferencesStore(stateDirectory: directory).load()
        #expect(state.showsRemainingMinutes)
        #expect(state.reminderEnabled)
        #expect(state.alarmEnabled == (contents != "{\"alarm_enabled\":false}"))
        #expect(!state.autoSetToNextHourEnabled)
    }

    @Test
    func unavailableStateStorageDoesNotPreventMenuChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "blocked".write(to: directory, atomically: true, encoding: .utf8)
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil), playSound: { _ in }
        )
        controller.selectMode(.countdown)
        controller.reminders.setReminderEnabled(false)
        controller.timer.setRemainingMinutesVisible(false)
        controller.timer.setAutoSetToNextHourEnabled(true)
        #expect(!controller.mode.isClockEnabled)
        #expect(!controller.reminders.isReminderEnabled)
        #expect(!controller.timer.showsRemainingMinutes)
        #expect(controller.timer.isAutoSetToNextHourEnabled)
        #expect(try String(contentsOf: directory, encoding: .utf8) == "blocked")
    }

    @Test
    func updatingOnePreferencePreservesOtherStoredChoices() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CountdownPreferencesStore(stateDirectory: directory)
        store.saveEnablement("unknown_preference", enabled: true)
        store.saveEnablement("alarm_enabled", enabled: false)
        store.saveEnablement("reminder_enabled", enabled: false)
        store.saveEnablement("current_timeout_enabled", enabled: false)
        let values = try JSONDecoder().decode([String: Bool].self,
            from: Data(contentsOf: directory.appendingPathComponent("features.json")))
        #expect(values == ["unknown_preference": true, "alarm_enabled": false,
                           "reminder_enabled": false, "current_timeout_enabled": false])
    }

    @Test
    func stateDoesNotRequireAConfigurationFile() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timerStore = TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path])
        let stateStore = CountdownPreferencesStore(stateDirectory: timerStore.stateDirectory)
        stateStore.saveEnablement("current_timeout_enabled", enabled: false)
        stateStore.saveEnablement("reminder_enabled", enabled: false)
        let controller = CountdownController(
            sessionStore: timerStore,
            configuration: CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path]),
            playSound: { _ in }
        )
        #expect(controller.mode == .timer)
        #expect(!controller.reminders.isReminderEnabled)
        #expect(!controller.timer.showsRemainingMinutes)
    }
}
