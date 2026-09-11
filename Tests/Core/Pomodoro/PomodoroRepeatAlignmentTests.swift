import Foundation
import Testing
@testable import Countdown

struct PomodoroRepeatAlignmentTests {
    private var start: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 5))!
    }

    @Test(arguments: [1, 4, 12], [900.0, 2_100, 3_600])
    func finalRestUsesMinimumAndSurvivesSerialization(stages: Int, longRest: TimeInterval) throws {
        var model = PomodoroModel(longRestDuration: longRest, focusPeriodsPerCycle: stages)
        model.isAutoAlignEnabled = true
        model.restartStage(stages, at: start)
        let schedule = try #require(model.clockSchedule)
        #expect(model.focusRemaining == 1_500)
        #expect(model.restRemaining >= longRest)
        #expect(model.restRemaining < longRest + 1_800)
        #expect(model.savedLongRestDuration == longRest)
        #expect(schedule.isValid(focusPeriodsPerCycle: stages))
        #expect(ClockBoundary.halfHour(atOrAfter: schedule.longRestEnd) == schedule.longRestEnd)
        let decoded = try JSONDecoder().decode(PomodoroClockSchedule.self, from: JSONEncoder().encode(schedule))
        #expect(decoded.savedLongRestDuration == longRest)
        #expect(decoded.longRestEnd == schedule.longRestEnd)
        #expect(decoded.isValid(focusPeriodsPerCycle: stages))
    }

    @Test(arguments: [1, 4, 12])
    func lateUpdatesMatchSmallUpdates(stages: Int) throws {
        var fast = PomodoroModel(longRestDuration: 900, focusPeriodsPerCycle: stages)
        fast.isAutoAlignEnabled = true
        fast.restartStage(1, at: start + 17 * 60 + 0.25)
        var slow = fast
        let end = start + 100_000
        var now = start + 17 * 60 + 0.25
        while now < end {
            now = min(end, now + 37)
            slow.update(at: now)
        }
        fast.update(at: end)
        #expect(fast.stage == slow.stage)
        #expect(fast.clockSchedule?.focusEnd == slow.clockSchedule?.focusEnd)
        #expect(fast.clockSchedule?.longRestEnd == slow.clockSchedule?.longRestEnd)
        // Large sleep gaps must not require one iteration per stage.
        fast.update(at: end + 100_000 * Double((stages + 1) * 1_800))
        #expect(fast.savedFocusDuration == 1_500)
        #expect(fast.savedLongRestDuration == 900)
    }

    @Test
    func pauseDoesNotCarryClockDriftIntoFollowingStages() throws {
        var model = PomodoroModel(longRestDuration: 900)
        model.isAutoAlignEnabled = true
        model.restartStage(1, at: start)
        model.pause(at: start + 60)
        model.toggleRunning(at: start + 7 * 60)
        let end = try #require(model.clockSchedule?.restEnd)
        model.update(at: end)
        #expect(model.stage == 2)
        #expect(model.clockSchedule?.restEnd == start + 3_600)
        #expect(model.focusRemaining == 19 * 60)
        #expect(model.savedFocusDuration == 1_500)
    }

    @Test
    func manualAlignRestoresBothRestAllocationsOnNextStage() throws {
        var model = PomodoroModel(focusDuration: 300, restDuration: 3_300)
        model.restartStage(1, at: start + 120)
        model.autoAlign(at: start + 120)
        #expect(model.restDuration == 28 * 60)
        #expect(model.savedRestDuration == 3_300)
        model.update(at: try #require(model.clockSchedule?.restEnd))
        #expect(model.restDuration == 3_300)
        #expect(model.focusDuration == 300)
    }
}
