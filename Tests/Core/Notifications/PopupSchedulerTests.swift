import Foundation
import Testing
@testable import Countdown

@MainActor
struct PopupSchedulerTests {
    @Test(arguments: [-10, 0, 1, 2, 7, 14, 16])
    func unsupportedIntervalsUseDefault(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: value).popupIntervalMinutes == 5)
    }

    @Test(arguments: [5, 10, 15, 20, 60, 120])
    func supportedIntervalsAreUnchanged(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: value).popupIntervalMinutes == value)
    }

    @Test(arguments: [0, 1, 59])
    func firstPopupRoundsUpThenKeepsItsClockSchedule(seconds: Int) {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8, minute: 8, second: seconds))!
        var now = start
        let popups = PopupScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: 15),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        var remaining: TimeInterval = 7_200
        func advance(_ seconds: TimeInterval) {
            let previous = remaining
            now += seconds
            remaining -= seconds
            popups.reportElapsed(previousRemaining: previous, remaining: remaining)
        }
        advance(TimeInterval(17 * 60 - seconds - 1)) // 08:24:59
        #expect(popups.popupIntervalCount == 0)
        advance(1) // 08:25
        #expect(popups.popupIntervalCount == 1)
        advance(899)
        #expect(popups.popupIntervalCount == 1)
        advance(1) // 08:40
        #expect(popups.popupIntervalCount == 2)
        advance(2 * 900 + 30) // Late update at 09:10:30 emits once.
        #expect(popups.popupIntervalCount == 3)
        advance(869)
        #expect(popups.popupIntervalCount == 3)
        advance(1) // 09:25, not 09:25:30.
        #expect(popups.popupIntervalCount == 4)
    }

    @Test
    func alignedStartDoesNotAddAnotherFiveMinutes() {
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8, minute: 10))!
        let popups = PopupScheduler(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: 15),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        now += 900
        popups.reportElapsed(previousRemaining: 3_600, remaining: 2_700)
        #expect(popups.popupIntervalCount == 1)
    }

    @Test(arguments: CountdownMode.allCases)
    func resumeSkipsPausedPopupsAndKeepsOriginalClockTimes(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8, minute: 8))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupIntervalMinutes: 15),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(mode)
        if mode.usesTimer { controller.adjustTimerDuration(by: 3_600) }
        now += 120 // Pause at 08:10.
        controller.toggleRunning()
        now += 31 * 60 // Resume at 08:41, without updates during the pause.
        controller.toggleRunning()
        #expect(controller.popups.popupIntervalCount == 0)
        now += 14 * 60 - 1
        controller.update()
        #expect(controller.popups.popupIntervalCount == 0)
        now += 1 // 08:55: original schedule, not a new interval from resume.
        controller.update()
        #expect(controller.popups.popupIntervalCount == 1)
    }
}
