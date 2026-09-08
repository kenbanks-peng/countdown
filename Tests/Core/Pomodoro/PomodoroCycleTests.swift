import Foundation
import Testing
@testable import Countdown

struct PomodoroCycleTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func fourFocusPeriodsUseThreeRestsAndOneLongRestThenRepeat() {
        var model = PomodoroModel(longRestDuration: 900)
        #expect(model.cycleDuration == 130 * 60)
        model.toggleRunning(at: start)
        for stage in 1...4 {
            let stageStart = start + Double(stage - 1) * 1_800
            model.update(at: stageStart)
            #expect(model.stage == stage)
            #expect(model.completedFocusPeriods == stage - 1)
            #expect(model.focusRemaining == 1_500)
            #expect(model.restRemaining == (stage == 4 ? 900 : 300))
            #expect(model.dotStates == (1...4).map { index in
                index < stage ? .completed : (index == stage ? .current : .pending)
            })
            model.update(at: stageStart + 1_500)
            #expect(model.completedFocusPeriods == stage)
            #expect(model.dotStates == (1...4).map { $0 <= stage ? .completed : .pending })
            #expect(model.progressDescription == "Focus period \(stage) of 4. \(stage) completed.")
            #expect(model.phaseLabel == (stage == 4 ? "Long rest" : "Rest"))
        }
        model.update(at: start + 7_799)
        #expect(model.restRemaining == 1)
        model.update(at: start + 7_800)
        #expect(model.stage == 1)
        #expect(model.status == .running)
        #expect(model.dotStates == [.current, .pending, .pending, .pending])
        #expect(model.focusRemaining == 1_500)
        #expect(model.restRemaining == 300)
    }

    @Test(arguments: [1, 3, 4, 12])
    func configuredCyclesRepeatAfterLongRest(focusPeriodsPerCycle: Int) {
        var model = PomodoroModel(longRestDuration: 900, focusPeriodsPerCycle: focusPeriodsPerCycle)
        #expect(model.cycleDuration == Double(focusPeriodsPerCycle) * 1_500 + Double(focusPeriodsPerCycle - 1) * 300 + 900)
        model.toggleRunning(at: start)
        for stage in 1...focusPeriodsPerCycle {
            let stageStart = start + Double(stage - 1) * 1_800
            model.update(at: stageStart)
            #expect(model.stage == stage)
            #expect(model.dotStates.count == focusPeriodsPerCycle)
            #expect(model.dotStates[stage - 1] == .current)
            #expect(model.restPhase == (stage == focusPeriodsPerCycle ? .longRest : .rest))
            model.update(at: stageStart + 1_500)
            #expect(model.restRemaining == (stage == focusPeriodsPerCycle ? 900 : 300))
            #expect(model.progressDescription == "Focus period \(stage) of \(focusPeriodsPerCycle). \(stage) completed.")
            #expect(model.dotStates == (1...focusPeriodsPerCycle).map { $0 <= stage ? .completed : .pending })
        }
        model.update(at: start + model.cycleDuration)
        #expect(model.stage == 1)
        #expect(model.focusRemaining == 1_500)
        #expect(model.completedFocusPeriods == 0)
        model.reset()
        #expect(model.focusPeriodsPerCycle == focusPeriodsPerCycle)
    }

    @Test(arguments: [0, -1, 13, Int.max])
    func invalidCyclesUseFour(focusPeriodsPerCycle: Int) {
        #expect(PomodoroModel(focusPeriodsPerCycle: focusPeriodsPerCycle).focusPeriodsPerCycle == 4)
        #expect(CountdownConfiguration(alarmNotificationURL: nil, pomodoroFocusPeriodsPerCycle: focusPeriodsPerCycle).pomodoroFocusPeriodsPerCycle == 4)
    }

    @Test(arguments: [1, 3, 4, 12])
    func lateUpdatesMatchSmallUpdatesAndIgnoreDuplicateOrBackwardTime(focusPeriodsPerCycle: Int) {
        var late = PomodoroModel(focusPeriodsPerCycle: focusPeriodsPerCycle)
        var stepped = PomodoroModel(focusPeriodsPerCycle: focusPeriodsPerCycle)
        late.toggleRunning(at: start)
        stepped.toggleRunning(at: start)
        for seconds in stride(from: 60, through: 80_040, by: 60) {
            stepped.update(at: start + Double(seconds))
        }
        late.update(at: start + 80_040)
        #expect(late.stage == stepped.stage)
        #expect(late.focusRemaining == stepped.focusRemaining)
        #expect(late.restRemaining == stepped.restRemaining)
        let description = late.accessibilityDescription
        late.update(at: start + 80_040)
        late.update(at: start + 70_000)
        #expect(late.accessibilityDescription == description)
        #expect(late.elapsedTime == 80_040)
        late.update(at: start + 80_100)
        stepped.update(at: start + 80_100)
        #expect(late.focusRemaining == stepped.focusRemaining)
        #expect(late.restRemaining == stepped.restRemaining)
    }

    @Test
    func editedDurationsCarryIntoFollowingStagesAndCycles() {
        var model = PomodoroModel(longRestDuration: 900)
        model.toggleRunning(at: start)
        model.adjustDuration(.focus, by: -300, at: start + 600)
        model.adjustDuration(.rest, by: 120, at: start + 600)
        model.adjustDuration(.longRest, by: 300, at: start + 600)
        #expect(model.focusRemaining == 600)
        #expect(model.restRemaining == 420)
        for stage in 2...4 {
            model.update(at: start + Double(stage - 1) * 1_620)
            #expect(model.stage == stage)
            #expect(model.focusRemaining == 1_200)
            #expect(model.restRemaining == (stage == 4 ? 1_200 : 420))
        }
        model.update(at: start + 7_260)
        #expect(model.stage == 1)
        #expect(model.focusRemaining == 1_200)
        #expect(model.restRemaining == 420)
        #expect(model.longRestDuration == 1_200)
    }

    @Test(arguments: [false, true])
    func longRestEditsKeepElapsedTimeAndDoNotChangeShortRests(paused: Bool) {
        var model = PomodoroModel(longRestDuration: 900)
        model.toggleRunning(at: start)
        let now = start + 7_200 // Five minutes into the long rest.
        model.update(at: now)
        if paused { model.pause(at: now) }
        model.adjustDuration(.longRest, by: 300, at: now)
        #expect(model.restRemaining == 900)
        model.adjustDuration(.focus, by: 60, at: now)
        #expect(model.focusRemaining == 0) // Do not reopen completed focus.
        model.adjustDuration(.rest, by: 60, at: now)
        #expect(model.restRemaining == 900)
        model.adjustDuration(.longRest, by: -960, at: now)
        #expect(model.stage == 1)
        #expect(model.status == (paused ? .paused : .running))
        #expect(model.focusRemaining == 1_560)
        #expect(model.restRemaining == 360)
        #expect(model.longRestDuration == 300)
        model.reset()
        #expect(model.stage == 1)
        #expect(model.focusDuration == 1_500)
        #expect(model.restDuration == 300)
        #expect(model.longRestDuration == 900)
    }

    @Test
    func longRestPauseResumeAndResetKeepStageAndAllocations() {
        var model = PomodoroModel(longRestDuration: 900)
        model.toggleRunning(at: start)
        model.pause(at: start + 7_000)
        #expect(model.stage == 4)
        #expect(model.restRemaining == 800)
        model.update(at: start + 20_000)
        #expect(model.restRemaining == 800)
        model.toggleRunning(at: start + 20_000)
        model.update(at: start + 20_800)
        #expect(model.stage == 1)
        #expect(model.focusRemaining == 1_500)
    }

    @Test(arguments: [Double.nan, Double.infinity, -Double.infinity])
    func invalidEditsDoNotChangeAllocations(amount: Double) {
        var model = PomodoroModel(longRestDuration: 900)
        for phase in [PomodoroModel.Phase.focus, .rest, .longRest] {
            model.adjustDuration(phase, by: amount, at: start)
        }
        #expect(model.focusDuration == 1_500)
        #expect(model.restDuration == 300)
        #expect(model.longRestDuration == 900)
    }
}
