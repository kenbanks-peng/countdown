import Foundation
import Testing
@testable import Countdown

@MainActor
struct ClockEndpointScheduleTests {
    @Test(arguments: [PomodoroModel.Phase.focus, .rest, .longRest], [-1, 1])
    func delayedEditsKeepEveryOtherEndpoint(phase: PomodoroModel.Phase, steps: Int) throws {
        let session = Session()
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
            for other in phases where other != phase {
                #expect(after.end(for: other) == before.end(for: other))
            }
            expectMark(after.end(for: phase))
            #expect(controller.pomodoro.focusRemaining == max(0, after.focusEnd.timeIntervalSince(session.now)))
            #expect(controller.pomodoro.restRemaining == after.restEnd.timeIntervalSince(after.focusEnd))
        }
    }

    @Test(arguments: [PomodoroModel.Phase.rest, .longRest], [-1, 1])
    func elapsedFocusAndHiddenPhaseEditsKeepTheActiveRestEndpoint(rest: PomodoroModel.Phase, steps: Int) throws {
        let session = Session()
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
        session.now += 150
        controller.adjustPomodoroDuration(rest == .rest ? .longRest : .rest, steps: 1)
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.end(for: rest) == before.end(for: rest))
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == before.end(for: rest).timeIntervalSince(session.now))
    }

    @Test
    func crossingRequestsClampWithoutMovingOtherSettings() throws {
        let session = Session()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, steps: 1)
        let before = try #require(controller.pomodoro.clockSchedule)
        controller.adjustPomodoroDuration(.focus, steps: 100)
        let focusEdit = try #require(controller.pomodoro.clockSchedule)
        #expect(focusEdit.restEnd == before.restEnd)
        #expect(focusEdit.longRestEnd == before.longRestEnd)
        #expect(focusEdit.focusEnd < min(before.restEnd, before.longRestEnd))
        controller.adjustPomodoroDuration(.rest, steps: -100)
        let restEdit = try #require(controller.pomodoro.clockSchedule)
        #expect(restEdit.focusEnd == focusEdit.focusEnd)
        #expect(restEdit.longRestEnd == before.longRestEnd)
        #expect(restEdit.restEnd > restEdit.focusEnd)
        expectMark(restEdit.restEnd)
    }

    @Test(arguments: [false, true])
    func pauseFreezesEndpointsAndResumeSnapsOnce(inRest: Bool) throws {
        let session = Session()
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
            #expect(abs(resumed.end(for: phase).timeIntervalSince(expected)) <= 150)
            expectMark(resumed.end(for: phase))
        }
        expectMark(try #require(controller.timer.endDate))
        #expect(abs(controller.timer.remaining - timerRemaining) <= 150)
        #expect(abs(controller.pomodoro.focusRemaining - focus) <= 150)
        #expect(abs(controller.pomodoro.restRemaining - rest) <= 300)
        session.now += 150
        controller.adjustPomodoroDuration(.longRest, steps: -1)
        #expect(controller.pomodoro.clockSchedule?.focusEnd == resumed.focusEnd)
        #expect(controller.pomodoro.clockSchedule?.restEnd == resumed.restEnd)
    }

    @Test
    func resumeDoesNotRestartCompletedFocusWhenRoundingMovesItsEndForward() throws {
        let session = Session()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now = try #require(controller.pomodoro.clockSchedule).focusEnd + 10
        controller.toggleRunning()
        session.now += 60
        controller.toggleRunning()
        let resumed = try #require(controller.pomodoro.clockSchedule)
        #expect(resumed.focusEnd > session.now)
        #expect(controller.pomodoro.focusRemaining == 0)
        let remaining = resumed.restEnd.timeIntervalSince(session.now)
        #expect(controller.pomodoro.restRemaining == remaining)
        controller.features.setClockEnabled(false)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == remaining)
        session.now += 30
        controller.update()
        #expect(controller.pomodoro.restRemaining == remaining - 30)
    }

    @Test
    func pausedTimerEditUsesItsFrozenClockReference() throws {
        let session = Session()
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(steps: 4)
        controller.toggleRunning()
        let end = try #require(controller.timer.endDate)
        let frozen = controller.timer.remaining
        session.now += 150
        controller.adjustTimerDuration(steps: 1)
        #expect(controller.timer.endDate == end + 300)
        #expect(controller.timer.remaining == frozen + 300)
        let edited = try #require(controller.timer.endDate)
        session.now += 160
        controller.toggleRunning()
        #expect(abs(try #require(controller.timer.endDate).timeIntervalSince(edited + 310)) <= 150)
        expectMark(try #require(controller.timer.endDate))
    }

    @Test
    func stageAndCycleRepeatsUseTheSelectedSpacing() throws {
        let session = Session()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: -1)
        session.now += 150
        controller.adjustPomodoroDuration(.rest, steps: 2)
        session.now += 150
        controller.adjustPomodoroDuration(.longRest, steps: 2)
        let selected = try #require(controller.pomodoro.clockSchedule)
        let repeatedFocus = (selected.focusDuration / 300).rounded() * 300
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
            for phase: PomodoroModel.Phase in [.focus, .rest, .longRest] {
                expectMark(next.end(for: phase))
            }
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
        for phase: PomodoroModel.Phase in [.focus, .rest, .longRest] {
            expectMark(schedule.end(for: phase))
        }
    }

    @Test(arguments: [false, true])
    func restartRetainsAbsoluteSettingsAndPauseReference(paused: Bool) throws {
        let session = Session()
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
            expectMark(try #require(restored.timer.endDate))
            expectMark(try #require(restored.pomodoro.clockSchedule).focusEnd)
        }
    }

    @Test
    func nextHourAutosetAndMidnightUseAbsoluteEndpoints() throws {
        let session = Session()
        defer { session.close() }
        session.now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 23, minute: 57, second: 13))!
        let controller = session.controller
        controller.setTimerToNextHour()
        let midnight = try #require(controller.timer.endDate)
        #expect(Calendar.current.component(.day, from: midnight) == 16)
        #expect(Calendar.current.component(.hour, from: midnight) == 0)
        controller.timer.setAutosetEnabled(true)
        session.now = midnight
        controller.update()
        #expect(controller.timer.endDate == midnight + 3_600)
        controller.toggleRunning()
        session.now += 150
        controller.setTimerToNextHour()
        #expect(controller.timer.endDate == midnight + 3_600)
        #expect(controller.timer.remaining == 3_450)
        #expect(controller.timer.isPaused)
    }

    @Test
    func displayChangesPreserveProgressIncludingCompletedFocus() throws {
        let session = Session(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(by: 2_713.25)
        controller.selectMode(.pomodoro)
        session.now += 1_600
        controller.adjustPomodoroDuration(.focus, by: 300)
        let before = controller.pomodoro
        let timerRemaining = controller.timer.remaining
        controller.features.setClockEnabled(true)
        controller.update()
        #expect(controller.pomodoro.focusRemaining == before.focusRemaining)
        #expect(controller.pomodoro.restRemaining == before.restRemaining)
        #expect(controller.timer.remaining == timerRemaining)
        let schedule = try #require(controller.pomodoro.clockSchedule)
        controller.selectMode(.timer)
        session.now += 150
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.clockSchedule?.restEnd == schedule.restEnd)
        controller.features.setClockEnabled(false)
        controller.toggleRunning()
        let frozen = controller.pomodoro.restRemaining
        session.now += 173
        controller.toggleRunning()
        #expect(controller.pomodoro.restRemaining == frozen)
    }

    private func expectMark(_ date: Date, sourceLocation: SourceLocation = #_sourceLocation) {
        let seconds = date.timeIntervalSince(Calendar.current.startOfDay(for: date))
        #expect(abs(seconds - (seconds / 300).rounded() * 300) < 1e-6, sourceLocation: sourceLocation)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 2, second: 13))!.addingTimeInterval(0.25)
        let clock: Bool
        lazy var controller = makeController()
        init(clock: Bool = true) { self.clock = clock }
        func makeController() -> CountdownController {
            CountdownController(
                stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
                configuration: CountdownConfiguration(alarmNotificationURL: nil),
                featureState: CountdownFeatureState(clockEnabled: clock, popupEnabled: false),
                playSound: { _ in }, now: { [unowned self] in now }, saveEnablement: { _, _ in }
            )
        }
        func close() { try? FileManager.default.removeItem(at: directory) }
    }
}
