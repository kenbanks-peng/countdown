import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollGestureTests {
    @Test
    func wheelNotchesAreNotDroppedWhenTheyArriveQuickly() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        for _ in 0..<3 { try session.scroll(angle: 90, delta: 1, after: 0.02) }
        #expect(session.controller.timer.remaining == 900)
    }

    @Test
    func preciseScrollUsesDistanceInsteadOfElapsedTime() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        for _ in 0..<11 {
            try session.scroll(angle: 90, delta: 1, after: 0.16, phase: .changed, precise: true)
        }
        #expect(session.controller.timer.remaining == 0)
        try session.scroll(angle: 90, delta: 1, after: 0.001, phase: .changed, precise: true)
        #expect(session.controller.timer.remaining == 300)
    }

    @Test
    func slowActiveGestureKeepsTheShrinkingSectorSelected() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        try session.scroll(angle: 264, delta: -12, phase: .began, precise: true)
        try session.scroll(angle: 264, delta: -12, after: 0.6, phase: .changed, precise: true)
        #expect(session.controller.pomodoro.focusDuration == 900)
        #expect(session.controller.pomodoro.restDuration == 300)
    }

    @Test(arguments: [false, true])
    func optionUsesOneMinuteWithTheSameScrollTravel(precise: Bool) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        let distance: Int32 = precise ? 12 : 1
        for step in 1...3 {
            try session.scroll(angle: 90, delta: distance, option: true, after: 0.01, precise: precise)
            #expect(session.controller.timer.remaining == Double(step) * 60)
        }
        try session.scroll(angle: 90, delta: distance, after: 0.01, precise: precise)
        #expect(session.controller.timer.remaining == 300)
    }

    @Test
    func preciseScrollDoesNotStoreExcessTravelAtTheLimit() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.adjustTimerDuration(by: 3_600)
        for _ in 0..<10 {
            try session.scroll(angle: 90, delta: 1_200, after: 0.01, precise: true)
        }
        #expect(session.controller.timer.remaining == 3_600)
        try session.scroll(angle: 90, delta: -12, after: 0.01, precise: true)
        #expect(session.controller.timer.remaining == 3_300)
    }

    @Test
    func preciseInputIsMarkedAsPreciseAndWheelInputIsNot() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        for precise in [false, true] {
            let event = try scrollEvent(in: session.window, at: .zero, delta: 1, precise: precise)
            #expect(event.hasPreciseScrollingDeltas == precise)
        }
    }

    @Test(arguments: [-1, 1])
    func preciseScrollAccumulatesTravelAndDiscardsItOnReversal(direction: Int32) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.adjustTimerDuration(by: 1_500)
        try session.scroll(angle: 90, delta: direction * 12, precise: true)
        #expect(session.controller.timer.remaining == 1_500 + Double(direction) * 300)
        for _ in 0..<11 {
            try session.scroll(angle: 90, delta: direction, after: 0.001, precise: true)
        }
        #expect(session.controller.timer.remaining == 1_500 + Double(direction) * 300)
        try session.scroll(angle: 90, delta: -direction, after: 0.001, precise: true)
        #expect(session.controller.timer.remaining == 1_500 + Double(direction) * 300)
        try session.scroll(angle: 90, delta: -direction * 11, after: 0.001, precise: true)
        #expect(session.controller.timer.remaining == 1_500)
    }

    @Test
    func downwardScrollKeepsItsTargetWhenTheSectorShrinks() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        // :44 is initially focus, but becomes rest after the first decrease.
        try session.scroll(angle: 264, delta: -12)
        #expect(session.controller.pomodoro.focusDuration == 1_200)
        try session.scroll(angle: 264, delta: -12, after: 0.16)
        #expect(session.controller.pomodoro.focusDuration == 900)
        #expect(session.controller.pomodoro.restDuration == 300)
        // The same pointer is now over background, but this is still the same scroll.
        try session.scroll(angle: 264, delta: -12, after: 0.16)
        #expect(session.controller.pomodoro.focusDuration == 600)
        try session.scroll(angle: 264, delta: -12, after: 0.5)
        #expect(session.controller.pomodoro.focusDuration == 600)
    }

    @Test(arguments: [NSEvent.Phase.ended, .cancelled])
    func endedGesturesReleaseTheTargetAndMomentumDoesNotEdit(ending: NSEvent.Phase) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        try session.scroll(angle: 264, delta: -1, phase: .began)
        #expect(session.controller.pomodoro.focusDuration == 1_200)
        try session.scroll(angle: 264, delta: 0, after: 0.001, phase: ending)
        // The same point must select rest once the previous gesture has ended.
        try session.scroll(angle: 264, delta: 1, after: 0.001)
        #expect(session.controller.pomodoro.focusDuration == 1_200)
        #expect(session.controller.pomodoro.restDuration == 600)
        try session.scroll(angle: 264, delta: 100, after: 0.16, momentum: true)
        #expect(session.controller.pomodoro.restDuration == 600)
        try session.scroll(angle: 264, delta: 1, after: 0.001, phase: .began)
        #expect(session.controller.pomodoro.restDuration == 900)
    }

    @Test(arguments: [false, true])
    func pointerMovementSelectsANewTargetWithoutWaiting(isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 180, delta: 1)
        #expect(timer.pomodoro.focusDuration == 1_800)
        try session.scroll(angle: 315, delta: 1, after: 0.001)
        #expect(timer.pomodoro.restDuration == 600)
        try session.scroll(angle: 180, delta: -1, after: 0.001)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 15, delta: -1, after: 0.001)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 180, delta: -1, after: 0.001)
        #expect(timer.pomodoro.focusDuration == 1_200)
    }

    @Test
    func modeChangesDiscardPartialScrollDistance() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        let timer = session.controller
        try session.scroll(angle: 90, delta: 1)
        try session.scroll(angle: 90, delta: 11, after: 0.001, precise: true)
        #expect(timer.timer.remaining == 300)
        timer.selectMode(.pomodoro)
        timer.selectMode(.timer)
        try session.scroll(angle: 90, delta: 1, after: 0.001, precise: true)
        #expect(timer.timer.remaining == 300)
        try session.scroll(angle: 90, delta: 11, after: 0.001, precise: true)
        #expect(timer.timer.remaining == 600)
        timer.selectMode(.countdown)
        try session.scroll(angle: 90, delta: 1, after: 0.001)
        #expect(timer.timer.remaining == 900)
        #expect(timer.pomodoro.focusRemaining == 600)
    }
}
