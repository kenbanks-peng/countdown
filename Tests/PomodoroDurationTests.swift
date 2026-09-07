import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroDurationTests {
    @Test
    func readyEditsClampOnlyTheSelectedPhaseAndResetUsesTheEditedPair() {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.breakDuration == 420)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        #expect(timer.pomodoro.breakRemaining == 420)
        timer.adjustPomodoroDuration(.focus, by: 6_000)
        #expect(timer.pomodoro.focusDuration == 3_180)
        #expect(timer.pomodoro.breakDuration == 420)
        timer.adjustPomodoroDuration(.shortBreak, by: -6_000)
        #expect(timer.pomodoro.breakDuration == 60)
        #expect(timer.pomodoro.focusDuration == 3_180)
        timer.resetPomodoro()
        #expect(timer.pomodoro.status == .ready)
        #expect(timer.pomodoro.focusRemaining == 3_180)
        #expect(timer.pomodoro.breakRemaining == 60)
        timer.selectMode(.countdown)
        timer.adjustPomodoroDuration(.focus, by: -60)
        #expect(timer.pomodoro.focusDuration == 3_180)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [false, true])
    func activeEditsPreserveElapsedTimeAndCompleteWithoutSpendingRemovedTime(paused: Bool) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.togglePomodoroRunning()
        session.now += 600
        if paused {
            timer.togglePomodoroRunning()
            session.now += 1_200
        }
        timer.adjustPomodoroDuration(.focus, by: 300)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        #expect(timer.pomodoro.breakRemaining == 420)
        timer.adjustPomodoroDuration(.focus, by: -1_260) // 9 configured, 10 elapsed.
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 420)
        #expect(timer.pomodoro.phaseLabel == "Break")
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.adjustPomodoroDuration(.focus, by: 600)
        #expect(timer.pomodoro.focusDuration == 1_140)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 420)
        if paused { timer.togglePomodoroRunning() }
        session.now += 180
        if paused { timer.togglePomodoroRunning() }
        timer.adjustPomodoroDuration(.shortBreak, by: -240)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 0)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.breakRemaining == 0)
        timer.togglePomodoroRunning()
        #expect(timer.pomodoro.focusRemaining == 1_140)
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
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
