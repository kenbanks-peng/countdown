import Foundation
import Testing
@testable import Countdown

@MainActor
struct AutoRepeatTests {
    @Test(arguments: [CountdownMode.timer, .countdown])
    func repeatsLastEditNotElapsedOrPausedTime(mode: CountdownMode) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(mode)
        controller.setAutoRepeatEnabled(true)
        #expect(controller.timer.remaining == 0)
        controller.adjustTimerDuration(by: 713.25)
        session.now += 100
        controller.adjustTimerDuration(by: 60)
        let selected = controller.timer.remaining
        #expect(selected == 673.25)
        session.now += 50
        controller.toggleRunning()
        session.now += 200
        controller.toggleRunning()
        controller.save()
        let restored = session.makeController()
        restored.setAutoRepeatEnabled(true)
        session.now = try #require(restored.timer.endDate)
        restored.update()
        #expect(restored.timer.remaining == selected)
        #expect(restored.timer.endDate == session.now + selected)
        #expect(restored.timer.completionCount == 1)
        session.now += selected
        restored.update()
        #expect(restored.timer.remaining == selected)
        #expect(restored.timer.completionCount == 2)
    }

    @Test(arguments: CountdownMode.allCases, [CountdownMode.timer, .countdown])
    func repeatsValuesInheritedOnEntry(outgoing: CountdownMode, incoming: CountdownMode) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(outgoing)
        if outgoing.usesTimer { controller.adjustTimerDuration(by: 1_200) }
        session.now += 123.25
        controller.update()
        controller.selectMode(incoming)
        let inherited = controller.timer.remaining
        controller.setAutoRepeatEnabled(true)
        session.now = try #require(controller.timer.endDate)
        controller.update()
        #expect(controller.timer.remaining == (outgoing == incoming ? 1_200 : inherited))
    }

    @Test(arguments: 0..<4, [1, 4, 12])
    func pomodoroStopsOrRepeatsAfterFinalRest(variant: Int, stages: Int) throws {
        let enabled = variant & 1 != 0
        let late = variant & 2 != 0
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, pomodoroFocusPeriodsPerCycle: stages),
            preferences: CountdownPreferences(autoRepeatEnabled: enabled, notificationEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(.pomodoro)
        let cycle = controller.pomodoro.cycleDuration
        now += cycle * (late ? 10_000 : 1)
        controller.update()
        #expect(controller.pomodoro.stage == (enabled ? 1 : stages))
        #expect(controller.pomodoro.focusRemaining == (enabled ? 1_500 : 0))
        #expect(controller.pomodoro.restRemaining == (enabled ? (stages == 1 ? 1_200 : 300) : 0))
        #expect(controller.engine.isPaused == !enabled)
        #expect(controller.timer.completionCount == 0)
        controller.update()
        #expect(controller.engine.isPaused == !enabled)
        if !enabled {
            controller.toggleRunning()
            #expect(controller.pomodoro.stage == 1)
            #expect(controller.pomodoro.focusRemaining == 1_500)
            #expect(!controller.engine.isPaused)
        }
    }

    @Test
    func pomodoroCompletionDoesNotAnnounceAnotherRest() {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.notifications.setNotificationEnabled(true)
        controller.setAutoRepeatEnabled(true)
        session.now += 100
        controller.setAutoRepeatEnabled(false)
        let remainingCycle = controller.pomodoro.cycleDuration - 100
        let notifications = controller.notifications.notificationIntervalCount
        session.now += remainingCycle
        controller.update()
        #expect(controller.engine.isPaused)
        #expect(controller.notifications.notificationIntervalCount == notifications)
        controller.save()
        let restored = session.makeController()
        #expect(restored.engine.isPaused)
        #expect(restored.pomodoro.focusRemaining + restored.pomodoro.restRemaining == 0)
    }

    @Test(arguments: [CountdownMode.timer, .countdown])
    func disablingRepeatLeavesCurrentRunUnchanged(mode: CountdownMode) {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(mode)
        controller.adjustTimerDuration(by: 600)
        controller.setAutoRepeatEnabled(true)
        session.now += 100
        controller.setAutoRepeatEnabled(false)
        #expect(controller.timer.remaining == 500)
        session.now += 500
        controller.update()
        #expect(controller.timer.remaining == 0)
        #expect(controller.timer.completionCount == 1)
    }
}
