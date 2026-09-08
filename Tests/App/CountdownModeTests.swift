import Foundation
import Testing
@testable import Countdown

@MainActor
struct CountdownModeTests {
    @Test
    func pickerChoicesHaveExactlyTheThreeValidMappings() throws {
        #expect(CountdownMode.allCases == [.pomodoro, .timer, .countdown])
        #expect(CountdownMode.allCases.map(\.label) == ["Pomodoro", "Timer", "Countdown"])
        #expect(CountdownMode.allCases.map(\.usesTimer) == [false, true, true])
        #expect(CountdownMode.allCases.map(\.isClockEnabled) == [true, true, false])
        for mode in CountdownMode.allCases {
            #expect(try JSONDecoder().decode(CountdownMode.self, from: JSONEncoder().encode(mode)) == mode)
        }
    }

    @Test(arguments: CountdownMode.allCases, CountdownMode.allCases)
    func selectionAndRestartKeepOneModeAndSharedPause(outgoing: CountdownMode, incoming: CountdownMode) throws {
        let session = Session()
        defer { session.close() }
        let controller = session.makeController()
        #expect(controller.mode == .timer)
        controller.adjustTimerDuration(by: 1_200)
        controller.selectMode(outgoing)
        session.now += 73
        controller.toggleRunning()
        let remaining = controller.timer.remaining
        let focusEnd = controller.pomodoro.clockSchedule?.focusEnd
        session.now += 47
        controller.selectMode(incoming)
        controller.selectMode(incoming) // Selecting the current entry is a no-op.
        #expect(controller.mode == incoming)
        #expect(controller.timer.isClockEnabled == incoming.isClockEnabled)
        #expect(controller.pomodoro.clockSchedule != nil)
        #expect(controller.timer.remaining == remaining)
        #expect(controller.pomodoro.clockSchedule?.focusEnd == focusEnd)
        #expect(controller.engine.isPaused)
        controller.popups.setPopupEnabled(false)
        controller.save()
        let restored = session.makeController()
        #expect(restored.mode == incoming)
        #expect(restored.timer.isClockEnabled == incoming.isClockEnabled)
        #expect(restored.pomodoro.clockSchedule != nil)
        #expect(restored.timer.remaining == remaining)
        #expect(restored.engine.isPaused)
        #expect(restored.pomodoro.status == .paused)
        let popups = try JSONDecoder().decode([String: Bool].self, from: Data(contentsOf:
            session.store.stateDirectory.appendingPathComponent("features.json")))
        #expect(popups["clock_enabled"] == nil)
        #expect(popups["popup_enabled"] == false)
    }

    @Test(arguments: CountdownMode.allCases, CountdownMode.allCases)
    func selectionSettlesTimeoutUnderOutgoingMode(outgoing: CountdownMode, incoming: CountdownMode) {
        for autoSetToNextHour in [false, true] {
            for alarm in [false, true] {
                let session = Session()
                defer { session.close() }
                let controller = session.makeController(autoSetToNextHour: autoSetToNextHour, alarm: alarm)
                controller.setTimerToNextHour()
                controller.selectMode(outgoing)
                session.now += controller.timer.remaining
                controller.selectMode(incoming)
                controller.update() // Also settles a no-op selection.
                #expect(controller.timer.completionCount == (outgoing.usesTimer ? 1 : 0))
                #expect(session.sounds == (outgoing.usesTimer && alarm ? 1 : 0))
                #expect(controller.timer.remaining == (outgoing.usesTimer && autoSetToNextHour ? 3_600 : 0))
                #expect(!controller.engine.isPaused)
                controller.update()
                #expect(controller.timer.completionCount == (outgoing.usesTimer ? 1 : 0))
            }
        }
    }

    @Test(arguments: [CountdownMode.timer, .countdown], [false, true])
    func timerControlsAndTimeoutEnablementWorkInBothModes(mode: CountdownMode, timeout: Bool) {
        let session = Session()
        defer { session.close() }
        let controller = session.makeController()
        controller.selectMode(mode)
        controller.timer.setRemainingMinutesVisible(timeout)
        controller.adjustTimerDuration(steps: 1)
        #expect(controller.timer.remaining == 300)
        controller.toggleTimerRunning()
        session.now += 73
        controller.adjustTimerDuration(steps: 1)
        #expect(controller.timer.remaining == 600)
        #expect(controller.engine.isPaused)
        controller.setTimerToNextHour()
        #expect(controller.timer.remaining == 3_527)
        #expect(controller.timer.isPaused)
        controller.toggleTimerRunning()
        session.now += controller.timer.remaining
        controller.update()
        #expect(controller.timer.remaining == 0)
        #expect(controller.timer.showsRemainingMinutes == timeout)
        // Current Timeout controls the display, not the alarm.
        #expect(controller.timer.completionCount == 1)
        #expect(session.sounds == 1)
    }

    @Test
    func countdownResumeDoesNotRoundTheRemainingDuration() {
        let session = Session()
        defer { session.close() }
        let controller = session.makeController()
        controller.selectMode(.countdown)
        controller.adjustTimerDuration(by: 713.25)
        session.now += 73.5
        controller.toggleRunning()
        let remaining = controller.timer.remaining
        session.now += 47.25
        controller.toggleRunning()
        #expect(controller.timer.remaining == remaining)
        #expect(controller.timer.endDate == session.now + remaining)
        #expect(!controller.mode.isClockEnabled)
    }

    @MainActor
    private final class Session {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        var sounds = 0
        var store: TimerSessionStore { TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]) }

        func makeController(autoSetToNextHour: Bool = false, alarm: Bool = true) -> CountdownController {
            CountdownController(
                sessionStore: store, configuration: CountdownConfiguration(alarmNotificationURL: nil),
                preferences: CountdownPreferences(autoSetToNextHourEnabled: autoSetToNextHour, popupEnabled: false, alarmEnabled: alarm),
                playSound: { [unowned self] _ in sounds += 1 }, now: { [unowned self] in now }
            )
        }

        func close() { try? FileManager.default.removeItem(at: directory) }
    }
}
