import Foundation
import Testing
@testable import Countdown

struct PomodoroAutoAlignTests {
    private func date(hour: Int = 10, minute: Int, second: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(
            year: 2026, month: 1, day: 15, hour: hour, minute: minute, second: second
        ))!
    }

    private func model(at now: Date, focus: TimeInterval = 1_500,
                       rest: TimeInterval = 300, longRest: TimeInterval = 1_200,
                       stage: Int = 1, paused: Bool = false) -> PomodoroModel {
        var model = PomodoroModel(focusDuration: focus, restDuration: rest, longRestDuration: longRest)
        model.restoreClockSchedule(PomodoroClockSchedule(
            stageStart: now, focusEnd: now + focus, restEnd: now + focus + rest,
            longRestEnd: now + focus + longRest, sampledAt: now,
            pausedAt: paused ? now : nil, stage: stage, focusCompleted: false
        ), at: now)
        return model
    }

    @Test(arguments: [300.0, 2_400])
    func increasesOrDecreasesFocusAndPreservesRest(focus: TimeInterval) throws {
        let now = date(minute: 2, second: 13) + 0.25
        var model = model(at: now, focus: focus)
        #expect(model.canAutoAlign(at: now))
        model.autoAlign(at: now)
        let schedule = try #require(model.clockSchedule)
        #expect(schedule.restEnd == date(minute: 30))
        #expect(schedule.focusEnd == date(minute: 25))
        #expect(model.restRemaining == 300)
        #expect(model.restDuration == 300)
        #expect(model.longRestDuration == 1_200)
        #expect(model.stage == 1)
        #expect(model.status == .running)
        #expect(schedule.isValid(focusPeriodsPerCycle: 4))
        model.autoAlign(at: now)
        #expect(model.clockSchedule?.restEnd == date(hour: 11, minute: 0))
        #expect(model.clockSchedule?.nextStageFocusDuration == focus)
        model.autoAlign(at: now)
        #expect(model.clockSchedule?.restEnd == schedule.restEnd)
        model.update(at: schedule.restEnd)
        #expect(model.stage == 2)
        #expect(model.focusRemaining == focus)
        #expect(model.clockSchedule?.nextStageFocusDuration == nil)
    }

    @Test(arguments: [0.0, 0.25])
    func fiveMinuteMinimumIsInclusiveButFractionsDoNotRoundDown(fraction: TimeInterval) {
        let now = date(minute: 20) + fraction
        var model = model(at: now)
        model.autoAlign(at: now)
        #expect(model.clockSchedule?.restEnd == (fraction == 0 ? date(minute: 30) : date(hour: 11, minute: 0)))
        #expect(model.focusRemaining >= 300)
    }

    @Test
    func skipsAnHourThatCannotHoldFocusAndRest() {
        let now = date(minute: 58)
        var model = model(at: now)
        model.autoAlign(at: now)
        #expect(model.clockSchedule?.restEnd == date(hour: 11, minute: 30))
        #expect(model.focusRemaining == 27 * 60)
    }

    @Test
    func finalStageUsesLongRestAndRestoresFocusOnRepeat() throws {
        let now = date(hour: 23, minute: 58)
        var model = model(at: now, stage: 4)
        model.autoAlign(at: now)
        let schedule = try #require(model.clockSchedule)
        #expect(schedule.longRestEnd == date(hour: 23, minute: 30) + 3_600)
        #expect(model.focusRemaining == 12 * 60)
        #expect(model.restRemaining == 1_200)
        #expect(model.restDuration == 300)
        model.autoAlign(at: now)
        #expect(model.clockSchedule?.longRestEnd == schedule.longRestEnd + 1_800)
        model.autoAlign(at: now)
        #expect(model.clockSchedule?.longRestEnd == schedule.longRestEnd)
        model.update(at: schedule.longRestEnd)
        #expect(model.stage == 1)
        #expect(model.focusRemaining == 1_500)
    }

    @Test
    func pausedAlignmentUsesCurrentWallTimeAndKeepsPauseState() throws {
        let start = date(minute: 2)
        var model = model(at: start, paused: true)
        let now = date(minute: 58)
        model.autoAlign(at: now)
        let schedule = try #require(model.clockSchedule)
        #expect(model.status == .paused)
        #expect(schedule.pausedAt == now)
        #expect(schedule.restEnd == date(hour: 11, minute: 30))
        model.toggleRunning(at: now + 60)
        #expect(model.clockSchedule?.restEnd == schedule.restEnd + 60)
    }

    @Test
    func restAndCompletedCycleCannotBeAligned() throws {
        let now = date(minute: 2)
        var model = model(at: now, stage: 4)
        model.isAutoRepeatEnabled = false
        for offset in [1_500.0, 2_700] {
            model.update(at: now + offset)
            let before = try #require(model.clockSchedule)
            #expect(!model.canAutoAlign(at: now + offset))
            model.autoAlign(at: now + offset)
            #expect(model.clockSchedule?.focusEnd == before.focusEnd)
            #expect(model.clockSchedule?.longRestEnd == before.longRestEnd)
            #expect(model.stage == 4)
        }
    }

    @Test
    func capacityConflictDisablesAlignmentInsteadOfMissingBoundary() {
        let now = date(minute: 2)
        var model = model(at: now, focus: 300, rest: 3_300)
        #expect(!model.canAutoAlign(at: now))
        model.autoAlign(at: now)
        #expect(model.focusRemaining == 300)
        #expect(model.restRemaining == 3_300)
    }

    @Test
    func largeRestLeavesOnlyOneValidAlignment() {
        let now = date(minute: 2)
        var model = model(at: now, focus: 600, rest: 1_800)
        for _ in 0..<3 {
            model.autoAlign(at: now)
            #expect(model.clockSchedule?.restEnd == date(hour: 11, minute: 0))
            #expect(model.focusRemaining == 28 * 60)
            #expect(model.restDuration == 1_800)
            #expect(model.clockSchedule?.nextStageFocusDuration == 600)
        }
    }

    @Test
    func lateUpdateUsesOriginalDurationsAfterAlignedStage() throws {
        let now = date(minute: 2)
        var model = model(at: now)
        model.autoAlign(at: now)
        let end = try #require(model.clockSchedule?.restEnd)
        model.update(at: end + 3 * 1_800 + 900 + 60)
        #expect(model.stage == 1)
        #expect(model.focusRemaining == 1_440)
        #expect(model.restRemaining == 300)
    }

    @Test
    func manualFocusEditReplacesOneStageOverride() {
        let now = date(minute: 2)
        var model = model(at: now)
        model.autoAlign(at: now)
        model.adjustDuration(.focus, by: 300, at: now)
        #expect(model.clockSchedule?.nextStageFocusDuration == nil)
        #expect(model.focusDuration == 28 * 60)
    }
}
