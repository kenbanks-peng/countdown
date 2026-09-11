import Foundation
import Testing
@testable import Countdown

@MainActor
struct NotificationMenuTests {
    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func alarmToggleChangesNextTimeoutWithoutRestart(mode: CountdownMode, enabled: Bool) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        let alarm = URL(fileURLWithPath: "/tmp/alarm.mp3")
        var sounds: [URL?] = []
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: alarm, alarmMessage: "DONE"),
            preferences: CountdownPreferences(alarmEnabled: !enabled),
            playSound: { sounds.append($0) }, now: { now }
        )
        controller.selectMode(mode)
        controller.adjustTimerDuration(by: 300)
        controller.notifications.setAlarmEnabled(enabled)
        now += controller.timer.remaining
        controller.update()
        #expect(sounds == (enabled ? [alarm] : []))
        #expect(controller.notifications.lastEvent == (enabled ? .alarm("DONE") : .remaining(0)))
    }

    @Test
    func notificationMarksAndPhaseChangesDoNotPlaySounds() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var sounds: [URL?] = []
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: URL(fileURLWithPath: "/tmp/alarm.mp3"), notificationIntervalMinutes: 5),
            preferences: CountdownPreferences(), playSound: { sounds.append($0) }
        )
        let notifications = controller.notifications
        for remaining in [1_800.0, 600, 0] {
            notifications.reportElapsed(previousRemaining: remaining + 1, remaining: remaining)
        }
        notifications.reportPhaseChange(remaining: 1_500)
        #expect(notifications.lastEvent == .work)
        notifications.reportPhaseChange(remaining: 0)
        #expect(notifications.lastEvent == .rest)
        #expect(notifications.notificationIntervalCount == 5)
        #expect(sounds.isEmpty)
    }
}
