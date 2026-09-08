import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownAdjustmentTests {
    @Test(arguments: [false, true], [false, true])
    func timerUsesClockMarksOrRelativeStepsAfterElapsedTimeAndPause(clock: Bool, paused: Bool) {
        let session = Session(clock: clock)
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(by: 1_200)
        session.now += 73.5
        if paused {
            controller.toggleRunning()
            session.now += 47.25
        }
        controller.adjustTimerDuration(steps: 1)
        if clock {
            expectMark(timerEnd(controller))
        } else {
            #expect(abs(controller.timer.remaining - 1_426.5) < 1e-6)
        }
        let firstEnd = timerEnd(controller)
        controller.adjustTimerDuration(steps: 1)
        #expect(abs(timerEnd(controller) - firstEnd - 300) < 1e-6)
        controller.adjustTimerDuration(steps: -1)
        #expect(abs(timerEnd(controller) - firstEnd) < 1e-6)
        #expect(controller.countdown.isPaused == paused)
        // Clock-mode completion remains on the mark as real time advances.
        if clock && !paused {
            session.now += 17.125
            controller.update()
            expectMark(timerEnd(controller))
        }
    }

    @Test(arguments: [false, true])
    func timerMinimumAndMaximumAreAligned(clock: Bool) {
        let session = Session(clock: clock)
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(steps: -1)
        #expect(controller.timer.remaining == 0) // Decrease does not create a timer.
        controller.adjustTimerDuration(steps: 1)
        #expect(controller.timer.remaining >= 300)
        #expect(controller.timer.remaining < 600)
        expectMark(timerEnd(controller))
        let minimum = controller.timer.remaining
        controller.adjustTimerDuration(steps: -100)
        #expect(controller.timer.remaining == minimum)
        controller.adjustTimerDuration(steps: 100)
        #expect(controller.timer.remaining <= 3_600)
        #expect(controller.timer.remaining > 3_300)
        expectMark(timerEnd(controller))
        let maximum = controller.timer.remaining
        controller.adjustTimerDuration(steps: 1)
        #expect(controller.timer.remaining == maximum)
    }

    @Test(arguments: [PomodoroModel.Phase.rest, .longRest], [false, true])
    func partiallyElapsedRestEndsOnAMark(phase: PomodoroModel.Phase, paused: Bool) {
        let session = Session(clock: true)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now += (phase == .rest ? 0 : 5_400) + 1_573.5
        if paused {
            controller.toggleRunning()
            session.now += 38.25
        }
        controller.adjustPomodoroDuration(phase, steps: 1)
        #expect(controller.pomodoro.focusRemaining == 0)
        expectMark(pomodoroEnd(controller, phase: phase))
        #expect(controller.countdown.isPaused == paused)
    }

    @Test(arguments: [0.0, 73.25, 1_713.25, 7_113.25], [false, true])
    func pomodoroClockEditsKeepAllEndpointsAligned(elapsed: TimeInterval, paused: Bool) throws {
        let session = Session(clock: true)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now += elapsed
        controller.update()
        if paused { controller.toggleRunning() }
        for steps in [1, -1, 100, -100, 1] {
            for phase: PomodoroModel.Phase in [.focus, .rest, .longRest] {
                controller.adjustPomodoroDuration(phase, steps: steps)
                let schedule = try #require(controller.pomodoro.clockSchedule)
                #expect(schedule.isValid(cycles: controller.pomodoro.cycles))
                let end = schedule.end(for: phase)
                expectMark(end.timeIntervalSince(Calendar.current.startOfDay(for: end)))
                #expect(controller.pomodoro.focusDuration >= 300)
                #expect(controller.pomodoro.restDuration >= 300)
                #expect(controller.pomodoro.longRestDuration >= 300)
                #expect(controller.countdown.isPaused == paused)
            }
        }
    }

    @Test(arguments: [false, true])
    func clockModeAndPresentationModeChangesDoNotSnapExistingTimers(paused: Bool) {
        let session = Session(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(by: 713.25)
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: 23.5)
        controller.adjustPomodoroDuration(.rest, by: 17.25)
        controller.adjustPomodoroDuration(.longRest, by: 47.75)
        if paused { controller.toggleRunning() }
        let timerRemaining = controller.timer.remaining
        let model = controller.pomodoro
        controller.selectMode(.timer)
        controller.selectMode(.countdown)
        controller.selectMode(.pomodoro)
        #expect(controller.timer.remaining == timerRemaining)
        #expect(controller.pomodoro.focusDuration == model.focusDuration)
        #expect(controller.pomodoro.restDuration == model.restDuration)
        #expect(controller.pomodoro.longRestDuration == model.longRestDuration)
    }

    @Test
    func clockMinimumCanExceedFiveMinutesAndEndWrapsThroughTheHour() {
        let session = Session(clock: true)
        defer { session.close() }
        session.now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 57, second: 13))!.addingTimeInterval(0.25)
        let controller = session.controller
        controller.adjustTimerDuration(steps: 1)
        #expect(abs(controller.timer.remaining - 466.75) < 1e-6) // 23:05, not 23:00.
        expectMark(timerEnd(controller))
        controller.adjustTimerDuration(steps: 1)
        #expect(abs(controller.timer.remaining - 766.75) < 1e-6)
        controller.save()
        let restored = session.makeController()
        #expect(abs(restored.timer.remaining - 766.75) < 1e-6)
        expectMark(timerEnd(restored))
    }

    private func timerEnd(_ controller: CountdownController) -> Double {
        let arcs = CountdownArcLayout.timer(
            remaining: controller.timer.remaining,
            at: controller.mode.isClockEnabled ? controller.currentTime : nil,
            endDate: controller.timer.endDate, pausedAt: controller.timer.pausedAt
        )
        return (arcs.startProportion + arcs.proportion) * 3_600
    }

    private func pomodoroEnd(_ controller: CountdownController, phase: PomodoroModel.Phase) -> Double {
        let model = controller.pomodoro
        let arcs = CountdownArcLayout.pomodoro(
            focusRemaining: model.focusRemaining, restRemaining: model.restRemaining,
            restDuration: model.activeRestDuration,
            at: controller.mode.isClockEnabled ? controller.currentTime : nil,
            schedule: model.clockSchedule, restPhase: model.restPhase
        )
        let arc = phase == .focus ? arcs.focus : arcs.rest
        return (arc.startProportion + arc.proportion) * 3_600
    }

    private func expectMark(_ end: Double, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(abs(end - (end / 300).rounded() * 300) < 1e-6, sourceLocation: sourceLocation)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 2, second: 13))!.addingTimeInterval(0.25)
        lazy var controller = makeController()

        init(clock: Bool) {
            let store = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
            CountdownSettingsStore(fileManager: .default, stateDirectory: store.stateDirectory)
                .save(CountdownSettings(mode: clock ? .timer : .countdown))
        }

        func makeController() -> CountdownController {
            CountdownController(
                stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
                configuration: CountdownConfiguration(alarmNotificationURL: nil),
                featureState: CountdownFeatureState(popupEnabled: false),
                playSound: { _ in }, now: { [unowned self] in now }, saveEnablement: { _, _ in }
            )
        }

        func close() { try? FileManager.default.removeItem(at: directory) }
    }
}
