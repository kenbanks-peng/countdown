import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollTimeAdjusterTests {
    @Test
    func timerScrollUsesFiveMinuteStepsAndStopsAtFiveMinutes() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer.timer
        try session.scroll(angle: 90, delta: 30)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: 1)
        #expect(timer.remaining == 600)
        try session.scroll(angle: 90, delta: -30)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: -30)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: 7, option: true)
        #expect(timer.remaining == 300)
        try session.scroll(angle: 90, delta: 29, option: true)
        #expect(timer.remaining == 1_200) // Three marks, not three minutes.
    }

    @Test(arguments: [false, true])
    func normalPomodoroScrollAdjustsOnlyTheSelectedDuration(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 15, delta: 30)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 45, delta: -1) // Rest now ends at 60 degrees.
        #expect(timer.pomodoro.restDuration == 300)
        try session.scroll(angle: 90, delta: 30)
        #expect(timer.pomodoro.focusDuration == 1_800)
        try session.scroll(angle: 90, delta: -30)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.restDuration == 300)
        #expect(timer.timer.status == .empty)
    }

    @Test(arguments: [0.0, 29.999, 30, 30.001, 179.999, 180, 270, 359.999], [false, true])
    func boundariesBelongToTheFollowingAllocatedSector(angle: Double, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, delta: 1)
        #expect(session.timer.pomodoro.restDuration == (angle < 30 ? 600 : 300))
        #expect(session.timer.pomodoro.focusDuration == (angle >= 30 && angle < 180 ? 1_800 : 1_500))
    }

    @Test(arguments: [0.0, 88, 88.001, 100], [0.0, 15, 27])
    func circleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, radius: radius, delta: 1)
        #expect(session.timer.pomodoro.restDuration == (radius == 88 ? 600 : 300))
        #expect(session.timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [0.0, 16, 16.001, 20], [0.0, 15, 27])
    func compactCircleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = Session(isCompact: true)
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, radius: radius, delta: 1)
        #expect(session.timer.pomodoro.restDuration == (radius == 16 ? 600 : 300))
        #expect(session.timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [false, true])
    func optionAccumulatesMarksAndClearsOnTargetAndBackgroundChanges(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 90, delta: 7, option: true)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.pomodoro.focusDuration == 1_800)
        try session.scroll(angle: 90, delta: 31, option: true)
        #expect(timer.pomodoro.focusDuration == 2_400) // Two marks, remainder 7.
        try session.scroll(angle: 15, delta: 5, option: true)
        #expect(timer.pomodoro.restDuration == 300)
        try session.scroll(angle: 15, delta: 7, option: true)
        #expect(timer.pomodoro.restDuration == 600)
        try session.scroll(angle: 90, delta: -7, option: true)
        try session.scroll(angle: 315, delta: 0, option: true)
        try session.scroll(angle: 90, delta: -5, option: true)
        #expect(timer.pomodoro.focusDuration == 2_400)
        try session.scroll(angle: 90, delta: -1) // Ordinary scroll clears the remainder.
        try session.scroll(angle: 90, delta: -7, option: true)
        #expect(timer.pomodoro.focusDuration == 2_100)
        try session.scroll(angle: 90, delta: -5, option: true)
        #expect(timer.pomodoro.focusDuration == 1_800)
    }

    @Test
    func modeAndFaceChangesClearOptionRemainderWithoutChangingDurations() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer
        try session.scroll(angle: 90, delta: 1)
        try session.scroll(angle: 90, delta: 7, option: true)
        timer.selectMode(.pomodoro)
        timer.selectMode(.timer)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.timer.remaining == 300)
        timer.features.setClockEnabled(true)
        timer.features.setClockEnabled(false)
        try session.scroll(angle: 90, delta: 7, option: true)
        #expect(timer.timer.remaining == 300)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.timer.remaining == 600)
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
        let angle = phase == .focus ? 120.0 : 0
        let selected = {
            switch phase {
            case .focus: return timer.pomodoro.focusDuration
            case .rest: return timer.pomodoro.restDuration
            case .longRest: return timer.pomodoro.longRestDuration
            }
        }
        try session.scroll(angle: angle, delta: 1_200, option: true)
        #expect(selected() == (phase == .focus ? 2_700 : 2_100))
        try session.scroll(angle: angle, delta: 1)
        #expect(selected() == (phase == .focus ? 2_700 : 2_100))
        try session.scroll(angle: angle, delta: -1_200, option: true)
        #expect(selected() == 300)
        let minimumAngle = phase == .focus ? 45.0 : 0
        try session.scroll(angle: minimumAngle, delta: -1)
        #expect(selected() == 300)
        try session.scroll(angle: minimumAngle, delta: 1)
        #expect(selected() == 600)
        #expect(timer.pomodoro.status == .running)
        #expect(timer.timer.status == .empty)
    }

    @Test
    func fullCircleSeamTargetsRestAndEditsRecomputeTheNextOptionTarget() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.longRest, by: -600)
        timer.adjustPomodoroDuration(.rest, by: 300)
        timer.adjustPomodoroDuration(.focus, by: 1_500)
        try session.scroll(angle: 0, delta: -1)
        #expect(timer.pomodoro.restDuration == 300)
        #expect(timer.pomodoro.focusDuration == 3_000)
        timer.adjustPomodoroDuration(.rest, by: 300)
        try session.scroll(angle: 45, delta: -19, option: true)
        #expect(timer.pomodoro.restDuration == 300)
        try session.scroll(angle: 45, delta: -5, option: true) // Now focus; discard rest's -7.
        #expect(timer.pomodoro.focusDuration == 3_000)
        try session.scroll(angle: 45, delta: -7, option: true)
        #expect(timer.pomodoro.focusDuration == 2_700)
    }

    @Test(arguments: [false, true], [false, true])
    func scrollEditsRunningAndPausedDurationsWithoutRefillingCompletedFocus(paused: Bool, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 600
        if paused {
            timer.toggleRunning()
            session.now += 1_200
        }
        try session.scroll(angle: 150, delta: -1) // Depleted green remains a focus target.
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.focusRemaining == 600)
        try session.scroll(angle: 90, delta: 24, option: true)
        #expect(timer.pomodoro.focusDuration == 1_800)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        try session.scroll(angle: 90, delta: -120, option: true)
        #expect(timer.pomodoro.focusDuration == 300)
        #expect(timer.pomodoro.focusRemaining == 0)
        try session.scroll(angle: 45, delta: 1)
        #expect(timer.pomodoro.focusDuration == 600)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.restRemaining == 300)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        #expect(session.sounds == 0)
    }

    @Test(arguments: [false, true])
    func fourthStageScrollEditsLongRestWithoutChangingShortRest(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 7_200
        try session.scroll(angle: 45, delta: 1)
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
        timer.features.setClockEnabled(true)
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 150, delta: 1) // Focus from :20 to :45 becomes :20 to :50.
        #expect(timer.pomodoro.focusDuration == 1_800)
        try session.scroll(angle: 312, delta: 1) // Rest from :50 to :55 becomes :50 to :00.
        #expect(timer.pomodoro.restDuration == 600)
        try session.scroll(angle: 15, delta: 1) // Background, not the duration-only rest target.
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_800)
    }

    @Test(arguments: [0.0, 119.999, 120, 149.999, 150, 329.999, 330, 359.999], [false, true])
    func clockFaceScrollWrapsAtTwelveAndUsesVisibleBoundaries(angle: Double, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        session.now += 2_100 // :55, before controller creation.
        let timer = session.timer
        timer.features.setClockEnabled(true)
        timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, delta: 1)
        let focus = angle < 120 || angle >= 330
        let rest = angle >= 120 && angle < 150
        #expect(timer.pomodoro.focusDuration == (focus ? 1_800 : 1_500))
        #expect(timer.pomodoro.restDuration == (rest ? 600 : 300))
    }

    @Test(arguments: [false, true], [false, true])
    func clockFaceTargetsFollowElapsedTimeAndPausedClock(paused: Bool, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.features.setClockEnabled(true)
        timer.selectMode(.pomodoro)
        session.now += 600
        if paused {
            timer.toggleRunning()
            session.now += 600
        }
        try session.scroll(angle: paused ? 342 : 282, delta: 1)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 150, delta: 1) // Completed focus area is not a target.
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusRemaining == 900)
    }

    @Test(arguments: [false, true])
    func clockFaceRestPhaseDoesNotTargetCompletedFocus(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.features.setClockEnabled(true)
        timer.selectMode(.pomodoro)
        session.now += 1_620 // :47, three minutes of rest remain.
        try session.scroll(angle: 288, delta: 1)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.restRemaining == 480) // Ends at :55.
        try session.scroll(angle: 240, delta: 1)
        #expect(timer.pomodoro.focusDuration == 1_500)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 20))!
        var sounds = 0
        let window: NSWindow
        let isCompact: Bool
        lazy var timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(clockEnabled: false, popupEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now },
            saveEnablement: { _, _ in }
        )
        lazy var adapter = ScrollTimeAdjuster(countdown: timer, window: window, isCompact: { [unowned self] in isCompact })

        init(isCompact: Bool = false) {
            self.isCompact = isCompact
            _ = NSApplication.shared
            let side = isCompact ? 32 : 188
            window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: side, height: side), styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
        }

        func scroll(angle: Double, radius: Double? = nil, delta: Int32, option: Bool = false) throws {
            let radians = angle * .pi / 180
            let radius = radius ?? (isCompact ? 14 : 66)
            let center = isCompact ? 16.0 : 94
            let point = NSPoint(x: center + radius * sin(radians), y: center + radius * cos(radians))
            adapter.handle(try scrollEvent(in: window, at: point, delta: delta, option: option))
        }

        func close() {
            window.close()
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
