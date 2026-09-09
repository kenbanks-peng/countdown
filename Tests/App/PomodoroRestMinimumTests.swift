import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroRestMinimumTests {
    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func conversionReservesFiveMinutesOfRest(view: CountdownMode, paused: Bool) {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(view)
        controller.adjustTimerDuration(by: 600)
        controller.adjustTimerDuration(by: -480)
        if paused { controller.toggleRunning() }
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.restRemaining == 300)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.timer.remaining == 300)
        #expect(controller.engine.isPaused == paused)
    }

    @Test(arguments: [1, 4], [false, true])
    func conversionRepairsZeroRestWithoutIncreasingTheTotal(stage: Int, paused: Bool) throws {
        let session = ClockTestSession(clock: false)
        defer { session.close() }
        let store = TimerSessionStore(environment: ["XDG_STATE_HOME": session.directory.path])
        let end = session.now + 600
        let schedule = PomodoroClockSchedule(
            stageStart: session.now, focusEnd: end,
            restEnd: stage == 1 ? end : end + 300,
            longRestEnd: stage == 4 ? end : end + 900,
            sampledAt: session.now, pausedAt: paused ? session.now : nil,
            stage: stage, focusCompleted: false,
            restCarry: stage == 1 ? 300 : nil, longRestCarry: stage == 4 ? 900 : nil
        )
        CountdownSettingsStore(fileManager: .default, stateDirectory: store.stateDirectory).save(
            CountdownSettings(mode: .countdown, isPaused: paused, pomodoroClockSchedule: schedule)
        )
        store.save(TimerSession(status: paused ? .prepared : .active, duration: 600,
                                remaining: 600, endDate: paused ? nil : end, savedAt: session.now))
        let controller = session.controller
        #expect(controller.pomodoro.restRemaining == 0)
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.focusRemaining == 300)
        #expect(controller.pomodoro.restRemaining == 300)
        #expect(controller.timer.remaining == 600)
        #expect(controller.pomodoro.stage == stage)
        #expect(controller.engine.isPaused == paused)
        controller.save()
        let restored = session.makeController()
        #expect(restored.pomodoro.restRemaining == 300)
        #expect(restored.timer.remaining == 600)
        let repaired = try #require(restored.pomodoro.clockSchedule)
        #expect(repaired.isValid(focusPeriodsPerCycle: 4))
    }

    @Test(arguments: [PomodoroModel.Phase.rest, .longRest], [false, true])
    func restMinimumStillAppliesAfterALongRestAllocation(phase: PomodoroModel.Phase, amountEdit: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        if phase == .longRest { session.now += 5_400 }
        controller.update()
        if phase == .rest {
            let focusEnd = try #require(controller.pomodoro.clockSchedule).focusEnd
            session.now = focusEnd
            controller.update()
        }
        controller.adjustPomodoroDuration(phase, by: 10_000)
        let before = try #require(controller.pomodoro.clockSchedule)
        session.now = before.end(for: phase) - 60
        controller.update()
        if amountEdit { controller.adjustPomodoroDuration(phase, by: -60) }
        else { controller.adjustPomodoroDuration(phase, steps: -1) }
        #expect(controller.pomodoro.stage == before.stage)
        #expect(controller.pomodoro.restRemaining >= 300)
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.isValid(focusPeriodsPerCycle: 4))
        if !amountEdit { expectClockMark(after.end(for: phase)) }
    }

    @Test(arguments: [PomodoroModel.Phase.rest, .longRest], 0..<4)
    func restEditLeavesFiveMinutesFromCurrentTime(phase: PomodoroModel.Phase, variant: Int) throws {
        let amountEdit = variant & 1 != 0
        let paused = variant & 2 != 0
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.setAutoRepeatEnabled(true)
        controller.selectMode(.pomodoro)
        if phase == .longRest { session.now += 5_400 }
        controller.update()
        let before = try #require(controller.pomodoro.clockSchedule)
        session.now = before.end(for: phase) - 60
        controller.update()
        #expect(controller.pomodoro.restRemaining == 60)
        if paused {
            controller.toggleRunning()
            session.now += 120
        }
        if amountEdit { controller.adjustPomodoroDuration(phase, by: -60) }
        else { controller.adjustPomodoroDuration(phase, steps: -1) }
        #expect(controller.pomodoro.stage == before.stage)
        #expect(controller.pomodoro.restRemaining >= 300)
        #expect(controller.engine.isPaused == paused)
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.isValid(focusPeriodsPerCycle: 4))
        if !amountEdit { expectClockMark(after.end(for: phase)) }
        if paused { controller.toggleRunning() }
        let remaining = controller.pomodoro.restRemaining
        session.now += remaining - 1
        controller.update()
        #expect(controller.pomodoro.stage == before.stage)
        #expect(controller.pomodoro.restRemaining == 1)
        session.now += 1
        controller.update()
        #expect(controller.pomodoro.stage == (before.stage == 4 ? 1 : before.stage + 1))
    }
}
