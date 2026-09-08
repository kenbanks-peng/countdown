import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownReminderViewTests {
    @Test(arguments: [0.0, 1_500, 1_800, 6_900])
    func pomodoroReminderShowsMinutesForCurrentPhase(elapsed: TimeInterval) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // Start on a clock mark so both displays have the same phase times.
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(reminderEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(.pomodoro)
        now += elapsed
        controller.update()
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isReminder: true, changePresentation: {}))
        let bitmap = try render(hosting, side: 512)
        let text = try recognizedText(bitmap).joined(separator: " ")
        let model = controller.pomodoro
        try expectReminderMinutes(bitmap, remaining: model.focusRemaining > 0 ? model.focusRemaining : model.restRemaining)
        #expect(!text.contains(":"))
        #expect(!text.contains("Session"))
        #expect(!text.contains(controller.pomodoro.phaseLabel))
        #expect(controller.mode.isClockEnabled)

        // No circle, sectors, clock marks, or hands surround the number.
        for angle in stride(from: 0.0, to: 360.0, by: 5) {
            #expect(try sample(bitmap, angle: angle, radius: 0.42).alphaComponent < 0.03)
        }
    }

    @Test(arguments: [false, true])
    func timerReminderShowsWholeMinutesEvenWithLabelsDisabled(clockEnabled: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(showsRemainingMinutes: false, reminderEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(clockEnabled ? .timer : .countdown)
        controller.adjustTimerDuration(by: 600)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isReminder: true, changePresentation: {}))
        #expect(try recognizedText(render(hosting, side: 512)) == ["10"])
        now += 78
        controller.update()
        let text = try recognizedText(render(hosting, side: 512)).joined(separator: " ")
        #expect(!text.contains(":"))
        #expect(!text.contains(controller.mode.label))
        try expectReminderMinutes(render(hosting, side: 512), remaining: 540)
        controller.toggleRunning()
        try expectReminderMinutes(render(hosting, side: 512), remaining: 540)
        #expect(try !recognizedText(render(hosting, side: 512)).contains("Paused"))
    }

    @Test(arguments: [72.0, 144, 200], [0.5, 2.0])
    func configuredFontSizeDoesNotFollowWindowScale(fontSize: Double, scale: Double) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            playSound: { _ in }
        )
        controller.selectMode(.countdown)
        controller.adjustTimerDuration(by: 600)
        let hosting = NSHostingView(rootView: CountdownView(
            countdown: controller, isReminder: true, scale: scale,
            reminderFontSizePt: fontSize, changePresentation: {}
        ))
        try expectReminderMinutes(render(hosting, side: 512), remaining: 600, fontSize: fontSize)
    }

    // Vision can omit isolated single digits. Compare the complete rendered image instead.
    private func expectReminderMinutes(_ bitmap: NSBitmapImageRep, remaining: TimeInterval,
                                       fontSize: Double = 144) throws {
        let expected = try render(NSHostingView(rootView: CountdownReminderOverlay(remaining: remaining, fontSizePt: fontSize)), side: 512)
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let actualColor = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let expectedColor = try #require(expected.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                #expect(abs(actualColor.alphaComponent - expectedColor.alphaComponent) < 0.03)
                guard expectedColor.alphaComponent > 0.03 else { continue }
                #expect(abs(actualColor.redComponent - expectedColor.redComponent) < 0.03)
                #expect(abs(actualColor.greenComponent - expectedColor.greenComponent) < 0.03)
                #expect(abs(actualColor.blueComponent - expectedColor.blueComponent) < 0.03)
            }
        }
    }

    @Test
    func reminderTimeRoundsUpWithoutShowingZeroEarly() {
        #expect(CountdownReminderOverlay.timeLabel(0) == "0")
        #expect(CountdownReminderOverlay.timeLabel(-1) == "0")
        #expect(CountdownReminderOverlay.timeLabel(0.1) == "1")
        #expect(CountdownReminderOverlay.timeLabel(59.1) == "1")
        #expect(CountdownReminderOverlay.timeLabel(60) == "1")
        #expect(CountdownReminderOverlay.timeLabel(60.1) == "2")
        #expect(CountdownReminderOverlay.timeLabel(3_600) == "60")
    }
}
