import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownCoreTests {
    @Test(arguments: CountdownMode.allCases)
    func sharedControlsAndWakeupFollowTheActiveMode(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        var settings: [String: Bool] = [:]
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 5),
            playSound: { _ in sounds += 1 }, now: { now },
            saveEnablement: { settings[$0] = $1 }
        )
        timer.selectMode(mode)
        if mode == .timer { timer.adjustTimerDuration(by: 1_800) }
        #expect(timer.controlLabel == "Pause")
        now += 300
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 1)
        #expect(sounds == 1)
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 1)

        timer.toggleRunning()
        #expect(timer.controlLabel == "Resume")
        now += 900
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 1)
        timer.toggleRunning()
        now += 300
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 2)

        timer.features.setWakeupEnabled(false)
        now += 300
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 2)
        timer.features.setClockFaceEnabled(false)
        timer.features.setClockHandsEnabled(false)
        let features = timer.features
        timer.selectMode(mode == .timer ? .pomodoro : .timer)
        #expect(timer.features === features)
        #expect(!timer.features.isClockFaceEnabled)
        #expect(!timer.features.isClockHandsEnabled)
        #expect(!timer.features.isWakeupEnabled)
        now += 600
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 2)
        #expect(sounds == 2)
        #expect(settings == ["clock_face_enabled": false, "clock_hands_enabled": false, "wakeup_enabled": false])
    }

    @Test
    func restoringTimerDoesNotReplayWakeupsFromTimeWhileClosed() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        store.save(.init(status: .active, duration: 1_800, remaining: 1_800,
                         endDate: now.addingTimeInterval(1_800), savedAt: now))
        now += 360
        var sounds = 0
        let controller = CountdownController(
            stateStore: store,
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 5),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        #expect(controller.timer.remaining == 1_440)
        #expect(sounds == 0)
        now += 300
        controller.update()
        #expect(sounds == 1)
    }

    @Test(arguments: CountdownMode.allCases)
    func durationIncreaseDoesNotRepeatWakeupAfterOnlyOneMinute(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let controller = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 5),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.selectMode(mode)
        if mode == .timer { controller.adjustTimerDuration(by: 1_800) }
        now += 300
        controller.update()
        #expect(sounds == 1)
        if mode == .timer { controller.adjustTimerDuration(by: 60) }
        else { controller.adjustPomodoroDuration(.focus, by: 60) }
        now += 60
        controller.update()
        #expect(sounds == 1)
        now += 240
        controller.update()
        #expect(sounds == 2)
    }

    @Test
    func hiddenModeIsSilentAndSwitchingDoesNotCauseAnEarlyWakeup() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let controller = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 5),
            playSound: { _ in sounds += 1 }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.adjustTimerDuration(by: 610)
        controller.selectMode(.pomodoro)
        now += 10 // Hidden Timer crosses 600 seconds.
        controller.update()
        #expect(sounds == 0)
        now += 290 // Visible Pomodoro has run for five minutes.
        controller.update()
        controller.update() // A second view can also request an update.
        #expect(sounds == 1)
        controller.selectMode(.timer)
        now += 10 // Timer crosses 300 seconds, only ten seconds after the last sound.
        controller.update()
        #expect(sounds == 1)
    }

    @Test(arguments: CountdownMode.allCases)
    func durationEditsDoNotCauseWakeupAndCompletionDoesNotRepeatIt(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 2),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        timer.selectMode(mode)
        if mode == .timer {
            timer.adjustTimerDuration(by: 1_800)
            timer.adjustTimerDuration(by: -600)
        } else {
            timer.adjustPomodoroDuration(.focus, by: -600)
        }
        #expect(timer.features.wakeupIntervalCount == 0)
        now += 119
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 0)
        now += 1
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 1)
        now += 361 // A delayed update reports one Wakeup, not a burst.
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 2)
        now += 10_000
        timer.update()
        timer.update()
        #expect(timer.features.wakeupIntervalCount == 2)
    }
}
