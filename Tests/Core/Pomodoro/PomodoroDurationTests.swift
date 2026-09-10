import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroDurationTests {
    @Test(arguments: [false, true])
    func durationEditsPreserveStageAndPauseState(paused: Bool) {
        let session = Session()
        defer { session.removeState() }
        let timer = session.timer
        timer.selectMode(.pomodoro)
        session.now += 5_400
        timer.update()
        #expect(timer.pomodoro.stage == 4)
        if paused { timer.toggleRunning() }
        timer.adjustPomodoroDuration(.focus, steps: -1)
        timer.adjustPomodoroDuration(.rest, steps: 1)
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.restDuration == 600)
        timer.adjustPomodoroDuration(.longRest, steps: 1)
        #expect(timer.pomodoro.longRestDuration == 1_200)
        #expect(timer.pomodoro.stage == 4)
        #expect(timer.pomodoro.completedFocusPeriods == 3)
        #expect(timer.pomodoro.clockSchedule?.focusDuration == 1_200)
        #expect(timer.pomodoro.clockSchedule?.restDuration == 600)
        #expect(timer.pomodoro.clockSchedule?.longRestDuration == 1_200)
        #expect(timer.engine.isPaused == paused)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.selectMode(.countdown)
        timer.adjustPomodoroDuration(.focus, steps: 1)
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [false, true], [25, 1, 59])
    func startingCyclePreservesDefaultDurationsWithinLimits(paused: Bool, focusMinutes: Int) throws {
        let session = Session()
        defer { session.removeState() }
        session.configuration = CountdownConfiguration(
            alarmNotificationURL: nil, pomodoroFocusMinutes: focusMinutes,
            pomodoroRestMinutes: focusMinutes == 25 ? 5 : 1,
            pomodoroLongRestMinutes: focusMinutes == 25 ? 15 : 1
        )
        let timer = session.timer
        if paused { timer.toggleRunning() }
        session.now += 137.5
        timer.selectMode(.pomodoro)
        let schedule = try #require(timer.pomodoro.clockSchedule)
        let expectedFocus: TimeInterval = focusMinutes == 25 ? 1_500 : (focusMinutes == 1 ? 300 : 3_300)
        #expect(schedule.focusEnd == session.now + expectedFocus)
        #expect(schedule.restEnd == schedule.focusEnd + 300)
        #expect(schedule.longRestEnd == schedule.focusEnd + (focusMinutes == 25 ? 900 : 300))
        #expect(schedule.focusDuration == expectedFocus)
        #expect(schedule.restDuration == 300)
        #expect(schedule.longRestDuration == (focusMinutes == 25 ? 900 : 300))
        #expect(schedule.focusDuration >= 300)
        #expect(schedule.restDuration >= 300)
        #expect(schedule.longRestDuration >= 300)
        #expect(schedule.focusDuration + schedule.restDuration <= 3_600)
        #expect(schedule.stageStart == session.now)
        #expect(timer.pomodoro.stage == 1)
        #expect(timer.pomodoro.completedFocusPeriods == 0)
        #expect(timer.engine.isPaused == paused)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
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
        var configuration = CountdownConfiguration(alarmNotificationURL: nil, pomodoroLongRestMinutes: 15, notificationAudioEnabled: false)
        lazy var timer = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: configuration,
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
