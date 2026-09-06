import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroLifecycleTests {
    @Test
    func clickStartsFocusAndUpdatesUseElapsedTimeAcrossOneSilentPair() {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 600
        timer.update()
        #expect(timer.pomodoro.status == .ready)
        timer.togglePomodoroRunning()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.phaseLabel == "Focus")
        session.now += 600
        timer.update()
        #expect(timer.pomodoro.focusRemaining == 900)
        #expect(timer.pomodoro.breakRemaining == 300)
        timer.setCountdownToNextHour()
        timer.adjustCountdownDuration(by: 60)
        timer.toggleCountdownRunning()
        #expect(timer.countdown.status == .empty)
        #expect(timer.pomodoro.focusRemaining == 900)
        #expect(timer.pomodoro.status == .running)
        session.now += 900
        timer.update()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.phaseLabel == "Break")
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 300)
        session.now += 120
        timer.update()
        #expect(timer.pomodoro.breakRemaining == 180)
        session.now += 180
        timer.update()
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.breakRemaining == 0)
        session.now += 3_600
        timer.update()
        timer.update()
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(session.sounds == 0)
        timer.togglePomodoroRunning()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.phaseLabel == "Focus")
        #expect(timer.pomodoro.focusRemaining == 1_500)
        #expect(timer.pomodoro.breakRemaining == 300)
    }

    @Test(arguments: [600.0, 1_500, 1_620, 1_800, 3_900])
    func switchingModesAccountsForDelayedTimeAndNeverResumesHiddenPomodoro(elapsed: TimeInterval) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.togglePomodoroRunning()
        session.now += elapsed
        timer.selectMode(.countdown)
        if elapsed == 600 {
            #expect(timer.pomodoro.status == .paused)
            #expect(timer.pomodoro.focusRemaining == 900)
            #expect(timer.pomodoro.breakRemaining == 300)
        } else if elapsed == 1_500 {
            #expect(timer.pomodoro.status == .paused)
            #expect(timer.pomodoro.focusRemaining == 0)
            #expect(timer.pomodoro.breakRemaining == 300)
        } else if elapsed == 1_620 {
            #expect(timer.pomodoro.status == .paused)
            #expect(timer.pomodoro.focusRemaining == 0)
            #expect(timer.pomodoro.breakRemaining == 180)
        } else {
            #expect(timer.pomodoro.status == .completed)
            #expect(timer.pomodoro.focusRemaining == 0)
            #expect(timer.pomodoro.breakRemaining == 0)
        }
        let focus = timer.pomodoro.focusRemaining
        let shortBreak = timer.pomodoro.breakRemaining
        session.now += 1_200
        timer.togglePomodoroRunning() // Hidden timer commands are ignored.
        timer.resetPomodoro()
        timer.update()
        timer.selectMode(.pomodoro)
        timer.update()
        #expect(timer.pomodoro.focusRemaining == focus)
        #expect(timer.pomodoro.breakRemaining == shortBreak)
        #expect(timer.pomodoro.status != .running)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [600.0, 1_620])
    func clickPausesAndResumesEachPhaseWithAccessibleState(elapsed: TimeInterval) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        #expect(timer.pomodoro.controlLabel == "Start")
        timer.togglePomodoroRunning()
        #expect(timer.pomodoro.controlLabel == "Pause")
        session.now += elapsed
        timer.togglePomodoroRunning()
        #expect(timer.pomodoro.status == .paused)
        #expect(timer.pomodoro.controlLabel == "Resume")
        let pausedDescription = elapsed == 600
            ? "Pomodoro paused. Focus: 15 minutes remaining. Break: 5 minutes remaining."
            : "Pomodoro paused. Break: 3 minutes remaining. Focus complete."
        #expect(timer.pomodoro.accessibilityDescription == pausedDescription)
        session.now += 1_200
        timer.update()
        timer.selectMode(.countdown)
        timer.selectMode(.pomodoro)
        #expect(timer.pomodoro.accessibilityDescription == pausedDescription)
        timer.togglePomodoroRunning()
        timer.selectMode(.pomodoro) // Selecting the current mode does not pause.
        #expect(timer.pomodoro.status == .running)
        session.now += 60
        timer.update()
        if elapsed == 600 {
            #expect(timer.pomodoro.focusRemaining == 840)
            #expect(timer.pomodoro.breakRemaining == 300)
            #expect(timer.pomodoro.accessibilityDescription == "Pomodoro running. Focus: 14 minutes remaining. Break: 5 minutes remaining.")
        } else {
            #expect(timer.pomodoro.focusRemaining == 0)
            #expect(timer.pomodoro.breakRemaining == 120)
            #expect(timer.pomodoro.accessibilityDescription == "Pomodoro running. Break: 2 minutes remaining. Focus complete.")
        }
        session.now += 3_900
        timer.update()
        #expect(timer.pomodoro.controlLabel == "Start")
        #expect(timer.pomodoro.accessibilityDescription == "Pomodoro complete. Focus: 0 minutes remaining. Break: 0 minutes remaining.")
        #expect(session.sounds == 0)
    }

    @Test(arguments: [0.0, 600, 1_620, 3_900], [false, true])
    func resetReturnsEveryStateToAFullReadyPair(elapsed: TimeInterval, pause: Bool) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        if elapsed > 0 {
            timer.togglePomodoroRunning()
            session.now += elapsed
            timer.update()
            if pause && timer.pomodoro.status == .running {
                timer.togglePomodoroRunning()
            }
        }
        timer.resetPomodoro()
        #expect(timer.pomodoro.status == .ready)
        #expect(timer.pomodoro.focusRemaining == 1_500)
        #expect(timer.pomodoro.breakRemaining == 300)
        #expect(timer.pomodoro.phaseLabel == "Focus")
        #expect(timer.pomodoro.controlLabel == "Start")
        session.now += 3_900
        timer.update()
        #expect(timer.pomodoro.status == .ready)
        #expect(timer.pomodoro.focusRemaining == 1_500)
        #expect(timer.pomodoro.breakRemaining == 300)
        #expect(session.sounds == 0)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        lazy var timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )

        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
