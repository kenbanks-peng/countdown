import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollTargetTests {
    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func singleTimerAcceptsTheFullCircleButNotOutside(mode: CountdownMode, isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        session.controller.selectMode(mode)
        let radius = isCompact ? 16.0 : 88
        // Includes the center, the unused sector, and the full perimeter.
        for distance in [0.0, radius / 2, radius] {
            for angle in stride(from: 0.0, to: 360, by: 30) {
                session.controller.timer.clear()
                try session.scroll(angle: angle, radius: distance, delta: 1)
                #expect(session.controller.timer.remaining == 300)
                try session.scroll(angle: angle, radius: distance, delta: 1)
                #expect(session.controller.timer.remaining == 600)
                try session.scroll(angle: angle, radius: distance, delta: -1)
                #expect(session.controller.timer.remaining == 300)
            }
        }
        for angle in stride(from: 0.0, to: 360, by: 30) {
            session.controller.timer.clear()
            try session.scroll(angle: angle, radius: radius + 0.01, delta: 1)
            #expect(session.controller.timer.remaining == 0)
        }
    }

    @Test(arguments: [0.8, 1.5], [false, true])
    func scaledCircleUsesScaledScrollBoundary(scale: Double, isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let side = (isCompact ? 32.0 : 188) * scale
        session.window.setContentSize(NSSize(width: side, height: side))
        // AppKit can round the requested window size to whole points.
        let bounds = try #require(session.window.contentView).bounds
        let radius = min(bounds.width, bounds.height) / 2 - (isCompact ? 0 : 6 * scale)
        let adjuster = ScrollTimeAdjuster(countdown: session.controller, window: session.window,
                                         normalScale: scale, isCompact: { isCompact })
        for distance in [radius + 0.01, radius] {
            let point = NSPoint(x: bounds.midX + distance, y: bounds.midY)
            adjuster.handle(try scrollEvent(in: session.window, at: point, delta: 1))
            #expect(session.controller.timer.remaining == (distance == radius ? 300 : 0))
        }
    }

    @Test(arguments: [false, true])
    func normalPomodoroScrollAdjustsOnlyTheSelectedDuration(isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 285, delta: 12)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 315, delta: -12) // Rest now ends at 330 degrees.
        #expect(timer.pomodoro.restDuration == 300)
        try session.scroll(angle: 180, delta: 12)
        #expect(timer.pomodoro.focusDuration == 1_800)
        try session.scroll(angle: 180, delta: -12)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.restDuration == 300)
        #expect(timer.timer.remaining == 1_800)
    }

    @Test(arguments: [0.0, 149.999, 150, 150.001, 179.999, 180, 270, 359.999], [false, true])
    func boundariesBelongToTheFollowingClockSector(angle: Double, isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        try session.scroll(angle: (angle + 120).truncatingRemainder(dividingBy: 360), delta: 12)
        #expect(session.controller.pomodoro.restDuration == (angle >= 150 && angle < 180 ? 600 : 300))
        #expect(session.controller.pomodoro.focusDuration == (angle < 150 ? 1_800 : 1_500))
    }

    @Test(arguments: [0.0, 88, 88.001, 100], [0.0, 15, 27])
    func circleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = ScrollTestSession()
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        try session.scroll(angle: angle + 270, radius: radius, delta: 12)
        #expect(session.controller.pomodoro.restDuration == (radius == 88 ? 600 : 300))
        #expect(session.controller.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [0.0, 16, 16.001, 20], [0.0, 15, 27])
    func compactCircleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = ScrollTestSession(isCompact: true)
        defer { session.close() }
        session.controller.selectMode(.pomodoro)
        try session.scroll(angle: angle + 270, radius: radius, delta: 12)
        #expect(session.controller.pomodoro.restDuration == (radius == 16 ? 600 : 300))
        #expect(session.controller.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [false, true])
    func clockFaceScrollTargetsTheVisibleFocusAndRest(isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 150, delta: -12) // Focus ends at :40; rest moves to :45.
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.restDuration == 300)
        try session.scroll(angle: 282, delta: 12) // The old rest sector is now background.
        #expect(timer.pomodoro.restDuration == 300)
        try session.scroll(angle: 252, delta: 12) // Rest ends at :50; focus still ends at :40.
        #expect(timer.pomodoro.restDuration == 600)
        try session.scroll(angle: 15, delta: 12) // Background, not the duration-only rest target.
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_200)
    }

    @Test(arguments: [0.0, 119.999, 120, 149.999, 150, 329.999, 330, 359.999], [false, true])
    func clockFaceScrollWrapsAtTwelveAndUsesVisibleBoundaries(angle: Double, isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        session.now += 2_100 // :55, before controller creation.
        let timer = session.controller
        timer.selectMode(.pomodoro)
        let focus = angle < 120 || angle >= 330
        let rest = angle >= 120 && angle < 150
        try session.scroll(angle: angle, delta: focus ? -12 : 12)
        #expect(timer.pomodoro.focusDuration == (focus ? 1_200 : 1_500))
        #expect(timer.pomodoro.restDuration == (rest ? 600 : 300))
    }

    @Test(arguments: [false, true], [false, true])
    func clockFaceTargetsFollowElapsedTimeAndPausedClock(paused: Bool, isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        session.now += 600
        if paused {
            timer.toggleRunning()
            session.now += 600
        }
        try session.scroll(angle: 282, delta: 12) // Paused sectors retain their fixed endpoints.
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 150, delta: 12) // Completed focus area is not a target.
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusRemaining == 900)
    }

    @Test(arguments: [false, true])
    func clockFaceRestPhaseDoesNotTargetCompletedFocus(isCompact: Bool) throws {
        let session = ScrollTestSession(isCompact: isCompact)
        defer { session.close() }
        let timer = session.controller
        timer.selectMode(.pomodoro)
        session.now += 1_620 // :47, three minutes of rest remain.
        try session.scroll(angle: 288, delta: 12)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.restRemaining == 480) // Ends at :55.
        try session.scroll(angle: 240, delta: 12)
        #expect(timer.pomodoro.focusDuration == 1_500)
    }

}
