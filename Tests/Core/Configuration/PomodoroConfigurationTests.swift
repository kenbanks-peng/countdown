import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroConfigurationTests {
    @Test
    func configDefaultsApplyWithoutSavedDurationsAndSavedEditsTakePriority() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let configURL = configDirectory.appendingPathComponent("config.toml")
        try """
        [unrelated]
        focus = 59
        cycles = 12
        [pomodoro] # All times are minutes.
        focus = 20 # Shared focus duration.
        rest = 7
        long-rest = 22
        cycles = 3 # Focus periods before a long rest.
        """.write(to: configURL, atomically: true, encoding: .utf8)
        let configuration = CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
        #expect(configuration.pomodoroFocusPeriodsPerCycle == 3)
        #expect(configuration.pomodoroFocusMinutes == 20)
        #expect(configuration.pomodoroRestMinutes == 7)
        #expect(configuration.pomodoroLongRestMinutes == 22)
        let store = TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path])
        func controller(_ configuration: CountdownConfiguration) -> CountdownController {
            CountdownController(sessionStore: store, configuration: configuration,
                                preferences: CountdownPreferences(), playSound: { _ in }, now: { Date(timeIntervalSince1970: 1_699_999_800) })
        }
        let original = controller(configuration)
        original.selectMode(.pomodoro)
        #expect(original.pomodoro.focusPeriodsPerCycle == 3)
        #expect(original.pomodoro.focusDuration == 1_200)
        #expect(original.pomodoro.restDuration == 420)
        #expect(original.pomodoro.longRestDuration == 1_320)
        original.adjustPomodoroDuration(.focus, steps: 1)
        original.adjustPomodoroDuration(.rest, steps: 1)
        original.adjustPomodoroDuration(.longRest, steps: 1)
        original.save()
        let restored = controller(CountdownConfiguration(alarmNotificationURL: nil))
        #expect(restored.pomodoro.focusDuration == 1_500)
        #expect(restored.pomodoro.restDuration == 600)
        #expect(restored.pomodoro.longRestDuration == 1_500)
        #expect(restored.pomodoro.stage == 1)
        #expect(restored.pomodoro.focusPeriodsPerCycle == 8)
        #expect(controller(configuration).pomodoro.focusPeriodsPerCycle == 3)
    }

    @Test(arguments: ["0", "-1", "61", "1.5", "\"NaN\"", "99999999999999999999999999"])
    func invalidConfigDurationsUseStandardDefaults(value: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try "[pomodoro]\nfocus = \(value)\nrest = \(value)\nlong-rest = \(value)\n"
            .write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let configuration = CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
        #expect(configuration.pomodoroFocusMinutes == 25)
        #expect(configuration.pomodoroRestMinutes == 5)
        #expect(configuration.pomodoroLongRestMinutes == 20)
    }

    @Test(arguments: ["", "cycles = 0", "cycles = -1", "cycles = 16", "cycles = 1.5",
                      "cycles = \"4\"", "cycles = 99999999999999999999999999"])
    func missingOrInvalidCyclesUseEight(line: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try "[pomodoro]\n\(line)\n"
            .write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let configuration = CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
        #expect(configuration.pomodoroFocusPeriodsPerCycle == 8)
    }

    @Test(arguments: Array(1...15))
    func validCycleCountsLoad(count: Int) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try "[pomodoro]\ncycles = \(count)\n"
            .write(to: configDirectory.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
        let configuration = CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
        #expect(configuration.pomodoroFocusPeriodsPerCycle == count)
    }

    @Test
    func overCapacityConfigurationUsesStandardDefaults() {
        let configuration = CountdownConfiguration(
            alarmNotificationURL: nil, pomodoroFocusMinutes: 50,
            pomodoroRestMinutes: 15, pomodoroLongRestMinutes: 20
        )
        #expect(configuration.pomodoroFocusMinutes == 25)
        #expect(configuration.pomodoroRestMinutes == 5)
        #expect(configuration.pomodoroLongRestMinutes == 20)
    }

    @Test
    func longRestDoesNotRestrictConfiguration() {
        let configuration = CountdownConfiguration(
            alarmNotificationURL: nil, pomodoroFocusMinutes: 55,
            pomodoroRestMinutes: 5, pomodoroLongRestMinutes: 60
        )
        #expect(configuration.pomodoroFocusMinutes == 55)
        #expect(configuration.pomodoroRestMinutes == 5)
        #expect(configuration.pomodoroLongRestMinutes == 60)
    }

    @Test(arguments: ["-60", "0", "59", "3601", "1e309", "\"NaN\""])
    func invalidSavedLongRestUsesConfigDefaults(value: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "{\"mode\":\"Pomodoro\",\"focusDuration\":1500,\"restDuration\":300,\"longRestDuration\":\(value)}"
            .write(to: directory.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
        let store = CountdownSettingsStore(fileManager: .default, stateDirectory: directory)
        let defaults = CountdownSettings(focusDuration: 1_200, restDuration: 420, longRestDuration: 1_200)
        let settings = store.load(defaults: defaults)
        #expect(settings.focusDuration == 1_200)
        #expect(settings.restDuration == 420)
        #expect(settings.longRestDuration == 1_200)
    }
}
