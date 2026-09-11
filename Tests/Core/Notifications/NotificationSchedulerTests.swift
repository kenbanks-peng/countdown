import Foundation
import Testing
@testable import Countdown

@MainActor
struct NotificationSchedulerTests {
    @Test(arguments: [false, true])
    func notificationEnablementControlsText(notification: Bool) {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5),
            state: CountdownPreferences(notificationEnabled: notification), saveEnablement: { _, _ in }
        )
        notifications.reportElapsed(previousRemaining: 1_801, remaining: 1_800)
        notifications.reportElapsed(previousRemaining: 601, remaining: 600)
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.notificationIntervalCount == (notification ? 3 : 0))
        notifications.setNotificationEnabled(false)
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.notificationIntervalCount == (notification ? 3 : 0))
    }

    @Test
    func menuCanEnableNotificationsFromDisabledState() {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            state: CountdownPreferences(notificationEnabled: false),
            saveEnablement: { _, _ in }
        )
        notifications.setNotificationEnabled(true)
        notifications.reportElapsed(previousRemaining: 901, remaining: 900)
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.notificationIntervalCount == 2)
    }

    @Test(arguments: [-10, 0, 1, 2, 7])
    func smallIntervalsUseFiveMinutes(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: value).notificationIntervalMinutes == 5)
    }

    @Test(arguments: [(8, 10), (12, 10), (13, 15), (14, 15), (16, 15), (18, 20)])
    func intervalsRoundToNearestFive(value: Int, expected: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: value).notificationIntervalMinutes == expected)
    }

    @Test(arguments: [5, 10, 15, 20, 60, 120])
    func supportedIntervalsAreUnchanged(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: value).notificationIntervalMinutes == value)
    }

    @Test(arguments: [0.0, 0.1, 0.5, 1, 7, 30])
    func notificationDisplayTimePreservesNonnegativeSeconds(value: Double) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationHoldTimeSeconds: value).notificationHoldTimeSeconds == value)
    }

    @Test(arguments: [-1.0, -0.1, Double.infinity, -Double.infinity, Double.nan])
    func invalidNotificationDisplayTimesUseDefault(value: Double) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, notificationHoldTimeSeconds: value).notificationHoldTimeSeconds == 5)
    }

    @Test(arguments: [5, 8])
    func scheduleCountsBackwardsFromEndTime(interval: Int) {
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 50))!
        var now = end.addingTimeInterval(-17 * 60) // 14:33
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: interval),
            saveEnablement: { _, _ in }
        )
        var notificationMinutes: [Int] = []
        while now < end {
            let previous = end.timeIntervalSince(now)
            now += 1
            let count = notifications.notificationIntervalCount
            notifications.reportElapsed(previousRemaining: previous, remaining: end.timeIntervalSince(now))
            if notifications.notificationIntervalCount > count {
                #expect(Calendar.current.component(.second, from: now) == 0)
                notificationMinutes.append(Calendar.current.component(.minute, from: now))
            }
        }
        #expect(notificationMinutes == (interval == 5 ? [35, 40, 45, 50] : [40, 50]))
        notifications.reportElapsed(previousRemaining: 0, remaining: 0)
        #expect(notifications.notificationIntervalCount == notificationMinutes.count)
    }

    @Test
    func lateUpdatesEmitOnceAndKeepEndpointSchedule() {
        let notifications = NotificationScheduler(configuration: CountdownConfiguration(alarmNotificationURL: nil), saveEnablement: { _, _ in })
        notifications.reportElapsed(previousRemaining: 1_020, remaining: 299)
        #expect(notifications.notificationIntervalCount == 1)
        notifications.reportElapsed(previousRemaining: 299, remaining: 1)
        #expect(notifications.notificationIntervalCount == 1)
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.notificationIntervalCount == 2)
    }

    @Test
    func disabledAndPausedUpdatesDoNotReplayNotifications() {
        let notifications = NotificationScheduler(configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 5), saveEnablement: { _, _ in })
        notifications.setNotificationEnabled(false)
        notifications.reportElapsed(previousRemaining: 1_020, remaining: 600)
        notifications.setNotificationEnabled(true)
        notifications.reportElapsed(previousRemaining: 600, remaining: 600)
        notifications.reportElapsed(previousRemaining: 600, remaining: 301)
        #expect(notifications.notificationIntervalCount == 0)
        notifications.reportElapsed(previousRemaining: 301, remaining: 300)
        #expect(notifications.notificationIntervalCount == 1)
    }

    @Test(arguments: [5, 8])
    func pomodoroNotifiesDuringFocusAndAtPhaseBoundaries(interval: Int) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 25))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: interval),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, by: 600)
        controller.notifications.setNotificationEnabled(false)
        now += 8 * 60 // 14:33, focus ends at 14:50 and rest ends at 15:05.
        controller.update()
        controller.notifications.setNotificationEnabled(true)
        var notificationMinutes: [Int] = []
        var events: [NotificationScheduler.Event] = []
        let subscription = controller.notifications.$notificationIntervalCount.dropFirst().sink { _ in
            if let event = controller.notifications.lastEvent { events.append(event) }
        }
        defer { subscription.cancel() }
        for _ in 0..<(32 * 60) {
            now += 1
            let count = controller.notifications.notificationIntervalCount
            controller.update()
            if controller.notifications.notificationIntervalCount > count {
                notificationMinutes.append(Calendar.current.component(.minute, from: now))
            }
        }
        #expect(notificationMinutes == (interval == 5 ? [35, 40, 45, 50, 5] : [40, 50, 5]))
        #expect(events == (interval == 5
            ? [.remaining(900), .remaining(600), .remaining(300), .rest, .work]
            : [.remaining(600), .rest, .work]))
    }

    @Test(arguments: [false, true])
    func pomodoroLongRestAndLateUpdates(notification: Bool) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        var now = start
        var sounds = 0
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(notificationEnabled: notification),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(.pomodoro)
        controller.setAutoRepeatEnabled(true)
        // Skip to long rest, then cross its interval marks without notifications.
        now = start + 115 * 60
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.notifications.notificationIntervalCount == (notification ? 1 : 0))
        for minute in [120, 125, 130, 134] {
            now = start + Double(minute * 60)
            controller.update()
        }
        #expect(controller.notifications.notificationIntervalCount == (notification ? 1 : 0))
        #expect(sounds == 0)
        now = start + 135 * 60
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 1_500)
        #expect(controller.notifications.notificationIntervalCount == (notification ? 2 : 0))
        #expect(sounds == 0)
        // A complete cycle still emits once, even if the stage number is unchanged.
        now += controller.pomodoro.cycleDuration
        controller.update()
        controller.update()
        #expect(controller.notifications.notificationIntervalCount == (notification ? 3 : 0))
        #expect(sounds == 0)
    }

    @Test(arguments: CountdownMode.allCases)
    func resumeUsesCurrentEndpointWithoutReplayingPausedNotifications(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 25))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 10),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(mode)
        if mode.usesTimer { controller.adjustTimerDuration(by: 1_500) }
        now += 120
        controller.toggleRunning()
        now += 31 * 60
        controller.toggleRunning()
        #expect(controller.notifications.notificationIntervalCount == 0)
        let remaining = mode.usesTimer ? controller.timer.remaining : controller.pomodoro.focusRemaining
        let untilNotification = remaining.truncatingRemainder(dividingBy: 600)
        now += (untilNotification > 0 ? untilNotification : 600) - 1
        controller.update()
        #expect(controller.notifications.notificationIntervalCount == 0)
        now += 1
        controller.update()
        #expect(controller.notifications.notificationIntervalCount == 1)
    }

    @Test(arguments: [false, true])
    func alarmMessageUsesSavedAlarmControl(savedEnabled: Bool) {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationMarksMinutes: [1],
                                                 alarmMessage: "DONE"),
            state: CountdownPreferences(alarmEnabled: savedEnabled),
            saveEnablement: { _, _ in }
        )
        notifications.reportElapsed(previousRemaining: 61, remaining: 60)
        #expect(notifications.lastEvent == .remaining(60))
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.lastEvent == (savedEnabled ? .alarm("DONE") : .remaining(0)))
        notifications.reportPhaseChange(remaining: 0)
        #expect(notifications.lastEvent == .rest)
        notifications.reportPhaseChange(remaining: 1_500)
        #expect(notifications.lastEvent == .work)
    }

    @Test(arguments: ["", "   ", "\n"])
    func emptyAlarmMessageKeepsZero(message: String) {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, alarmMessage: message),
            saveEnablement: { _, _ in }
        )
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.lastEvent == .remaining(0))
    }

    @Test
    func exactMarksNotifyOnceAtEachMarkAndAtZero() {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationMarksMinutes: [1, 5, 15, 30, 45, 5]),
            saveEnablement: { _, _ in }
        )
        var marks: [Int] = []
        for remaining in stride(from: 3_600, through: 0, by: -1) {
            let count = notifications.notificationIntervalCount
            notifications.reportElapsed(previousRemaining: Double(remaining + 1), remaining: Double(remaining))
            if notifications.notificationIntervalCount > count { marks.append(remaining) }
        }
        #expect(marks == [2_700, 1_800, 900, 300, 60, 0])
    }

    @Test(arguments: [[Int](), [0], [1, 5, 15, 30, 45]])
    func exactMarksKeepEndAndPhaseNotifications(marks: [Int]) {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationMarksMinutes: marks),
            saveEnablement: { _, _ in }
        )
        notifications.reportElapsed(previousRemaining: 1, remaining: -1)
        #expect(notifications.notificationIntervalCount == 1)
        notifications.reportElapsed(previousRemaining: -1, remaining: -2)
        #expect(notifications.notificationIntervalCount == 1)
        notifications.reportPhaseChange(remaining: 0)
        #expect(notifications.lastEvent == .rest)
        notifications.reportPhaseChange(remaining: 1_500)
        #expect(notifications.lastEvent == .work)
        #expect(notifications.notificationIntervalCount == 3)
    }

    @Test
    func exactMarksHandleLatePausedDisabledAndInvalidUpdates() {
        let notifications = NotificationScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationMarksMinutes: [1, 5, 15, 30, 45]),
            saveEnablement: { _, _ in }
        )
        notifications.reportElapsed(previousRemaining: 3_000, remaining: 299)
        #expect(notifications.notificationIntervalCount == 1)
        #expect(notifications.lastEvent == .remaining(299))
        notifications.reportElapsed(previousRemaining: 299, remaining: 299)
        notifications.reportElapsed(previousRemaining: 299, remaining: 600)
        notifications.reportElapsed(previousRemaining: .infinity, remaining: 0)
        notifications.reportElapsed(previousRemaining: 299, remaining: .nan)
        // An endpoint edit is not elapsed time. Starting at a mark must not replay it.
        notifications.reportElapsed(previousRemaining: 300, remaining: 61)
        #expect(notifications.notificationIntervalCount == 1)
        notifications.setNotificationEnabled(false)
        notifications.reportElapsed(previousRemaining: 61, remaining: 60)
        notifications.setNotificationEnabled(true)
        notifications.reportElapsed(previousRemaining: 60, remaining: 1)
        #expect(notifications.notificationIntervalCount == 1)
        notifications.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(notifications.notificationIntervalCount == 2)
    }

    @Test
    func endpointEditsDoNotLeaveAStaleSchedule() {
        let notifications = NotificationScheduler(configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationIntervalMinutes: 10), saveEnablement: { _, _ in })
        notifications.reportElapsed(previousRemaining: 1_020, remaining: 900)
        #expect(notifications.notificationIntervalCount == 0)
        // The caller adds five minutes, without reporting the edit as elapsed time.
        notifications.reportElapsed(previousRemaining: 1_200, remaining: 900)
        #expect(notifications.notificationIntervalCount == 0)
        notifications.reportElapsed(previousRemaining: 900, remaining: 600)
        #expect(notifications.notificationIntervalCount == 1)
    }
}
