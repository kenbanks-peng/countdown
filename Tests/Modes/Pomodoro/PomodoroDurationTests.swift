import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroDurationTests {
    @Test(arguments: [false, true])
    func endpointEditsPreservePauseStateAndResetUsesEditedSpacing(paused: Bool) throws {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        if paused { timer.toggleRunning() }
        timer.adjustPomodoroDuration(.focus, steps: -1)
        timer.adjustPomodoroDuration(.rest, steps: 1)
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.restDuration == 600)
        let schedule = try #require(timer.pomodoro.clockSchedule)
        timer.resetPomodoro()
        #expect(timer.pomodoro.clockSchedule?.focusDuration == schedule.focusDuration)
        #expect(timer.pomodoro.clockSchedule?.restDuration == schedule.restDuration)
        #expect(timer.countdown.isPaused == paused)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.selectMode(.countdown)
        timer.adjustPomodoroDuration(.focus, steps: 1)
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [false, true])
    func clockEditsKeepCompletedFocusEmpty(paused: Bool) throws {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 1_620
        timer.update()
        if paused { timer.toggleRunning() }
        timer.adjustPomodoroDuration(.focus, steps: 1)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.clockSchedule?.focusCompleted == true)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        #expect(session.sounds == 0)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        var sounds = 0
        lazy var timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
