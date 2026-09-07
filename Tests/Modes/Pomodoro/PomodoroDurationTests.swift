import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroDurationTests {
    @Test
    func durationEditsClampOnlyTheSelectedPhaseAndResetUsesTheEditedPair() {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.rest, by: 120)
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.restDuration == 420)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        #expect(timer.pomodoro.restRemaining == 420)
        timer.adjustPomodoroDuration(.focus, by: 6_000)
        #expect(timer.pomodoro.focusDuration == 2_700)
        #expect(timer.pomodoro.restDuration == 420)
        timer.adjustPomodoroDuration(.rest, by: -6_000)
        #expect(timer.pomodoro.restDuration == 60)
        #expect(timer.pomodoro.focusDuration == 2_700)
        timer.resetPomodoro()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.focusRemaining == 2_700)
        #expect(timer.pomodoro.restRemaining == 60)
        timer.selectMode(.timer)
        timer.adjustPomodoroDuration(.focus, by: -60)
        #expect(timer.pomodoro.focusDuration == 2_700)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [false, true])
    func activeEditsPreserveElapsedTimeAndAdvanceWithoutSpendingRemovedTime(paused: Bool) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 600
        if paused {
            timer.togglePomodoroRunning()
            session.now += 1_200
        }
        timer.adjustPomodoroDuration(.focus, by: 300)
        #expect(timer.pomodoro.focusRemaining == 1_200)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.adjustPomodoroDuration(.rest, by: 120)
        #expect(timer.pomodoro.restRemaining == 420)
        timer.adjustPomodoroDuration(.focus, by: -1_260) // 9 configured, 10 elapsed.
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.restRemaining == 420)
        #expect(timer.pomodoro.phaseLabel == "Rest")
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.adjustPomodoroDuration(.focus, by: 600)
        #expect(timer.pomodoro.focusDuration == 1_140)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.restRemaining == 420)
        if paused { timer.togglePomodoroRunning() }
        session.now += 180
        if paused { timer.togglePomodoroRunning() }
        timer.adjustPomodoroDuration(.rest, by: -240)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        #expect(timer.pomodoro.stage == 2)
        #expect(timer.pomodoro.focusRemaining == 1_140)
        #expect(timer.pomodoro.restRemaining == 180)
        timer.adjustPomodoroDuration(.rest, by: 120)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        #expect(timer.pomodoro.restRemaining == 300)
        timer.resetPomodoro()
        #expect(timer.pomodoro.focusRemaining == 1_140)
        #expect(timer.pomodoro.restRemaining == 300)
        #expect(session.sounds == 0)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        lazy var timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, reminderEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
