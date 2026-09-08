import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownPopupViewTests {
    @Test(arguments: [0.0, 1_500, 1_800, 6_900])
    func popupShowsCurrentPhaseTimeAndSession(elapsed: TimeInterval) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // Start on a clock mark so both displays have the same phase times.
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(popupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(.pomodoro)
        now += elapsed
        controller.update()
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isPopup: true, changePresentation: {}))
        let bitmap = try render(hosting)
        let text = try recognizedText(bitmap).joined(separator: " ")
        #expect(text.contains(controller.pomodoro.phaseLabel))
        #expect(text.contains(elapsed == 1_500 ? "5:00" : elapsed == 6_900 ? "15:00" : "25:00"))
        #expect(text.contains("Session \(controller.pomodoro.stage) of 4"))
        #expect(!text.contains("Next"))
        #expect(controller.mode.isClockEnabled)

        // The popup does not change sector geometry outside its label.
        let normal = try render(NSHostingView(rootView: PomodoroView(
            model: controller.pomodoro, clockDate: now
        )))
        for angle in [15.0, 90, 270, 345] {
            let actual = try sample(bitmap, angle: angle, radius: 0.42)
            let expected = try sample(normal, angle: angle, radius: 0.42)
            #expect(abs(actual.redComponent - expected.redComponent) < 0.03)
            #expect(abs(actual.greenComponent - expected.greenComponent) < 0.03)
            #expect(abs(actual.blueComponent - expected.blueComponent) < 0.03)
        }
    }

    @Test(arguments: [false, true])
    func timerPopupShowsExactTimeEvenWithTimeoutDisabled(clockEnabled: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(showsRemainingMinutes: false, popupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(clockEnabled ? .timer : .countdown)
        controller.adjustTimerDuration(by: 600)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isPopup: true, changePresentation: {}))
        #expect(try recognizedText(render(hosting)).contains("10:00"))
        now += 78
        controller.update()
        let text = try recognizedText(render(hosting)).joined(separator: " ")
        #expect(text.contains(controller.mode.label))
        #expect(text.contains("8:42"))
        #expect(!text.contains("Session"))
        controller.toggleRunning()
        #expect(try recognizedText(render(hosting)).contains("Paused"))
    }

    @Test
    func popupTimeRoundsUpWithoutShowingZeroEarly() {
        #expect(CountdownPopupOverlay.timeLabel(0) == "0:00")
        #expect(CountdownPopupOverlay.timeLabel(-1) == "0:00")
        #expect(CountdownPopupOverlay.timeLabel(0.1) == "0:01")
        #expect(CountdownPopupOverlay.timeLabel(59.1) == "1:00")
        #expect(CountdownPopupOverlay.timeLabel(60.1) == "1:01")
        #expect(CountdownPopupOverlay.timeLabel(3_600) == "60:00")
    }
}
