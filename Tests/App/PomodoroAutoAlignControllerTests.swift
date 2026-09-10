import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroAutoAlignControllerTests {
    @Test(arguments: [false, true])
    func alignmentUpdatesSharedTimeAndSurvivesRestart(paused: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        if paused { controller.toggleRunning() }
        session.now += 60
        let originalFocus = controller.pomodoro.focusDuration
        #expect(controller.canAutoAlign)
        controller.autoAlign()
        let schedule = try #require(controller.pomodoro.clockSchedule)
        #expect(Calendar.current.component(.minute, from: schedule.restEnd) == 30)
        #expect(Calendar.current.component(.second, from: schedule.restEnd) == 0)
        #expect(controller.timer.remaining == controller.pomodoro.focusRemaining + controller.pomodoro.restRemaining)
        #expect(controller.engine.isPaused == paused)
        #expect(controller.pomodoro.stage == 1)

        let restored = session.makeController()
        #expect(restored.pomodoro.clockSchedule?.restEnd == schedule.restEnd)
        #expect(restored.pomodoro.clockSchedule?.nextStageFocusDuration == originalFocus)
        #expect(restored.engine.isPaused == paused)
        if paused { restored.toggleRunning() }
        session.now = schedule.restEnd
        restored.update()
        #expect(restored.pomodoro.stage == 2)
        #expect(restored.pomodoro.focusRemaining == originalFocus)
    }

    @Test(arguments: [CountdownMode.timer, .countdown])
    func timerModesAlsoSupportAutoAlign(mode: CountdownMode) {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(mode)
        controller.adjustTimerDuration(by: 900)
        #expect(controller.canAutoAlign)
        controller.autoAlign()
        #expect(controller.timer.remaining == 1_666.75)
        #expect(controller.timer.remaining == controller.pomodoro.focusRemaining + controller.pomodoro.restRemaining)
    }

    @Test
    func commandSettlesElapsedTimeBeforeCheckingFocus() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        let schedule = try #require(controller.pomodoro.clockSchedule)
        session.now = schedule.focusEnd
        controller.autoAlign()
        #expect(!controller.canAutoAlign)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.clockSchedule?.restEnd == schedule.restEnd)
    }
}
