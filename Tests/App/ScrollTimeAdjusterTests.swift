import AppKit
import Testing
@testable import Countdown

@MainActor
struct ScrollTimeAdjusterTests {
    @Test
    func modeChangesBlockCountdownScrollAndClearOptionRemainder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            playSound: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let adapter = ScrollTimeAdjuster(countdown: timer)
        adapter.handle(try scroll(delta: 30))
        #expect(timer.timer.remaining == 60)
        adapter.handle(try scroll(delta: 7, option: true))
        timer.selectMode(.pomodoro)
        adapter.handle(try scroll(delta: 30))
        adapter.handle(try scroll(delta: 24, option: true))
        timer.setTimerToNextHour()
        timer.toggleTimerRunning()
        #expect(timer.timer.remaining == 60)
        #expect(timer.timer.status == .active)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        timer.selectMode(.timer)
        adapter.handle(try scroll(delta: 5, option: true))
        #expect(timer.timer.remaining == 60)
        adapter.handle(try scroll(delta: 7, option: true))
        #expect(timer.timer.remaining == 120)
        adapter.handle(try scroll(delta: -30))
        #expect(timer.timer.remaining == 60)
    }

    @Test
    func normalPomodoroScrollAdjustsOnlyTheAllocatedSectorInWholeMinutes() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 15, delta: 30)
        #expect(timer.pomodoro.breakDuration == 360)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 33, delta: -1) // Now blue, after the boundary moved to 36°.
        #expect(timer.pomodoro.breakDuration == 300)
        try session.scroll(angle: 90, delta: 30)
        #expect(timer.pomodoro.focusDuration == 1_560)
        try session.scroll(angle: 90, delta: -30)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        #expect(timer.timer.status == .empty)
        #expect(timer.pomodoro.accessibilityDescription == "Pomodoro running. Focus: 25 minutes remaining. Break: 5 minutes remaining.")
    }

    @Test(arguments: [0.0, 29.999, 30, 30.001, 179.999, 180, 270, 359.999], [false, true])
    func boundariesBelongToTheFollowingAllocatedSector(angle: Double, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, delta: 1)
        if angle < 30 {
            #expect(session.timer.pomodoro.breakDuration == 360)
            #expect(session.timer.pomodoro.focusDuration == 1_500)
        } else if angle < 180 {
            #expect(session.timer.pomodoro.breakDuration == 300)
            #expect(session.timer.pomodoro.focusDuration == 1_560)
        } else {
            #expect(session.timer.pomodoro.breakDuration == 300)
            #expect(session.timer.pomodoro.focusDuration == 1_500)
        }
    }

    @Test(arguments: [0.0, 88, 88.001, 100], [0.0, 15, 27])
    func circleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = Session()
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, radius: radius, delta: -1)
        #expect(session.timer.pomodoro.breakDuration == (radius == 88 ? 240 : 300))
        #expect(session.timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [0.0, 16, 16.001, 20], [0.0, 15, 27])
    func compactCircleIncludesThePerimeterButNotTheCenterOrOutside(radius: Double, angle: Double) throws {
        let session = Session(isCompact: true)
        defer { session.close() }
        session.timer.selectMode(.pomodoro)
        try session.scroll(angle: angle, radius: radius, delta: -1)
        #expect(session.timer.pomodoro.breakDuration == (radius == 16 ? 240 : 300))
        #expect(session.timer.pomodoro.focusDuration == 1_500)
    }

    @Test(arguments: [false, true])
    func optionAccumulatesWholeMinutesAndClearsOnTargetBackgroundOrdinaryAndModeChanges(isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 90, delta: 7, option: true)
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.pomodoro.focusDuration == 1_560)
        try session.scroll(angle: 90, delta: 31, option: true)
        #expect(timer.pomodoro.focusDuration == 1_680) // Two steps, remainder 7.
        try session.scroll(angle: 15, delta: 5, option: true)
        #expect(timer.pomodoro.breakDuration == 300) // Focus remainder cannot enter break.
        try session.scroll(angle: 15, delta: 7, option: true)
        #expect(timer.pomodoro.breakDuration == 360)
        try session.scroll(angle: 15, delta: -31, option: true)
        #expect(timer.pomodoro.breakDuration == 240)
        try session.scroll(angle: 15, delta: -5, option: true)
        #expect(timer.pomodoro.breakDuration == 180)
        try session.scroll(angle: 90, delta: 7, option: true)
        try session.scroll(angle: 270, delta: 0, option: true)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.pomodoro.focusDuration == 1_680)
        try session.scroll(angle: 90, delta: 1)
        try session.scroll(angle: 90, delta: 7, option: true)
        #expect(timer.pomodoro.focusDuration == 1_740)
        timer.selectMode(.timer)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.timer.remaining == 0)
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.pomodoro.focusDuration == 1_740)
        // Even an away-and-back mode change with no event clears the remainder.
        timer.selectMode(.timer)
        timer.selectMode(.pomodoro)
        try session.scroll(angle: 90, delta: 7, option: true)
        #expect(timer.pomodoro.focusDuration == 1_740)
        try session.scroll(angle: 90, delta: 5, option: true)
        #expect(timer.pomodoro.focusDuration == 1_800)
        #expect(timer.pomodoro.breakDuration == 180)
    }

    @Test(arguments: [PomodoroModel.Phase.focus, .shortBreak], [false, true])
    func scrollClampsBothPhasesBelowAtAndAboveCapacityWithoutChangingTheOther(phase: PomodoroModel.Phase, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        if phase == .shortBreak { timer.adjustPomodoroDuration(.focus, by: -1_200) }
        timer.adjustPomodoroDuration(phase, by: phase == .focus ? 1_740 : 2_940)
        let angle = phase == .focus ? 90.0 : 0
        let selected = { phase == .focus ? timer.pomodoro.focusDuration : timer.pomodoro.breakDuration }
        let other = { phase == .focus ? timer.pomodoro.breakDuration : timer.pomodoro.focusDuration }
        #expect(selected() == 3_240)
        #expect(other() == 300)
        try session.scroll(angle: angle, delta: 1)
        #expect(selected() == 3_300)
        try session.scroll(angle: angle, delta: 30)
        #expect(selected() == 3_300)
        try session.scroll(angle: angle, delta: -30)
        #expect(selected() == 3_240)
        try session.scroll(angle: angle, delta: 1_200, option: true)
        #expect(selected() == 3_300)
        #expect(other() == 300)
        try session.scroll(angle: angle, delta: -1_200, option: true)
        #expect(selected() == 60)
        #expect(other() == 300)
        // A minimum sector still has an allocated target. Configured zero is forbidden.
        let minimumAngle = phase == .focus ? 33.0 : 0
        try session.scroll(angle: minimumAngle, delta: -1)
        #expect(selected() == 60)
        try session.scroll(angle: minimumAngle, delta: 1)
        #expect(selected() == 120)
        #expect(other() == 300)
        #expect(timer.pomodoro.status == .running)
        #expect(timer.timer.status == .empty)
    }

    @Test
    func fullCircleTopSeamTargetsBreakAndEditsRecomputeTheNextOptionTarget() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: 1_800)
        try session.scroll(angle: 0, delta: -1)
        #expect(timer.pomodoro.breakDuration == 240)
        #expect(timer.pomodoro.focusDuration == 3_300)
        timer.adjustPomodoroDuration(.focus, by: -1_800)
        timer.adjustPomodoroDuration(.shortBreak, by: 60)
        try session.scroll(angle: 27, delta: -19, option: true)
        #expect(timer.pomodoro.breakDuration == 240)
        try session.scroll(angle: 27, delta: -5, option: true) // Now focus; discard break's -7.
        #expect(timer.pomodoro.focusDuration == 1_500)
        try session.scroll(angle: 27, delta: -7, option: true)
        #expect(timer.pomodoro.focusDuration == 1_440)
    }

    @Test(arguments: [false, true], [false, true])
    func scrollEditsRunningAndPausedAllocationsWithoutRefillingExpiredPhases(paused: Bool, isCompact: Bool) throws {
        let session = Session(isCompact: isCompact)
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 600
        if paused {
            timer.togglePomodoroRunning()
            session.now += 1_200
        }
        try session.scroll(angle: 150, delta: -1) // Depleted green remains a focus target.
        #expect(timer.pomodoro.focusDuration == 1_440)
        #expect(timer.pomodoro.focusRemaining == 840)
        try session.scroll(angle: 90, delta: 72, option: true)
        #expect(timer.pomodoro.focusDuration == 1_800)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        try session.scroll(angle: 15, delta: 1)
        #expect(timer.pomodoro.breakDuration == 360)
        #expect(timer.pomodoro.breakRemaining == 360)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        try session.scroll(angle: 90, delta: -252, option: true)
        #expect(timer.pomodoro.focusDuration == 540)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 360)
        #expect(timer.pomodoro.accessibilityDescription == (paused
            ? "Pomodoro paused. Break: 6 minutes remaining. Focus complete."
            : "Pomodoro running. Break: 6 minutes remaining. Focus complete."))
        try session.scroll(angle: 60, delta: 1) // Completed focus config changes for the next pair only.
        #expect(timer.pomodoro.focusDuration == 600)
        #expect(timer.pomodoro.focusRemaining == 0)
        if paused { timer.togglePomodoroRunning() }
        session.now += 180
        if paused {
            timer.togglePomodoroRunning()
            session.now += 1_200
        }
        try session.scroll(angle: 27, delta: -36, option: true)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.breakDuration == 180)
        #expect(timer.pomodoro.breakRemaining == 0)
        try session.scroll(angle: 15, delta: 1)
        try session.scroll(angle: 60, delta: 1)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 0)
        timer.resetPomodoro()
        #expect(timer.pomodoro.focusRemaining == 660)
        #expect(timer.pomodoro.breakRemaining == 240)
        #expect(timer.timer.status == .empty)
        #expect(session.sounds == 0)
    }

    @Test
    func scrollAccountsForAStalePhaseBeforeApplyingTheEdit() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 1_620
        try session.scroll(angle: 90, delta: -1)
        #expect(timer.pomodoro.focusDuration == 1_440)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 180)
        #expect(timer.pomodoro.phaseLabel == "Break")
        try session.scroll(angle: 27, delta: 1) // Depleted break is still a break target.
        #expect(timer.pomodoro.breakDuration == 360)
        #expect(timer.pomodoro.breakRemaining == 240)
        session.now += 3_900
        try session.scroll(angle: 90, delta: 1)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 0)
        #expect(session.sounds == 0)
    }

    @Test
    func editedBoundariesKeepStartInclusiveAndEndExclusiveOwnership() throws {
        let session = Session()
        defer { session.close() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.shortBreak, by: 1_560) // 31-minute break ends at 186°.
        try session.scroll(angle: 186, delta: -1)
        #expect(timer.pomodoro.breakDuration == 1_860)
        #expect(timer.pomodoro.focusDuration == 1_440)
        timer.adjustPomodoroDuration(.shortBreak, by: -1_440) // 7 + 24 = 31 minutes.
        try session.scroll(angle: 186, delta: -1) // End of allocation is background.
        #expect(timer.pomodoro.breakDuration == 420)
        #expect(timer.pomodoro.focusDuration == 1_440)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let window: NSWindow
        let isCompact: Bool
        lazy var timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
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

    private func scroll(delta: Int32, option: Bool = false) throws -> NSEvent {
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: delta, wheel2: 0, wheel3: 0
        ))
        event.location = CGPoint(x: 120, y: 50)
        event.flags = option ? .maskAlternate : []
        return try #require(NSEvent(cgEvent: event))
    }
}
