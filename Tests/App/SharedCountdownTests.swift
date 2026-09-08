import Foundation
import Testing
@testable import Countdown

@MainActor
struct SharedCountdownTests {
    @Test(arguments: CountdownMode.allCases)
    func pauseWithAnEmptyTimerAppliesToNewDurationsAndSurvivesRestart(mode: CountdownMode) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        let store = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        let configuration = CountdownConfiguration(alarmNotificationURL: nil)
        let featureState = CountdownFeatureState(popupEnabled: false)
        let controller = CountdownController(stateStore: store, configuration: configuration, featureState: featureState, playSound: { _ in }, now: { now })
        controller.selectMode(mode)
        #expect(controller.canToggleRunning)
        #expect(controller.controlLabel == "Pause")
        controller.toggleRunning()
        now += 300
        controller.selectMode(.timer)
        controller.adjustTimerDuration(by: 600)
        #expect(controller.timer.isPaused)
        #expect(controller.pomodoro.status == .paused)
        controller.selectMode(.pomodoro)
        controller.save()
        now += 300
        let restored = CountdownController(stateStore: store, configuration: configuration, featureState: featureState, playSound: { _ in }, now: { now })
        #expect(restored.controlLabel == "Resume")
        #expect(restored.timer.remaining == 600)
        #expect(restored.pomodoro.status == .paused)
        restored.toggleRunning()
        now += 60
        restored.update()
        #expect(restored.timer.remaining == 540)
        #expect(restored.pomodoro.focusRemaining == 1_440)
        restored.selectMode(.timer)
        #expect(restored.controlLabel == "Pause")
    }

    @Test
    func switchingModesDoesNotPauseAndPomodoroStartsAutomatically() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_699_999_800)
        let controller = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.adjustTimerDuration(by: 1_200)
        now += 75
        controller.selectMode(.pomodoro)
        #expect(controller.pomodoro.status == .running)
        now += 600
        controller.update()
        controller.selectMode(.timer)
        #expect(!controller.timer.isPaused)
        #expect(controller.timer.remaining == 525)
    }
}
