import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollIncrementTests {
    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func optionPreservesSecondsAndNormalScrollAlignsInBothDirections(mode: CountdownMode, precise: Bool) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.now += 13.25
        session.controller.selectMode(mode)
        session.controller.adjustTimerDuration(by: 713.25)
        let distance: Int32 = precise ? 12 : 1
        try session.scroll(angle: 90, delta: distance, option: true, precise: precise)
        #expect(session.controller.timer.remaining == 773.25)
        try session.scroll(angle: 90, delta: -distance, option: true, precise: precise)
        #expect(session.controller.timer.remaining == 713.25)
        try session.scroll(angle: 90, delta: distance, precise: precise)
        #expect(session.controller.timer.remaining == (mode == .timer ? 886.75 : 900))
        try session.scroll(angle: 90, delta: -distance, option: true, precise: precise)
        #expect(session.controller.timer.remaining == (mode == .timer ? 826.75 : 840))
        try session.scroll(angle: 90, delta: -distance, precise: precise)
        #expect(session.controller.timer.remaining == (mode == .timer ? 586.75 : 600))
    }

    @Test(arguments: [PomodoroModel.Phase.focus, .rest, .longRest], [false, true])
    func optionEditsEachPomodoroPhaseByOneMinute(phase: PomodoroModel.Phase, precise: Bool) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        if phase == .longRest { session.now += 5_400 }
        session.controller.update()
        let before = try #require(session.controller.pomodoro.clockSchedule)
        let angle = phase == .focus ? 150.0 : (phase == .longRest ? 105 : 285)
        let distance: Int32 = precise ? 12 : 1
        try session.scroll(angle: angle, delta: distance, option: true, precise: precise)
        let edited = try #require(session.controller.pomodoro.clockSchedule)
        #expect(edited.end(for: phase) == before.end(for: phase) + 60)
        if phase == .focus {
            #expect(edited.restEnd == before.restEnd + 60)
            #expect(edited.longRestEnd == before.longRestEnd + 60)
        } else {
            #expect(edited.focusEnd == before.focusEnd)
        }
        try session.scroll(angle: angle, delta: -distance, option: true, after: 0.01, precise: precise)
        let restored = try #require(session.controller.pomodoro.clockSchedule)
        #expect(restored.focusEnd == before.focusEnd)
        #expect(restored.restEnd == before.restEnd)
        #expect(restored.longRestEnd == before.longRestEnd)
    }

    @Test
    func modifierChangeDiscardsPartialTrackpadTravel() throws {
        let session = ScrollTestSession()
        defer { session.close() }
        try session.scroll(angle: 90, delta: 11, precise: true)
        try session.scroll(angle: 90, delta: 1, option: true, after: 0.01, precise: true)
        #expect(session.controller.timer.remaining == 0)
        try session.scroll(angle: 90, delta: 11, option: true, after: 0.01, precise: true)
        #expect(session.controller.timer.remaining == 60)
        try session.scroll(angle: 90, delta: 11, option: true, after: 0.01, precise: true)
        try session.scroll(angle: 90, delta: 1, after: 0.01, precise: true)
        #expect(session.controller.timer.remaining == 60)
        try session.scroll(angle: 90, delta: 11, after: 0.01, precise: true)
        #expect(session.controller.timer.remaining == 300)
        try session.scroll(angle: 90, delta: 120, option: true, momentum: true, precise: true)
        #expect(session.controller.timer.remaining == 300)
    }
}
