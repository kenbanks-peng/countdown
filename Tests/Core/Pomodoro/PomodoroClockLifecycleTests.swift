import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroClockLifecycleTests {
    @Test(arguments: [false, true])
    func pauseFreezesEndpointsAndResumePreservesDurations(inRest: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(steps: 8)
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, steps: 3)
        if inRest { session.now += 1_550 }
        controller.toggleRunning()
        let paused = session.now
        let focus = controller.pomodoro.focusRemaining
        let rest = controller.pomodoro.restRemaining
        let timerRemaining = controller.timer.remaining
        let before = try #require(controller.pomodoro.clockSchedule)
        let timerEnd = controller.timer.endDate
        session.now += 150
        controller.update()
        #expect(controller.pomodoro.focusRemaining == focus)
        #expect(controller.pomodoro.restRemaining == rest)
        #expect(controller.timer.remaining == timerRemaining)
        #expect(controller.timer.endDate == timerEnd)
        controller.adjustPomodoroDuration(.longRest, steps: 1)
        let edited = try #require(controller.pomodoro.clockSchedule)
        #expect(edited.focusEnd == before.focusEnd)
        #expect(edited.restEnd == before.restEnd)
        session.now += 163
        controller.toggleRunning()
        let resumed = try #require(controller.pomodoro.clockSchedule)
        for phase: PomodoroModel.Phase in [.focus, .rest, .longRest] {
            let expected = edited.end(for: phase) + session.now.timeIntervalSince(paused)
            #expect(resumed.end(for: phase) == expected)
        }
        #expect(controller.timer.endDate == resumed.restEnd)
        #expect(controller.timer.remaining == timerRemaining)
        #expect(controller.pomodoro.focusRemaining == focus)
        #expect(controller.pomodoro.restRemaining == rest)
        session.now += 150
        controller.adjustPomodoroDuration(.longRest, steps: -1)
        #expect(controller.pomodoro.clockSchedule?.focusEnd == resumed.focusEnd)
        #expect(controller.pomodoro.clockSchedule?.restEnd == resumed.restEnd)
    }

    @Test
    func resumePreservesCompletedFocusAndRestProgress() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now = try #require(controller.pomodoro.clockSchedule).focusEnd + 10
        controller.toggleRunning()
        session.now += 60
        controller.toggleRunning()
        let resumed = try #require(controller.pomodoro.clockSchedule)
        #expect(resumed.focusEnd == session.now - 10)
        #expect(controller.pomodoro.focusRemaining == 0)
        let remaining = resumed.restEnd.timeIntervalSince(session.now)
        #expect(controller.pomodoro.restRemaining == remaining)
        controller.selectMode(.countdown)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == remaining)
        session.now += 30
        controller.update()
        #expect(controller.pomodoro.restRemaining == remaining - 30)
    }

    @Test(arguments: [1, 4])
    func endpointEditsPreserveFocusDurationForFollowingCycles(startMinute: Int) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let four = Calendar.current.startOfDay(for: session.now) + 4 * 3_600
        session.now = four + Double(startMinute) * 60
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: 1)
        let selected = try #require(controller.pomodoro.clockSchedule)
        #expect(selected.focusEnd == four + 30 * 60)
        #expect(selected.restEnd == four + 35 * 60)
        #expect(selected.focusDuration == Double(30 - startMinute) * 60)

        let repeatedFocus = selected.focusDuration
        for expectedStage in [2, 3, 4, 1, 2] {
            let previous = try #require(controller.pomodoro.clockSchedule)
            let nextStart = previous.end(for: controller.pomodoro.restPhase)
            session.now = nextStart
            controller.update()
            let next = try #require(controller.pomodoro.clockSchedule)
            #expect(next.stage == expectedStage)
            #expect(next.stageStart == nextStart)
            #expect(next.focusEnd == nextStart + repeatedFocus)
            #expect(next.restEnd == next.focusEnd + 5 * 60)
            #expect(next.longRestEnd == next.focusEnd + 15 * 60)
            #expect(controller.pomodoro.restPhase == (expectedStage == 4 ? .longRest : .rest))
        }
    }

    @Test
    func stageAndCycleRepeatsUseTheSelectedSpacing() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: -1)
        session.now += 150
        controller.adjustPomodoroDuration(.rest, steps: 2)
        session.now += 150
        controller.adjustPomodoroDuration(.longRest, steps: 2)
        let selected = try #require(controller.pomodoro.clockSchedule)
        let repeatedFocus = selected.focusDuration
        for expectedStage in [2, 3, 4, 1, 2] {
            let previous = try #require(controller.pomodoro.clockSchedule)
            session.now = previous.end(for: controller.pomodoro.restPhase)
            controller.update()
            let next = try #require(controller.pomodoro.clockSchedule)
            #expect(controller.pomodoro.stage == expectedStage)
            #expect(next.stageStart == session.now)
            #expect(next.focusDuration == repeatedFocus)
            #expect(next.restDuration == selected.restDuration)
            #expect(next.longRestDuration == selected.longRestDuration)
            #expect(next.focusEnd == next.stageStart + selected.focusDuration)
        }
        let beforeSleep = try #require(controller.pomodoro.clockSchedule)
        session.now += controller.pomodoro.cycleDuration * 10_000 + 150
        controller.update()
        #expect(controller.pomodoro.stage == beforeSleep.stage)
        #expect(controller.pomodoro.focusRemaining == repeatedFocus - 150)
    }

    @Test
    func lateClockUpdatesMatchSteppedUpdatesFromAnUnalignedStart() throws {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 2, second: 13))!
        var late = PomodoroModel()
        late.toggleRunning(at: start)
        late.setClockEnabled(true, at: start)
        var stepped = late
        for seconds in stride(from: 60, through: 80_040, by: 60) {
            stepped.update(at: start + Double(seconds))
        }
        late.update(at: start + 80_040)
        #expect(late.stage == stepped.stage)
        #expect(late.focusRemaining == stepped.focusRemaining)
        #expect(late.restRemaining == stepped.restRemaining)
        let schedule = try #require(late.clockSchedule)
        #expect(schedule.focusDuration == 1_500)
        #expect(schedule.restDuration == 300)
        #expect(schedule.longRestDuration == 1_200)
        for phase: PomodoroModel.Phase in [.focus, .rest, .longRest] {
            #expect(schedule.end(for: phase) == stepped.clockSchedule?.end(for: phase))
        }
    }

    @Test(arguments: [false, true])
    func restartRetainsAbsoluteSettingsAndPauseReference(paused: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(steps: 6)
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: -1)
        session.now += 150
        controller.adjustPomodoroDuration(.rest, steps: 2)
        session.now += 150
        controller.adjustPomodoroDuration(.longRest, steps: 2)
        if paused { controller.toggleRunning() }
        controller.save()
        let schedule = try #require(controller.pomodoro.clockSchedule)
        let timerEnd = controller.timer.endDate
        let remaining = controller.pomodoro.focusRemaining
        session.now += paused ? 7_200 : 150
        let restored = session.makeController()
        let after = try #require(restored.pomodoro.clockSchedule)
        #expect(after.focusEnd == schedule.focusEnd)
        #expect(after.restEnd == schedule.restEnd)
        #expect(after.longRestEnd == schedule.longRestEnd)
        #expect(after.pausedAt == schedule.pausedAt)
        #expect(restored.timer.endDate == timerEnd)
        #expect(restored.pomodoro.focusRemaining == remaining - (paused ? 0 : 150))
        if paused {
            restored.toggleRunning()
            expectClockMark(try #require(restored.timer.endDate))
            expectClockMark(try #require(restored.pomodoro.clockSchedule).focusEnd)
        }
    }
}
