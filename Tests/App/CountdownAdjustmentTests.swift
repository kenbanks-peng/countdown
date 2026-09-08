import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownAdjustmentTests {
    @Test(arguments: [false, true], [false, true])
    func timerEndsOnMarksAfterElapsedTimeAndPause(clock: Bool, paused: Bool) {
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
        expectMark(timerEnd(controller))
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

    @Test(arguments: [PomodoroModel.Phase.focus, .rest, .longRest])
    func durationPomodoroSelectedEndUsesTheDisplayedStart(phase: PomodoroModel.Phase) {
        let session = Session(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        if phase == .longRest {
            session.now += 5_400
        }
        session.now += 73.5
        controller.update()
        let before = controller.pomodoro
        controller.adjustPomodoroDuration(phase, steps: 1)
        expectMark(pomodoroEnd(controller, phase: phase))
        let firstEnd = pomodoroEnd(controller, phase: phase)
        controller.adjustPomodoroDuration(phase, steps: 1)
        #expect(abs(pomodoroEnd(controller, phase: phase) - firstEnd - 300) < 1e-6)
        controller.adjustPomodoroDuration(phase, steps: -1)
        #expect(abs(pomodoroEnd(controller, phase: phase) - firstEnd) < 1e-6)
        expectMark(pomodoroEnd(controller, phase: .focus))
        expectMark(pomodoroEnd(controller, phase: controller.pomodoro.restPhase))
        if phase == .longRest {
            #expect(controller.pomodoro.restDuration == before.restDuration)
        } else {
            #expect(controller.pomodoro.longRestDuration == before.longRestDuration)
        }
    }

    @Test(arguments: [false, true])
    func durationAlternatingEditsKeepBothEndsOnMarks(longRest: Bool) {
        let session = Session(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: 23.25)
        controller.adjustPomodoroDuration(.rest, by: 93.5)
        controller.adjustPomodoroDuration(.longRest, by: 17.75)
        if longRest { session.now += controller.pomodoro.focusDuration * 3 + controller.pomodoro.restDuration * 3 }
        session.now += 41.125
        controller.update()
        for phase in [controller.pomodoro.restPhase, .focus, controller.pomodoro.restPhase, .focus] {
            controller.adjustPomodoroDuration(phase, steps: 1)
            expectMark(pomodoroEnd(controller, phase: .focus))
            expectMark(pomodoroEnd(controller, phase: controller.pomodoro.restPhase))
            #expect(controller.pomodoro.focusDuration >= 300)
            #expect(controller.pomodoro.activeRestDuration >= 300)
            #expect(controller.pomodoro.focusDuration + controller.pomodoro.activeRestDuration <= 3_600)
        }
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

    @Test
    func durationShrinkingElapsedRestAlignsTheNextStage() {
        let session = Session(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, by: 300)
        session.now += 1_913.25
        controller.adjustPomodoroDuration(.rest, steps: -100)
        #expect(controller.pomodoro.stage == 2)
        if controller.pomodoro.focusRemaining > 0 {
            expectMark(pomodoroEnd(controller, phase: .focus))
        }
        expectMark(pomodoroEnd(controller, phase: .rest))
    }

    @Test(arguments: [0.0, 73.25, 1_713.25, 7_113.25])
    func durationPomodoroLimitsKeepVisibleEndsAligned(elapsed: Double) {
        let session = Session(clock: false)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.rest, by: 173.5)
        controller.adjustPomodoroDuration(.longRest, by: 93.25)
        session.now += elapsed
        controller.update()
        for steps in [1, -1, 100, -100, 1] {
            for phase in [controller.pomodoro.restPhase, .focus] {
                controller.adjustPomodoroDuration(phase, steps: steps)
                if controller.pomodoro.focusRemaining > 0 {
                    expectMark(pomodoroEnd(controller, phase: .focus))
                }
                expectMark(pomodoroEnd(controller, phase: controller.pomodoro.restPhase))
                #expect(controller.pomodoro.focusDuration >= 300)
                #expect(controller.pomodoro.activeRestDuration >= 300)
                #expect(controller.pomodoro.focusDuration + max(controller.pomodoro.restDuration, controller.pomodoro.longRestDuration) <= 3_600)
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
        controller.features.setClockEnabled(true)
        controller.selectMode(.timer)
        controller.features.setClockEnabled(false)
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
            at: controller.features.isClockEnabled ? controller.currentTime : nil,
            endDate: controller.timer.endDate, pausedAt: controller.timer.pausedAt
        )
        return (arcs.startProportion + arcs.proportion) * 3_600
    }

    private func pomodoroEnd(_ controller: CountdownController, phase: PomodoroModel.Phase) -> Double {
        let model = controller.pomodoro
        let arcs = CountdownArcLayout.pomodoro(
            focusRemaining: model.focusRemaining, restRemaining: model.restRemaining,
            restDuration: model.activeRestDuration,
            at: controller.features.isClockEnabled ? controller.currentTime : nil,
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
        let clock: Bool
        lazy var controller = makeController()

        init(clock: Bool) { self.clock = clock }

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
