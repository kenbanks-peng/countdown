import Foundation
import SwiftUI
import Testing
@testable import Countdown

struct CountdownArcLayoutTests {
    private func date(minute: Int, second: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: minute, second: second))!
    }

    private func close(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.000001
    }

    @Test func timerMovesClockwiseWithFixedEnd() {
        let initial = CountdownArcLayout.timer(remaining: 600, at: date(minute: 20))
        let later = CountdownArcLayout.timer(remaining: 300, at: date(minute: 25))
        #expect(close(initial.startProportion, 20.0 / 60))
        #expect(close(initial.startProportion + initial.proportion, 30.0 / 60))
        #expect(later.startProportion > initial.startProportion)
        #expect(close(later.startProportion + later.proportion, 30.0 / 60))
    }

    @Test func hiddenFaceKeepsOriginalLayout() {
        let timer = CountdownArcLayout.timer(remaining: 600, at: nil)
        #expect(timer.startProportion == 0)
        #expect(close(timer.proportion, 10.0 / 60))
        let pair = CountdownArcLayout.pomodoro(
            focusRemaining: 1_200, restRemaining: 300, restDuration: 300, at: nil
        )
        #expect(close(pair.focus.startProportion, 5.0 / 60))
        #expect(pair.rest.startProportion == 0)
    }

    @Test func focusPrecedesRestAndBothEndTimesStayFixed() {
        let initial = CountdownArcLayout.pomodoro(
            focusRemaining: 1_500, restRemaining: 300, restDuration: 300, at: date(minute: 20)
        )
        let later = CountdownArcLayout.pomodoro(
            focusRemaining: 1_200, restRemaining: 300, restDuration: 300, at: date(minute: 25)
        )
        #expect(close(initial.focus.startProportion, 20.0 / 60))
        #expect(close(initial.rest.startProportion, 45.0 / 60))
        #expect(close(later.focus.startProportion + later.focus.proportion, initial.rest.startProportion))
        #expect(close(later.rest.startProportion, initial.rest.startProportion))
        #expect(close(later.rest.startProportion + later.rest.proportion, 50.0 / 60))
        let inRest = CountdownArcLayout.pomodoro(
            focusRemaining: 0, restRemaining: 180, restDuration: 300, at: date(minute: 47)
        )
        #expect(inRest.focus.proportion == 0)
        #expect(close(inRest.rest.startProportion, 47.0 / 60))
        #expect(close(inRest.rest.startProportion + inRest.rest.proportion, 50.0 / 60))
    }

    @Test func pausedDurationFollowsClockAndAdjustmentMovesEnd() {
        let initial = CountdownArcLayout.timer(remaining: 600, at: date(minute: 20))
        let paused = CountdownArcLayout.timer(remaining: 600, at: date(minute: 25))
        let adjusted = CountdownArcLayout.timer(remaining: 900, at: date(minute: 25))
        #expect(initial.proportion == paused.proportion)
        #expect(paused.startProportion > initial.startProportion)
        #expect(adjusted.startProportion == paused.startProportion)
        #expect(close(adjusted.startProportion + adjusted.proportion, 40.0 / 60))
    }

    @Test func pausedClockTimerRotatesWithoutShrinkingAfterSeveralHours() {
        let pausedAt = date(minute: 55, second: 30)
        let now = pausedAt + 7_813
        let end = pausedAt + 600
        let initial = CountdownArcLayout.timer(remaining: 600, at: pausedAt, endDate: end, pausedAt: pausedAt)
        let paused = CountdownArcLayout.timer(remaining: 600, at: now, endDate: end, pausedAt: pausedAt)
        let resumed = CountdownArcLayout.timer(remaining: 600, at: now, endDate: now + 600)
        #expect(close(paused.startProportion, CountdownArcLayout.minuteProportion(at: now)))
        #expect(close(paused.proportion, initial.proportion))
        #expect(close(paused.startProportion, resumed.startProportion))
        #expect(close(paused.proportion, resumed.proportion))
        let running = CountdownArcLayout.timer(remaining: 540, at: now + 60, endDate: now + 600)
        #expect(close(running.proportion, paused.proportion - 60.0 / 3_600))
    }

    @Test(arguments: [false, true], [PomodoroModel.Phase.rest, .longRest])
    func pausedPomodoroRotatesWithoutChangingPhaseSizes(inRest: Bool, restPhase: PomodoroModel.Phase) {
        let start = date(minute: 40)
        let pausedAt = start + (inRest ? 1_260 : 300)
        let now = pausedAt + 7_813
        var schedule = PomodoroClockSchedule(
            stageStart: start, focusEnd: start + 1_200,
            restEnd: start + 1_800, longRestEnd: start + 2_100,
            sampledAt: pausedAt, pausedAt: pausedAt, stage: 1, focusCompleted: inRest
        )
        func arcs(at date: Date) -> (focus: CountdownArcLayout, rest: CountdownArcLayout) {
            CountdownArcLayout.pomodoro(
                focusRemaining: inRest ? 0 : 900, restRemaining: 600,
                restDuration: 600, at: date, schedule: schedule, restPhase: restPhase
            )
        }
        let initial = arcs(at: pausedAt)
        let paused = arcs(at: now)
        #expect(close(paused.focus.startProportion, CountdownArcLayout.minuteProportion(at: now)))
        #expect(close(paused.focus.proportion, initial.focus.proportion))
        #expect(close(paused.rest.proportion, initial.rest.proportion))
        #expect(close(paused.rest.startProportion,
                      CountdownArcLayout.minuteProportion(at: now + paused.focus.proportion * 3_600)))
        #expect(schedule.pausedAt == pausedAt)
        #expect(schedule.focusEnd == start + 1_200)
        schedule.resume(at: now)
        let resumed = arcs(at: now)
        #expect(close(paused.focus.startProportion, resumed.focus.startProportion))
        #expect(close(paused.rest.startProportion, resumed.rest.startProportion))
        #expect(close(paused.focus.proportion, resumed.focus.proportion))
        #expect(close(paused.rest.proportion, resumed.rest.proportion))
    }

    @Test func secondsAndHourRollover() {
        let initial = CountdownArcLayout.timer(remaining: 600, at: date(minute: 55, second: 30))
        let later = CountdownArcLayout.timer(remaining: 270, at: date(minute: 1))
        #expect(close(initial.startProportion, 55.5 / 60))
        #expect(close(initial.startProportion + initial.proportion - 1, later.startProportion + later.proportion))
        let path = RadialSector(proportion: initial.proportion, startProportion: initial.startProportion)
            .path(in: CGRect(x: 0, y: 0, width: 100, height: 100))
        #expect(path.contains(CGPoint(x: 50, y: 10)))
        #expect(!path.contains(CGPoint(x: 50, y: 90)))
    }

    @Test(arguments: [false, true])
    func longRestFitsAvailableSpaceWithoutOverlappingFocus(clock: Bool) {
        for elapsed in [0.0, 300, 600, 900] {
            let pair = CountdownArcLayout.pomodoro(
                focusRemaining: 3_300 - elapsed, restRemaining: 900, restDuration: 900,
                at: clock ? date(minute: 55, second: 13) + elapsed : nil
            )
            #expect(close(pair.rest.proportion, min(900, 300 + elapsed) / 3_600))
            #expect(pair.focus.proportion + pair.rest.proportion <= 1)
            if !clock {
                #expect(close(pair.focus.startProportion, pair.rest.proportion))
            }
        }
    }

    @Test func emptyAndFullHour() {
        let empty = CountdownArcLayout.timer(remaining: 0, at: date(minute: 20))
        let full = CountdownArcLayout.timer(remaining: 3_600, at: date(minute: 20))
        #expect(empty.proportion == 0)
        #expect(full.proportion == 1)
    }
}
