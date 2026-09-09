import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollDurationTests {
    @Test(arguments: [false, true])
    func countdownScrollAddsTimeWhileTheClockAdvances(precise: Bool) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(.countdown)
        for step in 1...4 {
            session.now += 0.1
            try session.scroll(angle: 270, delta: precise ? 12 : 1, after: 0.1, precise: precise)
            #expect(abs(session.controller.timer.remaining - (Double(step) * 300 - Double(step - 1) * 0.1)) < 1e-6)
        }
        session.now += 0.1
        try session.scroll(angle: 270, delta: precise ? -12 : -1, after: 0.1, precise: precise)
        #expect(abs(session.controller.timer.remaining - 899.6) < 1e-6)
    }

    @Test
    func focusScrollAtThreeTwentyFiveCanFillTheHourAhead() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.now = Calendar.current.startOfDay(for: session.now) + 3 * 3_600 + 10 * 60
        let timer = session.controller
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, steps: 100)
        session.now += 15 * 60
        timer.update()
        #expect(timer.pomodoro.focusRemaining + timer.pomodoro.restRemaining == 45 * 60)
        for minutes in [50, 55, 60] {
            try session.scroll(angle: 270, delta: 1, after: 0.16)
            #expect(timer.pomodoro.focusRemaining + timer.pomodoro.restRemaining == Double(minutes * 60))
        }
        #expect(timer.pomodoro.clockSchedule?.restEnd == session.now + 3_600)
        try session.scroll(angle: 270, delta: 1, after: 0.16)
        #expect(timer.pomodoro.focusRemaining + timer.pomodoro.restRemaining == 3_600)
        try session.scroll(angle: 270, delta: -1, after: 0.001)
        #expect(timer.pomodoro.focusRemaining + timer.pomodoro.restRemaining == 3_300)
        #expect(timer.pomodoro.longRestDuration == 900)
    }

    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func timerScrollUsesFiveMinuteStepsAndStopsAtFiveMinutes(mode: CountdownMode, option: Bool) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(mode)
        let timer = session.controller.timer
        try session.scroll(angle: 90, delta: option ? 3 : 1, option: option)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: option ? 3 : 1, option: option)
        #expect(timer.remaining == 600)
        try session.scroll(angle: 90, delta: option ? -3 : -1, option: option)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: option ? -3 : -1, option: option)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: 1_200, option: option)
        #expect(timer.remaining == 600) // Large events still move only one mark.
    }

    @Test(arguments: [PomodoroModel.Phase.focus, .rest, .longRest], [false, true])
    func scrollClampsAllocationsToFiveMinutesAndAvailableCapacity(phase: PomodoroModel.Phase, isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        if phase == .longRest {
            session.now += 5_400
            timer.update()
        }
        let angle = phase == .focus ? 150.0 : (phase == .longRest ? 105 : 285)
        let selected = {
            switch phase {
            case .focus: return timer.pomodoro.focusDuration
            case .rest: return timer.pomodoro.restDuration
            case .longRest: return timer.pomodoro.longRestDuration
            }
        }
        for _ in 0..<12 { try session.scroll(angle: angle, delta: 1_200, option: true, after: 0.16) }
        #expect(selected() == (phase == .focus ? 3_300 : (phase == .rest ? 2_100 : 3_600)))
        try session.scroll(angle: angle, delta: 12, after: 0.16)
        #expect(selected() == (phase == .focus ? 3_300 : (phase == .rest ? 2_100 : 3_600)))
        for _ in 0..<12 { try session.scroll(angle: angle, delta: -1_200, option: true, after: 0.16) }
        #expect(selected() == 300)
        try session.scroll(angle: angle, delta: -12, after: 0.16)
        #expect(selected() == 300)
        try session.scroll(angle: angle, delta: 12, after: 0.16)
        #expect(selected() == 600)
        #expect(timer.pomodoro.status == .running)
        #expect(timer.timer.remaining == timer.pomodoro.focusRemaining + timer.pomodoro.restRemaining)
    }

    @Test(arguments: [false, true])
    func fourthStageScrollEditsLongRestWithoutChangingShortRest(isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        session.now += 7_200
        try session.scroll(angle: 120, delta: 12)
        #expect(timer.pomodoro.stage == 4)
        #expect(timer.pomodoro.longRestDuration == 1_200)
        #expect(timer.pomodoro.restRemaining == 900)
        #expect(timer.pomodoro.restDuration == 300)
        session.now += 900
        timer.update()
        #expect(timer.pomodoro.stage == 1)
        #expect(timer.pomodoro.restRemaining == 300)
        session.now += 5_400
        timer.update()
        #expect(timer.pomodoro.stage == 4)
        #expect(timer.pomodoro.restRemaining == 1_200)
    }
}
