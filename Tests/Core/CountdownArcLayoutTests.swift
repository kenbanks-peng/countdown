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
            focusRemaining: 1_200, breakRemaining: 300, breakDuration: 300, at: nil
        )
        #expect(close(pair.focus.startProportion, 5.0 / 60))
        #expect(pair.shortBreak.startProportion == 0)
    }

    @Test func focusPrecedesBreakAndBothEndTimesStayFixed() {
        let initial = CountdownArcLayout.pomodoro(
            focusRemaining: 1_500, breakRemaining: 300, breakDuration: 300, at: date(minute: 20)
        )
        let later = CountdownArcLayout.pomodoro(
            focusRemaining: 1_200, breakRemaining: 300, breakDuration: 300, at: date(minute: 25)
        )
        #expect(close(initial.focus.startProportion, 20.0 / 60))
        #expect(close(initial.shortBreak.startProportion, 45.0 / 60))
        #expect(close(later.focus.startProportion + later.focus.proportion, initial.shortBreak.startProportion))
        #expect(close(later.shortBreak.startProportion, initial.shortBreak.startProportion))
        #expect(close(later.shortBreak.startProportion + later.shortBreak.proportion, 50.0 / 60))
        let inBreak = CountdownArcLayout.pomodoro(
            focusRemaining: 0, breakRemaining: 180, breakDuration: 300, at: date(minute: 47)
        )
        #expect(inBreak.focus.proportion == 0)
        #expect(close(inBreak.shortBreak.startProportion, 47.0 / 60))
        #expect(close(inBreak.shortBreak.startProportion + inBreak.shortBreak.proportion, 50.0 / 60))
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

    @Test func emptyAndFullHour() {
        let empty = CountdownArcLayout.timer(remaining: 0, at: date(minute: 20))
        let full = CountdownArcLayout.timer(remaining: 3_600, at: date(minute: 20))
        #expect(empty.proportion == 0)
        #expect(full.proportion == 1)
    }
}
