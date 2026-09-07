import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroLifecycleTests {
    @Test
    func coreStartsFocusAndAdvancesAcrossOneSilentPair() {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        #expect(timer.pomodoro.status == .running)
        #expect(timer.controlLabel == "Pause")
        session.now += 600
        timer.update()
        #expect(timer.pomodoro.focusRemaining == 900)
        #expect(timer.pomodoro.breakRemaining == 300)
        timer.setTimerToNextHour()
        timer.adjustTimerDuration(by: 60)
        timer.toggleTimerRunning() // A command for a hidden UI mode is ignored.
        #expect(timer.timer.status == .empty)
        #expect(timer.pomodoro.status == .running)
        session.now += 900
        timer.update()
        #expect(timer.pomodoro.phaseLabel == "Break")
        #expect(timer.pomodoro.breakRemaining == 300)
        session.now += 120
        timer.update()
        #expect(timer.pomodoro.breakRemaining == 180)
        session.now += 180
        timer.update()
        #expect(timer.pomodoro.status == .completed)
        #expect(!timer.countdown.isPaused)
        session.now += 3_600
        timer.update()
        #expect(timer.pomodoro.status == .completed)
        #expect(session.sounds == 0)
        timer.resetPomodoro()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.focusRemaining == 1_500)
    }

    @Test(arguments: [600.0, 1_500, 1_620, 1_800, 3_900])
    func switchingModesKeepsHiddenPomodoroAdvancing(elapsed: TimeInterval) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += elapsed
        timer.selectMode(.timer)
        #expect(timer.pomodoro.focusRemaining == max(0, 1_500 - elapsed))
        #expect(timer.pomodoro.breakRemaining == max(0, 300 - max(0, elapsed - 1_500)))
        #expect(!timer.countdown.isPaused)
        session.now += 1_200
        timer.togglePomodoroRunning()
        timer.resetPomodoro() // Hidden UI commands do not change the core.
        timer.selectMode(.pomodoro)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 0)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [600.0, 1_620])
    func pauseAndResumeApplyAcrossModes(elapsed: TimeInterval) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.adjustTimerDuration(by: 3_600)
        timer.selectMode(.pomodoro)
        session.now += elapsed
        timer.toggleRunning()
        #expect(timer.pomodoro.status == .paused)
        #expect(timer.timer.isPaused)
        #expect(timer.controlLabel == "Resume")
        let description = timer.pomodoro.accessibilityDescription
        let focus = timer.pomodoro.focusRemaining
        let shortBreak = timer.pomodoro.breakRemaining
        let remaining = timer.timer.remaining
        session.now += 1_200
        timer.selectMode(.timer)
        #expect(timer.controlLabel == "Resume")
        #expect(timer.timer.remaining == remaining)
        #expect(timer.pomodoro.accessibilityDescription == description)
        timer.toggleRunning()
        session.now += 60
        timer.selectMode(.pomodoro)
        #expect(timer.controlLabel == "Pause")
        #expect(timer.pomodoro.status == .running)
        #expect(timer.timer.remaining == remaining - 60)
        #expect(timer.pomodoro.focusRemaining == max(0, focus - 60))
        #expect(timer.pomodoro.breakRemaining == shortBreak - (focus == 0 ? 60 : 0))
        #expect(session.sounds == 0)
    }

    @Test(arguments: [0.0, 600, 1_620, 3_900], [false, true])
    func resetKeepsTheCoreRunState(elapsed: TimeInterval, pause: Bool) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += elapsed
        timer.update()
        if pause { timer.toggleRunning() }
        timer.resetPomodoro()
        #expect(timer.pomodoro.status == (pause ? .paused : .running))
        #expect(timer.pomodoro.focusRemaining == 1_500)
        #expect(timer.pomodoro.breakRemaining == 300)
        #expect(timer.countdown.isPaused == pause)
        session.now += 60
        timer.update()
        #expect(timer.pomodoro.focusRemaining == (pause ? 1_500 : 1_440))
        #expect(session.sounds == 0)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        lazy var timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
