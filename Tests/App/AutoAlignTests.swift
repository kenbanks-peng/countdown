import Foundation
import Testing
@testable import Countdown

@MainActor
struct AutoAlignTests {
    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func timerAlignmentKeepsRunStateAndPersists(mode: CountdownMode, paused: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(mode)
        controller.adjustTimerDuration(by: 3_000)
        if paused { controller.toggleRunning() }
        session.now += 60
        controller.autoAlign()
        #expect(controller.timer.remaining == 1_606.75)
        #expect(controller.timer.repeatDuration == 3_000)
        #expect(controller.engine.isPaused == paused)
        #expect(controller.timer.isPaused == paused)
        #expect(controller.timer.remaining == controller.pomodoro.focusRemaining + controller.pomodoro.restRemaining)
        let restored = session.makeController()
        #expect(restored.mode == mode)
        #expect(restored.timer.remaining == controller.timer.remaining)
        #expect(restored.timer.repeatDuration == controller.timer.repeatDuration)
        #expect(restored.engine.isPaused == paused)
        if paused {
            session.now += 60
            restored.toggleRunning()
            #expect(restored.timer.remaining == 1_606.75)
            #expect(restored.timer.endDate == session.now + 1_606.75)
        }
    }

    @Test(arguments: [CountdownMode.timer, .countdown], [0.0, 0.25])
    func emptyTimerAlignmentLeavesAtLeastFiveMinutes(mode: CountdownMode, fraction: TimeInterval) {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Calendar.current.date(from: DateComponents(
            year: 2026, month: 1, day: 15, hour: 10, minute: 25
        ))! + fraction
        let controller = session.controller
        controller.selectMode(mode)
        #expect(controller.timer.remaining == 0)
        controller.autoAlign()
        #expect(controller.timer.remaining == (fraction == 0 ? 300 : 2_099.75))
        #expect(controller.timer.status == .active)
        #expect(controller.timer.completionCount == 0)
        let remaining = controller.timer.remaining
        controller.autoAlign()
        #expect(controller.timer.remaining == (fraction == 0 ? 2_100 : remaining))
    }

    @Test(arguments: CountdownMode.allCases, [false, true])
    func repeatedAlignmentSwitchesEndpointsWhileTimeAdvances(mode: CountdownMode, paused: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(mode)
        if paused { controller.toggleRunning() }
        controller.autoAlign()
        let first = session.now + controller.timer.remaining
        let repeatDuration = controller.timer.repeatDuration
        for offset in [1_800.0, 0, 1_800, 0] {
            session.now += 1.25
            controller.autoAlign()
            #expect(session.now + controller.timer.remaining == first + offset)
            #expect(controller.engine.isPaused == paused)
            #expect(controller.timer.remaining == controller.pomodoro.focusRemaining + controller.pomodoro.restRemaining)
            if mode == .pomodoro {
                #expect(controller.pomodoro.restDuration == 300)
                #expect(controller.pomodoro.stage == 1)
                let schedule = try #require(controller.pomodoro.clockSchedule)
                #expect(schedule.isValid(focusPeriodsPerCycle: controller.pomodoro.focusPeriodsPerCycle))
            } else {
                #expect(controller.timer.repeatDuration == repeatDuration)
            }
        }
    }
}
