import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollTimeAdjusterTests {
    @Test
    func wheelNotchesAreNotDroppedWhenTheyArriveQuickly() throws {
        let session = Session()
        defer { session.close() }
        for _ in 0..<3 { try session.scroll(angle: 90, delta: 1, after: 0.02) }
        #expect(session.timer.timer.remaining == 900)
    }

    @Test
    func preciseScrollUsesDistanceInsteadOfElapsedTime() throws {
        let session = Session()
        defer { session.close() }
        for _ in 0..<11 {
            try session.scroll(angle: 90, delta: 1, after: 0.16, phase: .changed, precise: true)
        }
        #expect(session.timer.timer.remaining == 0)
        try session.scroll(angle: 90, delta: 1, after: 0.001, phase: .changed, precise: true)
        #expect(session.timer.timer.remaining == 300)
    }

    @Test
    func slowActiveGestureKeepsTheShrinkingSectorSelected() throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: 264, delta: -12, phase: .began, precise: true)
        try session.scroll(angle: 264, delta: -12, after: 0.6, phase: .changed, precise: true)
        #expect(session.timer.pomodoro.focusDuration == 900)
        #expect(session.timer.pomodoro.restDuration == 300)
    }

    @Test(arguments: [false, true])
    func optionRequiresThreeTimesTheScrollTravel(precise: Bool) throws {
        let session = Session()
        defer { session.close() }
        let distance: Int32 = precise ? 12 : 1
        for _ in 0..<2 {
            try session.scroll(angle: 90, delta: distance, option: true, after: 0.01, precise: precise)
            #expect(session.timer.timer.remaining == 0)
        }
        try session.scroll(angle: 90, delta: distance, option: true, after: 0.01, precise: precise)
        #expect(session.timer.timer.remaining == 300)
        try session.scroll(angle: 90, delta: distance, after: 0.01, precise: precise)
        #expect(session.timer.timer.remaining == 600)
    }

    @Test
    func preciseScrollDoesNotStoreExcessTravelAtTheLimit() throws {
        let session = Session()
        defer { session.close() }
        session.timer.adjustTimerDuration(by: 3_600)
        for _ in 0..<10 {
            try session.scroll(angle: 90, delta: 1_200, after: 0.01, precise: true)
        }
        #expect(session.timer.timer.remaining == 3_600)
        try session.scroll(angle: 90, delta: -12, after: 0.01, precise: true)
        #expect(session.timer.timer.remaining == 3_300)
    }

    @Test
    func preciseInputIsMarkedAsPreciseAndWheelInputIsNot() throws {
        let session = Session()
        defer { session.close() }
        for precise in [false, true] {
            let event = try scrollEvent(in: session.window, at: .zero, delta: 1, precise: precise)
            #expect(event.hasPreciseScrollingDeltas == precise)
        }
    }

    @Test
    func focusScrollAtThreeTwentyFiveCanFillTheHourAhead() throws {
        let session = Session()
        defer { session.close() }
        session.now = Calendar.current.startOfDay(for: session.now) + 3 * 3_600 + 10 * 60
        let timer = session.timer
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

    @Test(arguments: [-1, 1])
    func preciseScrollAccumulatesTravelAndDiscardsItOnReversal(direction: Int32) throws {
        let session = Session()
        defer { session.close() }
        session.timer.adjustTimerDuration(by: 1_500)
        try session.scroll(angle: 90, delta: direction * 12, precise: true)
        #expect(session.timer.timer.remaining == 1_500 + Double(direction) * 300)
        for _ in 0..<11 {
            try session.scroll(angle: 90, delta: direction, after: 0.001, precise: true)
        }
        #expect(session.timer.timer.remaining == 1_500 + Double(direction) * 300)
        try session.scroll(angle: 90, delta: -direction, after: 0.001, precise: true)
        #expect(session.timer.timer.remaining == 1_500 + Double(direction) * 300)
        try session.scroll(angle: 90, delta: -direction * 11, after: 0.001, precise: true)
        #expect(session.timer.timer.remaining == 1_500)
    }

    @Test
    func downwardScrollKeepsItsTargetWhenTheSectorShrinks() throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        // :44 is initially focus, but becomes rest after the first decrease.
        try session.scroll(angle: 264, delta: -12)
        #expect(session.timer.pomodoro.focusDuration == 1_200)
        try session.scroll(angle: 264, delta: -12, after: 0.16)
        #expect(session.timer.pomodoro.focusDuration == 900)
        #expect(session.timer.pomodoro.restDuration == 300)
        // The same pointer is now over background, but this is still the same scroll.
        try session.scroll(angle: 264, delta: -12, after: 0.16)
        #expect(session.timer.pomodoro.focusDuration == 600)
        try session.scroll(angle: 264, delta: -12, after: 0.5)
        #expect(session.timer.pomodoro.focusDuration == 600)
    }

    @Test(arguments: [NSEvent.Phase.ended, .cancelled])
    func endedGesturesReleaseTheTargetAndMomentumDoesNotEdit(ending: NSEvent.Phase) throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: 264, delta: -1, phase: .began)
        #expect(session.timer.pomodoro.focusDuration == 1_200)
        try session.scroll(angle: 264, delta: 0, after: 0.001, phase: ending)
        // The same point must select rest once the previous gesture has ended.
        try session.scroll(angle: 264, delta: 1, after: 0.001)
        #expect(session.timer.pomodoro.focusDuration == 1_200)
        #expect(session.timer.pomodoro.restDuration == 600)
        try session.scroll(angle: 264, delta: 100, after: 0.16, momentum: true)
        #expect(session.timer.pomodoro.restDuration == 600)
        try session.scroll(angle: 264, delta: 1, after: 0.001, phase: .began)
        #expect(session.timer.pomodoro.restDuration == 900)
    }

    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func timerScrollUsesFiveMinuteStepsAndStopsAtFiveMinutes(mode: CountdownMode, option: Bool) throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(mode)
        let timer = session.timer.timer
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

    @Test(arguments: [false, true])
    func normalPomodoroScrollAdjustsOnlyTheSelectedDuration(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
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
        #expect(timer.timer.status == .empty)
    }

    @Test(arguments: [0.0, 149.999, 150, 150.001, 179.999, 180, 270, 359.999], [false, true])
    func boundariesBelongToTheFollowingClockSector(angle: Double, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: (angle + 120).truncatingRemainder(dividingBy: 360), delta: 12)
        #expect(session.timer.pomodoro.restDuration == (angle >= 150 && angle < 180 ? 600 : 300))
        #expect(session.timer.pomodoro.focusDuration == (angle < 150 ? 1_800 : 1_500))
    }

    @Test(arguments: [0.0, 88, 88.001, 100], [0.0, 15, 27])
    func circleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle + 270, radius: radius, delta: 12)
        #expect(session.timer.pomodoro.restDuration == (radius == 88 ? 600 : 300))
        #expect(session.timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [0.0, 16, 16.001, 20], [0.0, 15, 27])
    func compactCircleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = Session(isCompact: true)
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle + 270, radius: radius, delta: 12)
        #expect(session.timer.pomodoro.restDuration == (radius == 16 ? 600 : 300))
        #expect(session.timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [false, true])
    func pointerMovementSelectsANewTargetWithoutWaiting(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 180, delta: 3, option: true)
        #expect(timer.pomodoro.focusDuration == 1_800)
        try session.scroll(angle: 315, delta: 3, option: true, after: 0.001)
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
        let session = Session()
        defer { session.close() }
        let timer = session.timer
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
        #expect(timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [PomodoroModel.Phase.focus, .rest, .longRest], [false, true])
    func scrollClampsAllocationsToFiveMinutesAndAvailableCapacity(phase: PomodoroModel.Phase, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
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
        #expect(timer.timer.status == .empty)
    }

    @Test(arguments: [false, true])
    func fourthStageScrollEditsLongRestWithoutChangingShortRest(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
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

    @Test(arguments: [false, true])
    func clockFaceScrollTargetsTheVisibleFocusAndRest(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
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
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        session.now += 2_100 // :55, before controller creation.
        let timer = session.timer
        timer.selectMode(.pomodoro)
        let focus = angle < 120 || angle >= 330
        let rest = angle >= 120 && angle < 150
        try session.scroll(angle: angle, delta: focus ? -12 : 12)
        #expect(timer.pomodoro.focusDuration == (focus ? 1_200 : 1_500))
        #expect(timer.pomodoro.restDuration == (rest ? 600 : 300))
    }

    @Test(arguments: [false, true], [false, true])
    func clockFaceTargetsFollowElapsedTimeAndPausedClock(paused: Bool, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
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
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 1_620 // :47, three minutes of rest remain.
        try session.scroll(angle: 288, delta: 12)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.restRemaining == 480) // Ends at :55.
        try session.scroll(angle: 240, delta: 12)
        #expect(timer.pomodoro.focusDuration == 1_500)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 20))!
        var sounds = 0
        var scrollTime: TimeInterval = 0
        let window: NSWindow
        let isCompact: Bool
        lazy var timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now },
            saveEnablement: { _, _ in }
        )
        lazy var adapter = ScrollTimeAdjuster(countdown: timer, window: window,
                                             isCompact: { [unowned self] in isCompact },
                                             uptime: { [unowned self] in scrollTime })

        init(isCompact: Bool = false) {
            self.isCompact = isCompact
            _ = NSApplication.shared
            let side = isCompact ? 32 : 188
            window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: side, height: side), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
        }

        func scroll(angle: Double, radius: Double? = nil, delta: Int32, option: Bool = false,
                    after interval: TimeInterval = 0.5, phase: NSEvent.Phase = [], momentum: Bool = false,
                    precise: Bool = false) throws {
            scrollTime += interval
            let radians = angle * .pi / 180
            let radius = radius ?? (isCompact ? 14 : 66)
            let center = isCompact ? 16.0 : 94
            let point = NSPoint(x: center + radius * sin(radians), y: center + radius * cos(radians))
            adapter.handle(try scrollEvent(in: window, at: point, delta: delta, option: option,
                                           phase: phase, momentum: momentum, precise: precise))
        }

        func close() {
            window.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
