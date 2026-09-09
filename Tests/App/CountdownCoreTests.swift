import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownCoreTests {
    @Test(arguments: CountdownMode.allCases)
    func sharedControlsAndNotificationFollowTheActiveMode(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        var settings: [String: Bool] = [:]
        let timer = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5),
            playSound: { _ in sounds += 1 }, now: { now },
            saveEnablement: { settings[$0] = $1 }
        )
        timer.selectMode(mode)
        if mode.usesTimer { timer.adjustTimerDuration(by: 1_800) }
        #expect(timer.controlLabel == "Pause")
        now += 300
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 1)
        #expect(sounds == 1)
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 1)

        timer.toggleRunning()
        #expect(timer.controlLabel == "Resume")
        now += 900
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 1)
        timer.toggleRunning()
        now += 300
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 2)

        timer.notifications.setNotificationEnabled(false)
        now += 300
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 2)
        timer.selectMode(.countdown)
        let notifications = timer.notifications
        timer.selectMode(mode.usesTimer ? .pomodoro : .timer)
        #expect(timer.notifications === notifications)
        #expect(!timer.notifications.isNotificationEnabled)
        now += 600
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 2)
        #expect(sounds == 2) // Disabling notifications also disables notification audio.
        #expect(settings == ["notification_enabled": false])
    }

    @Test
    func restoringTimerDoesNotReplayNotificationsFromTimeWhileClosed() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        let store = TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path])
        store.save(.init(status: .active, duration: 1_800, remaining: 1_800,
                         endDate: now.addingTimeInterval(1_800), savedAt: now))
        now += 360
        var sounds = 0
        let controller = CountdownController(
            sessionStore: store,
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        #expect(controller.timer.remaining == 1_440)
        #expect(sounds == 0)
        now += 239 // One second before the next end-anchored notification.
        controller.update()
        #expect(sounds == 0)
        now += 1
        controller.update()
        #expect(sounds == 1)
    }

    @Test(arguments: CountdownMode.allCases)
    func durationIncreaseDoesNotRepeatNotificationAfterOnlyOneMinute(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(mode)
        if mode.usesTimer { controller.adjustTimerDuration(by: 1_800) }
        now += 300
        controller.update()
        #expect(sounds == 1)
        if mode.usesTimer { controller.adjustTimerDuration(by: 300) }
        else { controller.adjustPomodoroDuration(.focus, by: 300) }
        now += 60
        controller.update()
        #expect(sounds == 1)
        now += 240
        controller.update()
        #expect(sounds == 2)
    }

    @Test
    func hiddenModeIsSilentAndSwitchingDoesNotCauseAnEarlyNotification() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.adjustTimerDuration(by: 610)
        controller.selectMode(.pomodoro)
        now += 10 // Hidden Timer crosses 600 seconds.
        controller.update()
        #expect(sounds == 0)
        now += 290 // Visible Pomodoro has run for five minutes.
        controller.update()
        controller.update() // A second view can also request an update.
        #expect(sounds == 1)
        controller.selectMode(.timer)
        now += 10 // Timer crosses 300 seconds, only ten seconds after the last sound.
        controller.update()
        #expect(sounds == 1)
    }

    @Test(arguments: CountdownMode.allCases)
    func durationEditsDoNotCauseNotificationAndCompletionDoesNotRepeatIt(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        let timer = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        timer.selectMode(mode)
        if mode.usesTimer {
            timer.adjustTimerDuration(by: 1_800)
            timer.adjustTimerDuration(by: -600)
        } else {
            timer.adjustPomodoroDuration(.focus, by: -600)
        }
        #expect(timer.notifications.notificationIntervalCount == 0)
        now += 299
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 0)
        now += 1
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 1)
        now += 361 // A delayed update reports one notification, not a burst.
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 2)
        now += 10_000
        timer.update()
        timer.update()
        #expect(timer.notifications.notificationIntervalCount == 3) // Includes the endpoint notification.
    }
}
