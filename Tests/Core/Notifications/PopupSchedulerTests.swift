import Foundation
import Testing
@testable import Countdown

@MainActor
struct PopupSchedulerTests {
    @Test(arguments: [false, true], [false, true])
    func popupAndAudioAreIndependent(popup: Bool, audio: Bool) {
        var sounds: [URL?] = []
        let green = URL(fileURLWithPath: "/tmp/green.mp3")
        let yellow = URL(fileURLWithPath: "/tmp/yellow.mp3")
        let red = URL(fileURLWithPath: "/tmp/red.mp3")
        let popups = PopupScheduler(
            configuration: CountdownConfiguration(
                alarmNotificationURL: nil, greenNotificationURL: green,
                yellowNotificationURL: yellow, redNotificationURL: red,
                popupIntervalMinutes: 5, popupNotificationEnabled: popup,
                audioNotificationEnabled: audio
            ), playSound: { sounds.append($0) }, saveEnablement: { _, _ in }
        )
        popups.reportElapsed(previousRemaining: 1_801, remaining: 1_800)
        popups.reportElapsed(previousRemaining: 601, remaining: 600)
        popups.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(popups.popupIntervalCount == (popup ? 3 : 0))
        #expect(sounds == (audio ? [green, yellow, red] : []))
        popups.setPopupEnabled(false)
        popups.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(popups.popupIntervalCount == (popup ? 3 : 0))
        #expect(sounds.count == (audio ? 4 : 0))
    }

    @Test
    func masterControlDisablesPopupAndAudio() {
        var sounds = 0
        let popups = PopupScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationEnabled: false),
            playSound: { _ in sounds += 1 }, saveEnablement: { _, _ in }
        )
        popups.setPopupEnabled(true)
        popups.reportElapsed(previousRemaining: 901, remaining: 900)
        popups.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(popups.popupIntervalCount == 0)
        #expect(sounds == 0)
    }

    @Test(arguments: [-10, 0, 1, 2, 7])
    func smallIntervalsUseFiveMinutes(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: value).popupIntervalMinutes == 5)
    }

    @Test(arguments: [(8, 10), (12, 10), (13, 15), (14, 15), (16, 15), (18, 20)])
    func intervalsRoundToNearestFive(value: Int, expected: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: value).popupIntervalMinutes == expected)
    }

    @Test(arguments: [5, 10, 15, 20, 60, 120])
    func supportedIntervalsAreUnchanged(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: value).popupIntervalMinutes == value)
    }

    @Test(arguments: [-1, 0, 1, 7, 30])
    func popupDisplayTimeUsesPositiveSeconds(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupTimeSeconds: value).popupTimeSeconds == (value > 0 ? value : 5))
    }

    @Test(arguments: [5, 8])
    func scheduleCountsBackwardsFromEndTime(interval: Int) {
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 50))!
        var now = end.addingTimeInterval(-17 * 60) // 14:33
        var sounds = 0
        let popups = PopupScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: interval),
            playSound: { _ in sounds += 1 }, saveEnablement: { _, _ in }
        )
        var popupMinutes: [Int] = []
        while now < end {
            let previous = end.timeIntervalSince(now)
            now += 1
            let count = popups.popupIntervalCount
            popups.reportElapsed(previousRemaining: previous, remaining: end.timeIntervalSince(now))
            if popups.popupIntervalCount > count {
                #expect(Calendar.current.component(.second, from: now) == 0)
                popupMinutes.append(Calendar.current.component(.minute, from: now))
            }
        }
        #expect(popupMinutes == (interval == 5 ? [35, 40, 45, 50] : [40, 50]))
        #expect(sounds == popupMinutes.count)
        popups.reportElapsed(previousRemaining: 0, remaining: 0)
        #expect(popups.popupIntervalCount == sounds)
    }

    @Test
    func lateUpdatesEmitOnceAndKeepEndpointSchedule() {
        let popups = PopupScheduler(configuration: CountdownConfiguration(alarmNotificationURL: nil), playSound: { _ in }, saveEnablement: { _, _ in })
        popups.reportElapsed(previousRemaining: 1_020, remaining: 299)
        #expect(popups.popupIntervalCount == 1)
        popups.reportElapsed(previousRemaining: 299, remaining: 1)
        #expect(popups.popupIntervalCount == 1)
        popups.reportElapsed(previousRemaining: 1, remaining: 0)
        #expect(popups.popupIntervalCount == 2)
    }

    @Test
    func disabledAndPausedUpdatesDoNotReplayPopups() {
        let popups = PopupScheduler(configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: 5), playSound: { _ in }, saveEnablement: { _, _ in })
        popups.setPopupEnabled(false)
        popups.reportElapsed(previousRemaining: 1_020, remaining: 600)
        popups.setPopupEnabled(true)
        popups.reportElapsed(previousRemaining: 600, remaining: 600)
        popups.reportElapsed(previousRemaining: 600, remaining: 301)
        #expect(popups.popupIntervalCount == 0)
        popups.reportElapsed(previousRemaining: 301, remaining: 300)
        #expect(popups.popupIntervalCount == 1)
    }

    @Test(arguments: [5, 8])
    func pomodoroNotifiesDuringFocusAndAtPhaseBoundaries(interval: Int) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 25))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: interval),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, by: 600)
        controller.popups.setPopupEnabled(false)
        now += 8 * 60 // 14:33, focus ends at 14:50 and rest ends at 15:05.
        controller.update()
        controller.popups.setPopupEnabled(true)
        var popupMinutes: [Int] = []
        for _ in 0..<(32 * 60) {
            now += 1
            let count = controller.popups.popupIntervalCount
            controller.update()
            if controller.popups.popupIntervalCount > count {
                popupMinutes.append(Calendar.current.component(.minute, from: now))
            }
        }
        #expect(popupMinutes == (interval == 5 ? [35, 40, 45, 50, 5] : [40, 50, 5]))
    }

    @Test(arguments: [false, true], [false, true])
    func pomodoroLongRestAndLateUpdates(popup: Bool, notifications: Bool) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!
        var now = start
        var sounds = 0
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, notificationEnabled: notifications),
            preferences: CountdownPreferences(popupEnabled: popup),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(.pomodoro)
        // Skip to long rest, then cross its interval marks without notifications.
        now = start + 115 * 60
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.popups.popupIntervalCount == (popup && notifications ? 1 : 0))
        for minute in [120, 125, 130, 134] {
            now = start + Double(minute * 60)
            controller.update()
        }
        #expect(controller.popups.popupIntervalCount == (popup && notifications ? 1 : 0))
        #expect(sounds == (notifications ? 1 : 0))
        now = start + 135 * 60
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 1_500)
        #expect(controller.popups.popupIntervalCount == (popup && notifications ? 2 : 0))
        #expect(sounds == (notifications ? 2 : 0))
        // A complete cycle still emits once, even if the stage number is unchanged.
        now += controller.pomodoro.cycleDuration
        controller.update()
        controller.update()
        #expect(controller.popups.popupIntervalCount == (popup && notifications ? 3 : 0))
        #expect(sounds == (notifications ? 3 : 0))
    }

    @Test(arguments: CountdownMode.allCases)
    func resumeUsesCurrentEndpointWithoutReplayingPausedPopups(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 14, minute: 25))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: 10),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(mode)
        if mode.usesTimer { controller.adjustTimerDuration(by: 1_500) }
        now += 120
        controller.toggleRunning()
        now += 31 * 60
        controller.toggleRunning()
        #expect(controller.popups.popupIntervalCount == 0)
        let remaining = mode.usesTimer ? controller.timer.remaining : controller.pomodoro.focusRemaining
        let untilPopup = remaining.truncatingRemainder(dividingBy: 600)
        now += (untilPopup > 0 ? untilPopup : 600) - 1
        controller.update()
        #expect(controller.popups.popupIntervalCount == 0)
        now += 1
        controller.update()
        #expect(controller.popups.popupIntervalCount == 1)
    }

    @Test
    func endpointEditsDoNotLeaveAStaleSchedule() {
        let popups = PopupScheduler(configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: 10), playSound: { _ in }, saveEnablement: { _, _ in })
        popups.reportElapsed(previousRemaining: 1_020, remaining: 900)
        #expect(popups.popupIntervalCount == 0)
        // The caller adds five minutes, without reporting the edit as elapsed time.
        popups.reportElapsed(previousRemaining: 1_200, remaining: 900)
        #expect(popups.popupIntervalCount == 0)
        popups.reportElapsed(previousRemaining: 900, remaining: 600)
        #expect(popups.popupIntervalCount == 1)
    }
}
