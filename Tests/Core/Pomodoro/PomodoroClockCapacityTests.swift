import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroClockCapacityTests {
    @Test
    func normalRestAloneLimitsFocusAndLongRestDisplayGrowsWithTime() throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Calendar.current.startOfDay(for: session.now)
        let controller = session.controller
        controller.setAutoRepeatEnabled(true)
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: 100)
        let selected = try #require(controller.pomodoro.clockSchedule)
        #expect(selected.focusDuration == 3_300)
        #expect(selected.restDuration == 300)
        #expect(selected.longRestDuration == 900)
        #expect(selected.isValid(focusPeriodsPerCycle: controller.pomodoro.focusPeriodsPerCycle))
        session.now += 3 * 3_600
        controller.update()
        let last = try #require(controller.pomodoro.clockSchedule)
        #expect(controller.pomodoro.restPhase == .longRest)
        #expect(last.longRestDuration == 900)
        for elapsed in [0.0, 300, 600] {
            let arcs = CountdownArcLayout.pomodoro(
                focusRemaining: 0, restRemaining: 0, restDuration: 900,
                at: session.now + elapsed, schedule: last, restPhase: .longRest
            )
            #expect(abs(arcs.rest.proportion * 3_600 - (300 + elapsed)) < 1e-6)
            #expect(abs(arcs.focus.proportion + arcs.rest.proportion - 1) < 1e-6)
        }
        controller.save()
        let restored = session.makeController()
        #expect(restored.pomodoro.focusDuration == 3_300)
        #expect(restored.pomodoro.longRestDuration == 900)
        controller.toggleRunning()
        session.now += 300
        controller.toggleRunning()
        let resumed = try #require(controller.pomodoro.clockSchedule)
        #expect(resumed.focusDuration == 3_300)
        #expect(resumed.longRestDuration == 900)
        session.now = resumed.longRestEnd - 1
        controller.update()
        #expect(controller.pomodoro.stage == 4)
        #expect(controller.pomodoro.restRemaining == 1)
        session.now += 1
        controller.update()
        #expect(controller.pomodoro.stage == 1)
        #expect(controller.pomodoro.focusRemaining == 3_300)
        #expect(controller.pomodoro.longRestDuration == 900)
    }

    @Test(arguments: [8.0, 10.0, 15.0], [false, true])
    func elapsedTimeReleasesClockCapacity(elapsedMinutes: Double, paused: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let start = Calendar.current.startOfDay(for: session.now) + 3 * 3_600 + 10 * 60
        session.now = start
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: 100)
        session.now += elapsedMinutes * 60
        controller.update()
        #expect(controller.pomodoro.focusRemaining + controller.pomodoro.restRemaining == (60 - elapsedMinutes) * 60)
        if paused {
            controller.toggleRunning()
            session.now += 7 * 60
        }
        let before = try #require(controller.pomodoro.clockSchedule)
        controller.adjustPomodoroDuration(.focus, steps: 1)
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.focusEnd == before.focusEnd + 300)
        #expect(after.restEnd == before.restEnd + 300)
        #expect(after.longRestEnd == before.longRestEnd + 300)
        #expect(controller.pomodoro.focusRemaining + controller.pomodoro.restRemaining == (65 - elapsedMinutes) * 60)
        #expect(after.isValid(focusPeriodsPerCycle: controller.pomodoro.focusPeriodsPerCycle))
        expectClockMark(after.focusEnd)

        controller.adjustPomodoroDuration(.focus, steps: 100)
        let maximum = try #require(controller.pomodoro.clockSchedule)
        let expectedRestEnd = start + floor(elapsedMinutes / 5) * 300 + 3_600
        #expect(maximum.restEnd == expectedRestEnd)
        #expect(maximum.focusEnd == expectedRestEnd - 300)
        #expect(maximum.longRestDuration == 900)
        let reference = maximum.pausedAt ?? session.now
        #expect(maximum.restEnd <= reference + 3_600)
        #expect(maximum.restEnd + 300 > reference + 3_600)
        controller.adjustPomodoroDuration(.focus, steps: 1)
        #expect(controller.pomodoro.clockSchedule?.focusEnd == maximum.focusEnd)
        controller.save()
        let restored = session.makeController()
        #expect(restored.pomodoro.clockSchedule?.focusEnd == maximum.focusEnd)
        #expect(restored.pomodoro.clockSchedule?.restEnd == maximum.restEnd)
        #expect(restored.pomodoro.longRestDuration == 900)
        #expect(restored.pomodoro.focusRemaining == controller.pomodoro.focusRemaining)
        if paused { restored.toggleRunning() }
        let running = try #require(restored.pomodoro.clockSchedule)
        session.now = running.restEnd
        restored.update()
        #expect(restored.pomodoro.stage == 2)
        #expect(restored.pomodoro.focusDuration + restored.pomodoro.restDuration <= 3_600)
        #expect(restored.pomodoro.longRestDuration == 900)
    }

    @Test
    func normalRestCanUseElapsedClockSpaceWithoutMovingFocus() throws {
        let session = ClockTestSession()
        defer { session.close() }
        session.now = Calendar.current.startOfDay(for: session.now) + 3 * 3_600 + 10 * 60
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: 100)
        session.now += 15 * 60
        controller.update()
        let before = try #require(controller.pomodoro.clockSchedule)
        controller.adjustPomodoroDuration(.rest, by: 3_600)
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.focusEnd == before.focusEnd)
        #expect(after.longRestEnd == before.longRestEnd)
        #expect(after.restEnd == session.now + 3_600)
        #expect(after.isValid(focusPeriodsPerCycle: controller.pomodoro.focusPeriodsPerCycle))
        expectClockMark(after.restEnd)
    }

    @Test(arguments: [false, true], [false, true])
    func focusEditLeavesFiveMinutesFromCurrentTime(paused: Bool, amountEdit: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let start = Calendar.current.startOfDay(for: session.now) + 3 * 3_600
        session.now = start
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now = start + 9 * 60
        controller.update()
        if paused {
            controller.toggleRunning()
            session.now += 7 * 60
        }
        // Request 3:10 from the initial 3:25 endpoint while the time is 3:09.
        if amountEdit {
            controller.adjustPomodoroDuration(.focus, by: -900)
        } else {
            controller.adjustPomodoroDuration(.focus, steps: -3)
        }
        let schedule = try #require(controller.pomodoro.clockSchedule)
        let endMinutes: TimeInterval = amountEdit ? 14 : 15
        #expect(schedule.focusEnd == start + endMinutes * 60)
        #expect(controller.pomodoro.focusRemaining == (endMinutes - 9) * 60)
        #expect(schedule.restDuration == 300)
        #expect(schedule.longRestDuration == 900)
        if !amountEdit { expectClockMark(schedule.focusEnd) }
        // Time passing must not move the selected endpoint to enforce an edit limit.
        if !paused {
            session.now = start + 11 * 60
            controller.update()
            #expect(controller.pomodoro.focusRemaining == (endMinutes - 11) * 60)
            #expect(controller.pomodoro.clockSchedule?.focusEnd == schedule.focusEnd)
        }
    }

    @Test
    func clockEditsKeepFiveMinuteMinimumAtAnUnalignedStart() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: -100)
        controller.adjustPomodoroDuration(.rest, steps: -100)
        controller.adjustPomodoroDuration(.longRest, steps: -100)
        let schedule = try #require(controller.pomodoro.clockSchedule)
        #expect(schedule.focusDuration >= 300)
        #expect(schedule.restDuration >= 300)
        #expect(schedule.longRestDuration >= 300)
        for phase: PomodoroModel.Phase in [.focus, .rest, .longRest] {
            expectClockMark(schedule.end(for: phase))
        }
    }
}
