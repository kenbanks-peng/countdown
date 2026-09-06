import Foundation
import Testing
@testable import Countdown

@MainActor
struct TimerControllerTests {
    @Test
    func selectingPomodoroPausesCountdownAtCommandTimeAndKeepsAllocationsSeparate() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupEnabled: false),
            playSound: { _ in sounds += 1 },
            now: { now }
        )
        #expect(timer.mode == .countdown)
        timer.adjustCountdownDuration(by: 1_200)
        now += 75
        timer.selectMode(.pomodoro)
        #expect(timer.mode == .pomodoro)
        #expect(timer.countdown.isPaused)
        #expect(timer.countdown.remaining == 1_125)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        #expect(timer.pomodoro.phaseLabel == "Focus")
        #expect(timer.pomodoro.accessibilityDescription == "Pomodoro ready. Focus: 25 minutes allocated. Break: 5 minutes allocated.")
        now += 600
        timer.update()
        timer.selectMode(.countdown)
        #expect(timer.countdown.remaining == 1_125)
        #expect(timer.countdown.isPaused)
        timer.toggleCountdownRunning()
        now += 5
        timer.update()
        #expect(timer.countdown.remaining == 1_120)
        #expect(sounds == 0)
    }

    @Test
    func countdownCommandsAndRestorationKeepTheirEstablishedRules() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path])
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let configuration = CountdownConfiguration(
            alarmNotificationURL: nil, clockFaceEnabled: false,
            clockHandsEnabled: false, currentTimeoutEnabled: false
        )
        let timer = TimerController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        timer.adjustCountdownDuration(by: 360)
        timer.selectMode(.countdown)
        #expect(timer.countdown.status == .active, "Selecting the current mode must not pause")
        now += 61
        timer.update()
        #expect(timer.countdown.remaining == 299)
        #expect(timer.countdown.wakeupIntervalCount == 1)
        #expect(sounds == 1)
        timer.save()
        now += 9
        let restored = TimerController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        #expect(restored.countdown.status == .active)
        #expect(restored.countdown.remaining == 290)
        restored.selectMode(.pomodoro)
        restored.save()
        #expect(!restored.countdown.isClockFaceEnabled)
        #expect(!restored.countdown.isClockHandsEnabled)
        #expect(!restored.countdown.isCurrentTimeoutEnabled)
        now += 20
        let paused = TimerController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        #expect(paused.countdown.isPaused)
        #expect(paused.countdown.remaining == 290)
        paused.toggleCountdownRunning()
        now += 290
        paused.update()
        paused.update()
        #expect(paused.countdown.status == .empty)
        #expect(paused.countdown.completionCount == 1)
        #expect(sounds == 2)
        paused.selectMode(.pomodoro)
        paused.selectMode(.countdown)
        #expect(paused.countdown.status == .empty)
    }

    @Test
    func autosetAndNextHourStayCountdownSpecific() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 6, hour: 10, minute: 30))!
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, autosetEnabled: true, wakeupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        #expect(timer.countdown.remaining == 1_800)
        now += 1_800
        timer.selectMode(.pomodoro)
        #expect(timer.countdown.isPaused)
        #expect(timer.countdown.remaining == 3_600)
        #expect(timer.countdown.isAutosetEnabled)
        now += 120
        timer.setCountdownToNextHour()
        timer.update()
        #expect(timer.countdown.remaining == 3_600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        #expect(timer.pomodoro.breakDuration == 300)
        timer.selectMode(.countdown)
        timer.setCountdownToNextHour()
        #expect(timer.countdown.remaining == 3_480)
        #expect(timer.countdown.isPaused)
    }
}
