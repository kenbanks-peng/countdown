import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownFeatureStateTests {
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
        popup_enabled = true
        alarm_enabled = true
        popup_time = 15
        alarm_notification = "alarm.mp3"
        """
        try contents.write(to: configURL, atomically: true, encoding: .utf8)
        let configuration = CountdownConfiguration.load(environment: [
            "XDG_CONFIG_HOME": directory.appendingPathComponent("config").path
        ])
        #expect(configuration.popupTime == 15)
        #expect(configuration.alarmNotificationURL?.standardizedFileURL
            == configDirectory.appendingPathComponent("alarm.mp3"))
        let timerStore = TimerStateStore(environment: ["XDG_STATE_HOME": directory.appendingPathComponent("state").path])
        let stateStore = CountdownFeatureStateStore(stateDirectory: timerStore.stateDirectory)
        stateStore.saveEnablement("alarm_enabled", enabled: alarmEnabled)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        func controller() -> CountdownController {
            CountdownController(
                stateStore: timerStore, configuration: configuration,
                playSound: { _ in sounds += 1 }, now: { now }
            )
        }
        let original = controller()
        original.selectMode(.countdown)
        original.features.setPopupEnabled(false)
        original.timer.setCurrentTimeoutEnabled(false)
        original.timer.setAutosetEnabled(true)
        original.save()
        let savedFeatures = try JSONDecoder().decode(
            [String: Bool].self,
            from: Data(contentsOf: timerStore.stateDirectory.appendingPathComponent("features.json"))
        )
        #expect(savedFeatures["popup_enabled"] == false)
        let restored = controller()
        #expect(!restored.mode.isClockEnabled)
        #expect(!restored.features.isPopupEnabled)
        #expect(!restored.timer.isCurrentTimeoutEnabled)
        #expect(restored.timer.isAutosetEnabled)
        #expect(stateStore.load().alarmEnabled == alarmEnabled)
        restored.timer.setAutosetEnabled(false)
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
        let state = CountdownFeatureStateStore(stateDirectory: directory).load()
        #expect(state.currentTimeoutEnabled)
        #expect(state.popupEnabled)
        #expect(state.alarmEnabled == (contents != "{\"alarm_enabled\":false}"))
        #expect(!state.autosetEnabled)
    }

    @Test
    func unavailableStateStorageDoesNotPreventMenuChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "blocked".write(to: directory, atomically: true, encoding: .utf8)
        let controller = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil), playSound: { _ in }
        )
        controller.selectMode(.countdown)
        controller.features.setPopupEnabled(false)
        controller.timer.setCurrentTimeoutEnabled(false)
        controller.timer.setAutosetEnabled(true)
        #expect(!controller.mode.isClockEnabled)
        #expect(!controller.features.isPopupEnabled)
        #expect(!controller.timer.isCurrentTimeoutEnabled)
        #expect(controller.timer.isAutosetEnabled)
        #expect(try String(contentsOf: directory, encoding: .utf8) == "blocked")
    }

    @Test
    func stateDoesNotRequireAConfigurationFile() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timerStore = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        let stateStore = CountdownFeatureStateStore(stateDirectory: timerStore.stateDirectory)
        stateStore.saveEnablement("current_timeout_enabled", enabled: false)
        stateStore.saveEnablement("popup_enabled", enabled: false)
        let controller = CountdownController(
            stateStore: timerStore,
            configuration: CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path]),
            playSound: { _ in }
        )
        #expect(controller.mode == .timer)
        #expect(!controller.features.isPopupEnabled)
        #expect(!controller.timer.isCurrentTimeoutEnabled)
    }
}
