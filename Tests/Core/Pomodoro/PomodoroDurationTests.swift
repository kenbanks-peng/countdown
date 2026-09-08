import Foundation
import Testing
@testable import Countdown

@MainActor
struct PomodoroDurationTests {
    @Test(arguments: [false, true])
    func resetRestoresDefaultsAndFirstCycleWithoutChangingPauseState(paused: Bool) {
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
        timer.resetPomodoro()
        #expect(timer.pomodoro.stage == 1)
        #expect(timer.pomodoro.completedFocusPeriods == 0)
        #expect(timer.pomodoro.focusRemaining == 1_500)
        #expect(timer.pomodoro.restRemaining == 300)
        #expect(timer.pomodoro.clockSchedule?.focusDuration == 1_500)
        #expect(timer.pomodoro.clockSchedule?.restDuration == 300)
        #expect(timer.pomodoro.clockSchedule?.longRestDuration == 900)
        #expect(timer.engine.isPaused == paused)
        #expect(timer.pomodoro.status == (paused ? .paused : .running))
        timer.selectMode(.countdown)
        timer.adjustPomodoroDuration(.focus, steps: 1)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(session.sounds == 0)
    }

    @Test(arguments: [false, true], [25, 1, 59])
    func resetAlignsDefaultsAndEnforcesMinimum(paused: Bool, focusMinutes: Int) throws {
        let session = Session()
        defer { session.removeState() }
        session.configuration = CountdownConfiguration(
            alarmNotificationURL: nil, pomodoroFocusMinutes: focusMinutes,
            pomodoroRestMinutes: focusMinutes == 25 ? 5 : 1,
            pomodoroLongRestMinutes: focusMinutes == 25 ? 15 : 1
        )
        let timer = session.timer
        timer.selectMode(.pomodoro)
        if paused { timer.toggleRunning() }
        session.now += 137.5
        timer.resetPomodoro()
        let schedule = try #require(timer.pomodoro.clockSchedule)
        let origin = Calendar.current.startOfDay(for: session.now)
        for end in [schedule.focusEnd, schedule.restEnd, schedule.longRestEnd] {
            #expect(end.timeIntervalSince(origin).truncatingRemainder(dividingBy: 300) == 0)
        }
        let expectedFocus: TimeInterval = focusMinutes == 25 ? 1_362.5 : (focusMinutes == 1 ? 462.5 : 3_162.5)
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
        var configuration = CountdownConfiguration(alarmNotificationURL: nil, pomodoroLongRestMinutes: 15, audioNotificationEnabled: false)
        lazy var timer = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: configuration,
            preferences: CountdownPreferences(reminderEnabled: false),
            playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
        )
        func removeState() { try? FileManager.default.removeItem(at: directory) }
    }
}
