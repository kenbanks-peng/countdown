import Combine
import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownTestNotificationTests {
    @Test(arguments: CountdownMode.allCases)
    func testImmediatelyUsesCurrentTimeBetweenIntervalMarks(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationEnabled: false, testEnabled: true),
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { _ in sounds += 1 }, now: { now },
            reloadConfiguration: { CountdownConfiguration(alarmNotificationURL: nil) }
        )
        controller.selectMode(mode)
        if mode.usesTimer { controller.adjustTimerDuration(by: 1_200) }
        let previous = mode.usesTimer ? controller.timer.remaining : controller.pomodoro.focusRemaining
        var requests = 0
        var displayedRemaining: TimeInterval = -1
        let subscription = controller.testNotificationRequested.sink { _ in
            requests += 1
            displayedRemaining = mode.usesTimer ? controller.timer.remaining : controller.pomodoro.focusRemaining
        }
        defer { subscription.cancel() }
        now += 78
        controller.testNotification()
        #expect(requests == 1)
        #expect(displayedRemaining == previous - 78)
        #expect(displayedRemaining.truncatingRemainder(dividingBy: 300) != 0)
        #expect(controller.notifications.notificationIntervalCount == 0)
        #expect(!controller.notifications.isNotificationEnabled)
        #expect(sounds == 0)
        controller.testNotification()
        #expect(requests == 2)
    }

    @Test
    func everyTestReadsLatestNotificationSettingsBeforeUpdatingTime() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configDirectory = directory.appendingPathComponent("countdown")
        try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let file = configDirectory.appendingPathComponent("config.toml")
        var events: [String] = []
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, testEnabled: true),
            playSound: { _ in },
            now: { events.append("time"); return Date(timeIntervalSince1970: 1_699_999_800) },
            reloadConfiguration: {
                events.append("reload")
                return CountdownConfiguration.load(environment: ["XDG_CONFIG_HOME": directory.path])
            }
        )
        var received: CountdownConfiguration?
        let subscription = controller.testNotificationRequested.sink { received = $0; events.append("show") }
        defer { subscription.cancel() }
        for size in [180, 240] {
            try """
            test = true
            [notifications]
            notification_font = "Impact"
            notification_font_size_pt = \(size)
            notification_font_alpha = \(Double(size) / 300)
            notification_font_weight = 800
            notification_font_width = 75
            notification_font_optical_size_pt = 48
            notification_time_seconds = 2
            notification_fade_time_seconds = 0
            notification_fade_in = "\(size == 180 ? "linear" : "ease-out")"
            notification_fade_out = "\(size == 180 ? "ease-in-out" : "ease-in")"
            """.write(to: file, atomically: true, encoding: .utf8)
            events = []
            controller.testNotification()
            let config = try #require(received)
            #expect(events.first == "reload")
            #expect(events.contains("time"))
            #expect(events.last == "show")
            #expect(config.notificationFont == "Impact")
            #expect(config.notificationFontSizePt == Double(size))
            #expect(config.notificationFontAlpha == Double(size) / 300)
            #expect(config.notificationFontVariations == NotificationFontVariations(weight: 800, width: 75, opticalSize: 48))
            #expect(config.notificationTimeSeconds == 2)
            #expect(config.notificationFadeTimeSeconds == 0)
            #expect(config.notificationFadeIn == (size == 180 ? .linear : .easeOut))
            #expect(config.notificationFadeOut == (size == 180 ? .easeInOut : .easeIn))
        }
    }

    @Test
    func disabledTestDoesNotEmitRequest() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil), playSound: { _ in }
        )
        var requests = 0
        let subscription = controller.testNotificationRequested.sink { _ in requests += 1 }
        defer { subscription.cancel() }
        controller.testNotification()
        #expect(!controller.testEnabled)
        #expect(requests == 0)
    }

    @Test
    func pausedTestKeepsRemainingTimeAndPauseState() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, testEnabled: true),
            playSound: { _ in }, now: { now },
            reloadConfiguration: { CountdownConfiguration(alarmNotificationURL: nil) }
        )
        controller.selectMode(.countdown)
        controller.adjustTimerDuration(by: 600)
        controller.toggleRunning()
        now += 78
        var requests = 0
        let subscription = controller.testNotificationRequested.sink { _ in requests += 1 }
        defer { subscription.cancel() }
        controller.testNotification()
        #expect(requests == 1)
        #expect(controller.timer.remaining == 600)
        #expect(controller.engine.isPaused)
    }
}
