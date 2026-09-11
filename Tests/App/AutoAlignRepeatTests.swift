import Foundation
import Testing
@testable import Countdown

@MainActor
struct AutoAlignRepeatTests {
    private func date(hour: Int = 5, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15,
                                                   hour: hour, minute: minute))!
    }

    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func timerLoopsUseSavedOrFreshAlignedDuration(mode: CountdownMode, aligned: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = date(minute: 15)
        let controller = session.controller
        controller.selectMode(mode)
        controller.adjustTimerDuration(by: 1_200)
        controller.setAutoRepeatEnabled(true)
        controller.setAutoAlignEnabled(aligned)
        controller.autoAlign()
        #expect(controller.timer.remaining == 900)
        #expect(controller.timer.repeatDuration == 1_200)
        controller.selectMode(mode == .timer ? .countdown : .timer)
        #expect(controller.timer.repeatDuration == 1_200)
        session.now = date(minute: 30)
        controller.update()
        #expect(controller.timer.remaining == (aligned ? 1_800 : 1_200))
        #expect(controller.timer.repeatDuration == 1_200)
        // A late timer repeat starts at the actual update time.
        session.now = date(hour: 6, minute: 7)
        controller.update()
        #expect(controller.timer.remaining == (aligned ? 23 * 60 : 1_200))
    }

    @Test(arguments: [false, true])
    func pomodoroKeepsLongRestAndAlignsNextLoop(loop: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = date(minute: 15)
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.setAutoAlignEnabled(true)
        controller.setAutoRepeatEnabled(loop)
        controller.autoAlign()
        #expect(controller.pomodoro.focusRemaining == 600)
        #expect(controller.pomodoro.savedFocusDuration == 1_500)
        session.now = date(minute: 30)
        controller.update()
        #expect(controller.pomodoro.stage == 2)
        #expect(controller.pomodoro.focusRemaining == 1_500)
        #expect(controller.pomodoro.restRemaining == 300)
        session.now = date(hour: 6, minute: 30)
        controller.update()
        #expect(controller.pomodoro.stage == 4)
        #expect(controller.pomodoro.focusRemaining == 1_500)
        #expect(controller.pomodoro.restRemaining == 2_100)
        #expect(controller.pomodoro.savedLongRestDuration == 900)
        #expect(controller.pomodoro.clockSchedule?.longRestEnd == date(hour: 7, minute: 30))
        session.now = date(hour: 7, minute: 30)
        controller.update()
        #expect(controller.pomodoro.stage == (loop ? 1 : 4))
        #expect(controller.pomodoro.focusRemaining == (loop ? 1_500 : 0))
        #expect(controller.engine.isPaused == !loop)
    }

    @Test
    func toggleIsSharedPersistentAndDoesNotChangeCurrentRun() throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = date()
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.restartPomodoroStage(4)
        let end = controller.pomodoro.clockSchedule?.longRestEnd
        controller.setAutoAlignEnabled(true)
        #expect(controller.pomodoro.clockSchedule?.longRestEnd == end)
        controller.restartPomodoroStage(4)
        #expect(controller.pomodoro.restRemaining == 2_100)
        controller.save()
        let store = TimerSessionStore(environment: ["XDG_STATE_HOME": session.directory.path])
        let restored = CountdownController(sessionStore: store, configuration: CountdownConfiguration(alarmNotificationURL: nil, pomodoroFocusPeriodsPerCycle: 4), playSound: { _ in }, now: { session.now })
        #expect(restored.timer.isAutoAlignEnabled)
        #expect(restored.pomodoro.isAutoAlignEnabled)
        #expect(restored.pomodoro.restRemaining == 2_100)
        #expect(restored.pomodoro.savedLongRestDuration == 900)
        for mode in CountdownMode.allCases {
            restored.selectMode(mode)
            #expect(restored.timer.isAutoAlignEnabled)
            #expect(restored.pomodoro.isAutoAlignEnabled)
        }
    }

    @Test
    func disablingAutoAlignRestoresSavedAllocations() throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = date()
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.setAutoRepeatEnabled(true)
        controller.setAutoAlignEnabled(true)
        controller.restartPomodoroStage(4)
        controller.setAutoAlignEnabled(false)
        #expect(controller.pomodoro.restRemaining == 2_100)
        session.now = try #require(controller.pomodoro.clockSchedule?.longRestEnd)
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 1_500)
        #expect(controller.pomodoro.restRemaining == 300)
        controller.restartPomodoroStage(4)
        #expect(controller.pomodoro.restRemaining == 900)
    }
}
