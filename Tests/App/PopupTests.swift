import Foundation
import Testing
@testable import Countdown

@MainActor
struct PopupTests {
    @Test(arguments: [-10, 0, 1, 2, 7, 14, 16])
    func unsupportedIntervalsUseDefault(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupTime: value).popupTime == 5)
    }

    @Test(arguments: [5, 10, 15, 20, 60, 120])
    func supportedIntervalsAreUnchanged(value: Int) {
        #expect(CountdownConfiguration(alarmNotificationURL: nil, popupTime: value).popupTime == value)
    }

    @Test(arguments: [0, 1, 59])
    func firstPopupRoundsUpThenKeepsItsClockSchedule(seconds: Int) {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8, minute: 8, second: seconds))!
        var now = start
        let features = CountdownFeatures(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupTime: 15),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        var remaining: TimeInterval = 7_200
        func advance(_ seconds: TimeInterval) {
            let previous = remaining
            now += seconds
            remaining -= seconds
            features.reportElapsed(previousRemaining: previous, remaining: remaining)
        }
        advance(TimeInterval(17 * 60 - seconds - 1)) // 08:24:59
        #expect(features.popupIntervalCount == 0)
        advance(1) // 08:25
        #expect(features.popupIntervalCount == 1)
        advance(899)
        #expect(features.popupIntervalCount == 1)
        advance(1) // 08:40
        #expect(features.popupIntervalCount == 2)
        advance(2 * 900 + 30) // Late update at 09:10:30 emits once.
        #expect(features.popupIntervalCount == 3)
        advance(869)
        #expect(features.popupIntervalCount == 3)
        advance(1) // 09:25, not 09:25:30.
        #expect(features.popupIntervalCount == 4)
    }

    @Test
    func alignedStartDoesNotAddAnotherFiveMinutes() {
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8, minute: 10))!
        let features = CountdownFeatures(
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupTime: 15),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        now += 900
        features.reportElapsed(previousRemaining: 3_600, remaining: 2_700)
        #expect(features.popupIntervalCount == 1)
    }

    @Test(arguments: CountdownMode.allCases)
    func resumeSkipsPausedPopupsAndKeepsOriginalClockTimes(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 8, minute: 8))!
        let controller = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, popupTime: 15),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(mode)
        if mode == .timer { controller.adjustTimerDuration(by: 3_600) }
        now += 120 // Pause at 08:10.
        controller.toggleRunning()
        now += 31 * 60 // Resume at 08:41, without updates during the pause.
        controller.toggleRunning()
        #expect(controller.features.popupIntervalCount == 0)
        now += 14 * 60 - 1
        controller.update()
        #expect(controller.features.popupIntervalCount == 0)
        now += 1 // 08:55: original schedule, not a new interval from resume.
        controller.update()
        #expect(controller.features.popupIntervalCount == 1)
    }
}
