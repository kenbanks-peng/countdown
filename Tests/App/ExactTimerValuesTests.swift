import Foundation
import Testing
@testable import Countdown

@MainActor
struct ExactTimerValuesTests {
    @Test(arguments: [CountdownMode.timer, .countdown, .pomodoro])
    func exactValuesSurvivePauseModeChangesAndRestart(mode: CountdownMode) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(mode)
        if mode.usesTimer {
            controller.adjustTimerDuration(by: 713.25)
            controller.adjustTimerDuration(by: 60)
        } else {
            controller.adjustPomodoroDuration(.focus, by: 60)
            controller.adjustPomodoroDuration(.rest, by: 60)
            controller.adjustPomodoroDuration(.longRest, by: 60)
        }
        session.now += 17.125
        controller.toggleRunning()
        let remaining = controller.timer.remaining
        let focus = controller.pomodoro.focusRemaining
        let rest = controller.pomodoro.restRemaining
        let schedule = try #require(controller.pomodoro.clockSchedule)
        controller.save()
        session.now += 313.5
        let restored = session.makeController()
        #expect(restored.timer.remaining == remaining)
        #expect(restored.pomodoro.focusRemaining == focus)
        #expect(restored.pomodoro.restRemaining == rest)
        restored.toggleRunning()
        #expect(restored.timer.remaining == remaining)
        #expect(restored.pomodoro.focusRemaining == focus)
        #expect(restored.pomodoro.restRemaining == rest)
        let resumed = try #require(restored.pomodoro.clockSchedule)
        #expect(resumed.focusEnd == schedule.focusEnd + 313.5)
        #expect(resumed.restEnd == schedule.restEnd + 313.5)
        #expect(resumed.longRestEnd == schedule.longRestEnd + 313.5)
        for view in CountdownMode.allCases {
            restored.selectMode(view)
            #expect(restored.timer.remaining == remaining)
            #expect(restored.pomodoro.focusRemaining == focus)
            #expect(restored.pomodoro.restRemaining == rest)
        }
    }

    @Test
    func oneMinutePomodoroEditsSurviveStageChangesAndLongSleep() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: 60)
        controller.adjustPomodoroDuration(.rest, by: 60)
        controller.adjustPomodoroDuration(.longRest, by: 60)
        let selected = try #require(controller.pomodoro.clockSchedule)
        #expect(selected.focusDuration == 1_560)
        #expect(selected.restDuration == 360)
        #expect(selected.longRestDuration == 960)
        for stage in [2, 3, 4, 1, 2] {
            session.now = try #require(controller.pomodoro.clockSchedule).end(for: controller.pomodoro.restPhase)
            controller.update()
            #expect(controller.pomodoro.stage == stage)
            #expect(controller.pomodoro.focusDuration == selected.focusDuration)
            #expect(controller.pomodoro.restDuration == selected.restDuration)
            #expect(controller.pomodoro.longRestDuration == selected.longRestDuration)
        }
        session.now += controller.pomodoro.cycleDuration * 10_000 + 17.125
        controller.update()
        #expect(controller.pomodoro.stage == 2)
        #expect(controller.pomodoro.focusRemaining == selected.focusDuration - 17.125)
        #expect(controller.pomodoro.restRemaining == selected.restDuration)
    }

    @Test(arguments: [false, true])
    func directTimerSettingDoesNotRound(clock: Bool) {
        let session = ClockTestSession(clock: clock)
        defer { session.close() }
        session.controller.timer.setDuration(from: 713.25 / 3_600)
        #expect(session.controller.timer.remaining == 713.25)
        #expect(session.controller.timer.endDate == session.now + 713.25)
    }
}
