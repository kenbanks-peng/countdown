import AppKit
import Testing
@testable import Countdown

@MainActor
struct PomodoroFocusScrollTests {
    @Test(arguments: [false, true], 0..<8)
    func backgroundRepairsRestThenRestoresFocusInOneGesture(isCompact: Bool, variant: Int) throws {
        let option = variant & 1 != 0
        let paused = variant & 2 != 0
        let longRest = variant & 4 != 0
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        if longRest { session.now += 5_400 }
        controller.update()
        let initial = try #require(controller.pomodoro.clockSchedule)
        let restPhase = controller.pomodoro.restPhase
        session.now = initial.end(for: restPhase) - 180
        controller.update()
        if paused {
            controller.toggleRunning()
            session.now += 120
        }
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == 180)
        // Start just beyond rest. The first edit moves blue under this pointer.
        let visibleEnd = initial.end(for: restPhase) + (paused ? 120 : 0)
        let endMinute = Calendar.current.component(.minute, from: visibleEnd)
        let angle = Double((endMinute + 1) % 60) * 6

        try session.scroll(angle: angle, delta: 12, option: option, phase: .began, precise: true)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining >= 300)
        let rest = controller.pomodoro.restRemaining
        let allocation = controller.pomodoro.activeRestDuration
        try session.scroll(angle: angle, delta: 12, option: option, after: 0.01, phase: .changed, precise: true)
        #expect(controller.pomodoro.focusRemaining > 0)
        #expect(controller.pomodoro.restRemaining == rest)
        #expect(controller.pomodoro.activeRestDuration == allocation)
        #expect(controller.pomodoro.stage == initial.stage)
        #expect(controller.engine.isPaused == paused)
        #expect(controller.timer.remaining == controller.pomodoro.focusRemaining + rest)
        let restored = try #require(controller.pomodoro.clockSchedule)
        #expect(restored.isValid(focusPeriodsPerCycle: 4))
        let focus = controller.pomodoro.focusRemaining
        try session.scroll(angle: angle, delta: 12, option: option, after: 0.01, phase: .changed, precise: true)
        #expect(controller.pomodoro.focusRemaining == focus + (option ? 60 : 300))
        #expect(controller.pomodoro.restRemaining == rest)
    }

    @Test(arguments: [Int32(-1), 1], 0..<16)
    func backgroundScrollWithTwoMinutesOfRestDoesNotRestartTheStage(direction: Int32, variant: Int) throws {
        let option = variant & 1 != 0
        let paused = variant & 2 != 0
        let directEdit = variant & 4 != 0
        let session = ScrollTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        if variant & 8 != 0 { session.now += 5_400 }
        controller.update()
        let initial = try #require(controller.pomodoro.clockSchedule)
        session.now = initial.end(for: controller.pomodoro.restPhase) - 120
        controller.update()
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == 120)
        let stage = controller.pomodoro.stage
        let before = try #require(controller.pomodoro.clockSchedule)
        if paused { controller.toggleRunning() }
        if directEdit {
            if option { controller.adjustPomodoroDuration(.focus, by: Double(direction) * 60) }
            else { controller.adjustPomodoroDuration(.focus, steps: Int(direction)) }
        } else {
            try session.scroll(angle: 240, delta: direction, option: option)
        }
        #expect(controller.pomodoro.stage == stage)
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == (option ? 300 : 420))
        let after = try #require(controller.pomodoro.clockSchedule)
        #expect(after.focusEnd == before.focusEnd)
        #expect(after.stageStart == before.stageStart)
        #expect(after.isValid(focusPeriodsPerCycle: 4))
        // Keep the same background gesture. Further decreases at zero do nothing.
        let rest = controller.pomodoro.restRemaining
        if direction < 0 {
            try session.scroll(angle: 240, delta: -1, option: option, after: 0.01)
            #expect(controller.pomodoro.focusRemaining == 0)
            #expect(controller.pomodoro.restRemaining == rest)
            #expect(controller.pomodoro.clockSchedule?.focusEnd == before.focusEnd)
            #expect(controller.pomodoro.stage == stage)
        }
        // Continuing or reversing the gesture now adds focus without resetting rest.
        try session.scroll(angle: 240, delta: 1, option: option, after: 0.01)
        #expect(controller.pomodoro.focusRemaining == (option ? 300 : 420))
        #expect(controller.pomodoro.restRemaining == rest)
        #expect(controller.pomodoro.stage == stage)
    }

    @Test(arguments: [false, true])
    func sufficientRestAllowsImmediateFocusIncrease(option: Bool) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        session.now += 1_500
        controller.update()
        try session.scroll(angle: 240, delta: 1, option: option)
        #expect(controller.pomodoro.focusRemaining == 300)
        #expect(controller.pomodoro.restRemaining == 300)
        #expect(controller.pomodoro.stage == 1)
    }
}
