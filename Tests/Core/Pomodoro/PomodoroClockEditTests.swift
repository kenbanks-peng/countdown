import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroClockEditTests {
    @Test(arguments: [PomodoroModel.Phase.focus, .rest, .longRest], [-1, 1])
    func delayedEditsMoveRestEndpointsOnlyWithFocus(phase: PomodoroModel.Phase, steps: Int) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: -1)
        controller.adjustPomodoroDuration(.rest, steps: 2)
        controller.adjustPomodoroDuration(.longRest, steps: 2)
        let phases: [PomodoroModel.Phase] = [.focus, .rest, .longRest]
        for selected in phases where selected != phase {
            controller.adjustPomodoroDuration(selected, steps: steps)
            let before = try #require(controller.pomodoro.clockSchedule)
            session.now += 150
            controller.adjustPomodoroDuration(phase, steps: steps)
            let after = try #require(controller.pomodoro.clockSchedule)
            let shift = phase == .focus ? after.focusEnd.timeIntervalSince(before.focusEnd) : 0
            for other in phases where other != phase {
                #expect(after.end(for: other) == before.end(for: other) + shift)
            }
            if phase == .focus {
                #expect(after.restDuration == before.restDuration)
                #expect(after.longRestDuration == before.longRestDuration)
            }
            expectClockMark(after.end(for: phase))
            #expect(controller.pomodoro.focusRemaining == max(0, after.focusEnd.timeIntervalSince(session.now)))
            #expect(controller.pomodoro.restRemaining == after.restEnd.timeIntervalSince(after.focusEnd))
        }
    }

    @Test(arguments: [PomodoroModel.Phase.rest, .longRest], [-1, 1])
    func elapsedFocusEditsMoveRestButHiddenRestEditsKeepItsEndpoint(rest: PomodoroModel.Phase, steps: Int) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        if rest == .longRest { session.now += 5_400 }
        controller.update()
        controller.adjustPomodoroDuration(rest, steps: 2)
        let before = try #require(controller.pomodoro.clockSchedule)
        session.now = before.focusEnd + 150
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == before.end(for: rest).timeIntervalSince(session.now))
        controller.adjustPomodoroDuration(.focus, steps: steps)
        let focusEdit = try #require(controller.pomodoro.clockSchedule)
        #expect(focusEdit.restDuration == before.restDuration)
        #expect(focusEdit.longRestDuration == before.longRestDuration)
        session.now += 150
        controller.adjustPomodoroDuration(rest == .rest ? .longRest : .rest, steps: 1)
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.end(for: rest) == focusEdit.end(for: rest))
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == focusEdit.end(for: rest).timeIntervalSince(session.now))
    }

    @Test
    func crossingRequestsClampAndKeepRestDurationsOnFocusEdits() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, steps: 1)
        let before = try #require(controller.pomodoro.clockSchedule)
        controller.adjustPomodoroDuration(.focus, steps: 100)
        let focusEdit = try #require(controller.pomodoro.clockSchedule)
        #expect(focusEdit.restDuration == before.restDuration)
        #expect(focusEdit.longRestDuration == before.longRestDuration)
        #expect(focusEdit.focusEnd > before.focusEnd)
        #expect(focusEdit.isValid(focusPeriodsPerCycle: controller.pomodoro.focusPeriodsPerCycle))
        #expect(focusEdit.restEnd <= before.stageStart + 3_600)
        controller.adjustPomodoroDuration(.rest, steps: -100)
        let restEdit = try #require(controller.pomodoro.clockSchedule)
        #expect(restEdit.focusEnd == focusEdit.focusEnd)
        #expect(restEdit.longRestEnd == focusEdit.longRestEnd)
        #expect(restEdit.restEnd > restEdit.focusEnd)
        expectClockMark(restEdit.restEnd)
    }

    @Test(arguments: [false, true], [-1, 1])
    func focusAmountEditsKeepBothRestDurationsWhileRunningOrPaused(paused: Bool, direction: Int) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now += 150
        if paused { controller.toggleRunning() }
        let before = try #require(controller.pomodoro.clockSchedule)
        session.now += 150
        controller.adjustPomodoroDuration(.focus, by: Double(direction) * 300)
        let after = try #require(controller.pomodoro.clockSchedule)
        let shift = after.focusEnd.timeIntervalSince(before.focusEnd)
        #expect(shift * Double(direction) > 0)
        #expect(after.restEnd == before.restEnd + shift)
        #expect(after.longRestEnd == before.longRestEnd + shift)
        #expect(after.restDuration == before.restDuration)
        #expect(after.longRestDuration == before.longRestDuration)
        #expect(controller.pomodoro.restRemaining == before.restDuration)
        #expect(after.pausedAt == before.pausedAt)
        #expect(after.isValid(focusPeriodsPerCycle: controller.pomodoro.focusPeriodsPerCycle))
        expectClockMark(after.focusEnd)
    }

    @Test
    func displayChangesPreserveProgressIncludingCompletedFocus() throws {
        let session = ClockTestSession(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(by: 2_713.25)
        controller.selectMode(.pomodoro)
        session.now += 1_600
        controller.adjustPomodoroDuration(.focus, by: 300)
        let before = controller.pomodoro
        let timerRemaining = controller.timer.remaining
        controller.selectMode(.timer)
        controller.update()
        #expect(controller.pomodoro.focusRemaining == before.focusRemaining)
        #expect(controller.pomodoro.restRemaining == before.restRemaining)
        #expect(controller.timer.remaining == timerRemaining)
        let schedule = try #require(controller.pomodoro.clockSchedule)
        session.now += 150
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.clockSchedule?.restEnd == schedule.restEnd)
        controller.selectMode(.countdown)
        controller.toggleRunning()
        let frozen = controller.pomodoro.restRemaining
        session.now += 300
        controller.toggleRunning()
        #expect(controller.pomodoro.restRemaining == frozen)
    }
}
