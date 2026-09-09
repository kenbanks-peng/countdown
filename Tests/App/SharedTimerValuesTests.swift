import Foundation
import Testing
@testable import Countdown

@MainActor
struct SharedTimerValuesTests {
    @Test(arguments: [CountdownMode.timer, .countdown])
    func editsRemoveAndRestoreFocusWithMinimumRestOnConversion(view: CountdownMode) {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Date(timeIntervalSince1970: 1_699_999_800)
        let controller = session.controller
        controller.selectMode(view)
        controller.adjustTimerDuration(steps: 2)
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.focusRemaining == 300)
        #expect(controller.pomodoro.restRemaining == 300)
        controller.selectMode(view)
        controller.adjustTimerDuration(steps: -1)
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == 300)
        controller.selectMode(view)
        session.now += 180
        controller.update()
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == 300)
        controller.selectMode(view)
        controller.adjustTimerDuration(steps: 1)
        let total = controller.timer.remaining
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.focusRemaining == total - 300)
        #expect(controller.pomodoro.restRemaining == 300)
        #expect(controller.pomodoro.restDuration == 300)
        controller.save()
        let restored = session.makeController()
        #expect(restored.pomodoro.focusRemaining == total - 300)
        #expect(restored.pomodoro.restRemaining == 300)
        #expect(restored.timer.remaining == total)
        session.now += total
        restored.update()
        #expect(restored.pomodoro.stage == 2)
        #expect(restored.pomodoro.restRemaining == 300)
    }

    @Test(arguments: [CountdownMode.timer, .countdown])
    func longRestSurvivesTheHourLimit(view: CountdownMode) {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Date(timeIntervalSince1970: 1_699_999_800)
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now += 3 * 1_800
        controller.update()
        #expect(controller.pomodoro.stage == 4)
        controller.adjustPomodoroDuration(.focus, by: 600)
        controller.adjustPomodoroDuration(.longRest, by: 2_100)
        #expect(controller.timer.remaining == 5_100)
        controller.selectMode(view)
        #expect(controller.timer.remaining == 3_600)
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.focusRemaining == 600)
        #expect(controller.pomodoro.restRemaining == 3_000)
        #expect(controller.pomodoro.longRestDuration == 3_000)
        #expect(controller.pomodoro.stage == 4)
        controller.save()
        let restored = session.makeController()
        #expect(restored.timer.remaining == 3_600)
        #expect(restored.pomodoro.restRemaining == 3_000)
    }

    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func restOnlyTimeSurvivesRestart(view: CountdownMode, paused: Bool) {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Date(timeIntervalSince1970: 1_699_999_800)
        let controller = session.controller
        controller.selectMode(view)
        controller.adjustTimerDuration(steps: 2)
        controller.adjustTimerDuration(steps: -1)
        session.now += 270
        controller.update()
        if paused { controller.toggleRunning() }
        controller.save()
        session.now += 10
        let restored = session.makeController()
        let remaining: TimeInterval = paused ? 30 : 20
        #expect(restored.timer.remaining == remaining)
        restored.selectMode(.pomodoro)
        #expect(restored.pomodoro.focusRemaining == 0)
        #expect(restored.pomodoro.restRemaining == 300)
        #expect(restored.timer.remaining == 300)
        #expect(restored.engine.isPaused == paused)
    }

    @Test
    func pomodoroEditsUpdateTheTotalAndInactivePomodoroDoesNotRepeat() {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Date(timeIntervalSince1970: 1_699_999_800)
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: 1)
        #expect(controller.timer.remaining == 2_100)
        controller.adjustPomodoroDuration(.rest, steps: 1)
        #expect(controller.timer.remaining == 2_400)
        controller.selectMode(.countdown)
        session.now += 10_000
        controller.update()
        #expect(controller.timer.remaining == 0)
        #expect(controller.timer.completionCount == 1)
        #expect(controller.pomodoro.stage == 1)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == 0)
        controller.save()
        let restored = session.makeController()
        #expect(restored.timer.remaining == 0)
        #expect(restored.pomodoro.stage == 1)
    }
}
