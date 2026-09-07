import Foundation
import Testing
@testable import Countdown

@MainActor
struct TimerCoreTests {
    @Test(arguments: TimerMode.allCases)
    func sharedControlsAndWakeupFollowTheActiveMode(mode: TimerMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        var settings: [String: Bool] = [:]
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 5),
            playSound: { _ in sounds += 1 }, now: { now },
            saveEnablement: { settings[$0] = $1 }
        )
        timer.selectMode(mode)
        if mode == .countdown { timer.adjustCountdownDuration(by: 1_800) }
        else { timer.toggleRunning() }
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
        timer.selectMode(mode == .countdown ? .pomodoro : .countdown)
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

    @Test(arguments: TimerMode.allCases)
    func durationEditsDoNotCauseWakeupAndCompletionDoesNotRepeatIt(mode: TimerMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, wakeupTime: 2),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        timer.selectMode(mode)
        if mode == .countdown {
            timer.adjustCountdownDuration(by: 1_800)
            timer.adjustCountdownDuration(by: -600)
        } else {
            timer.toggleRunning()
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
