import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownControllerTests {
    @Test
    func selectingPomodoroPausesCountdownAtCommandTimeAndKeepsAllocationsSeparate() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupEnabled: false),
            playSound: { _ in sounds += 1 },
            now: { now }
        )
        #expect(timer.mode == .timer)
        timer.adjustTimerDuration(by: 1_200)
        now += 75
        timer.selectMode(.pomodoro)
        #expect(timer.mode == .pomodoro)
        #expect(timer.timer.isPaused)
        #expect(timer.timer.remaining == 1_125)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        #expect(timer.pomodoro.phaseLabel == "Focus")
        #expect(timer.pomodoro.accessibilityDescription == "Pomodoro ready. Focus: 25 minutes allocated. Break: 5 minutes allocated.")
        now += 600
        timer.update()
        timer.selectMode(.timer)
        #expect(timer.timer.remaining == 1_125)
        #expect(timer.timer.isPaused)
        timer.toggleTimerRunning()
        now += 5
        timer.update()
        #expect(timer.timer.remaining == 1_120)
        #expect(sounds == 0)
    }

    @Test
    func countdownCommandsAndRestorationKeepTheirEstablishedRules() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let configuration = CountdownConfiguration(
            alarmNotificationURL: nil, clockFaceEnabled: false,
            clockHandsEnabled: false, currentTimeoutEnabled: false
        )
        let timer = CountdownController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        timer.adjustTimerDuration(by: 360)
        timer.selectMode(.timer)
        #expect(timer.timer.status == .active, "Selecting the current mode must not pause")
        now += 61
        timer.update()
        #expect(timer.timer.remaining == 299)
        #expect(timer.features.wakeupIntervalCount == 1)
        #expect(sounds == 1)
        timer.save()
        now += 9
        let restored = CountdownController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        #expect(restored.timer.status == .active)
        #expect(restored.timer.remaining == 290)
        restored.selectMode(.pomodoro)
        restored.save()
        #expect(!restored.features.isClockFaceEnabled)
        #expect(!restored.features.isClockHandsEnabled)
        #expect(!restored.timer.isCurrentTimeoutEnabled)
        now += 20
        let paused = CountdownController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        #expect(paused.timer.isPaused)
        #expect(paused.timer.remaining == 290)
        #expect(paused.mode == .pomodoro)
        paused.selectMode(.timer)
        paused.toggleTimerRunning()
        now += 290
        paused.update()
        paused.update()
        #expect(paused.timer.status == .empty)
        #expect(paused.timer.completionCount == 1)
        #expect(sounds == 2)
        paused.selectMode(.pomodoro)
        paused.selectMode(.timer)
        #expect(paused.timer.status == .empty)
    }

    @Test
    func autosetAndNextHourStayCountdownSpecific() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 6, hour: 10, minute: 30))!
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, autosetEnabled: true, wakeupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        #expect(timer.timer.remaining == 1_800)
        now += 1_800
        timer.selectMode(.pomodoro)
        #expect(timer.timer.isPaused)
        #expect(timer.timer.remaining == 3_600)
        #expect(timer.timer.isAutosetEnabled)
        now += 120
        timer.setTimerToNextHour()
        timer.update()
        #expect(timer.timer.remaining == 3_600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        timer.selectMode(.timer)
        timer.setTimerToNextHour()
        #expect(timer.timer.remaining == 3_480)
        #expect(timer.timer.isPaused)
    }
}
