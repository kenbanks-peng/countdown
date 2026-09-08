import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownPopupViewTests {
    @Test(arguments: [0.0, 1_500, 1_800, 6_900])
    func popupShowsOnlyWholeMinutes(elapsed: TimeInterval) throws {
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
        try expectPopupMinutes(bitmap, remaining: elapsed == 1_500 ? 300 : elapsed == 6_900 ? 900 : 1_500)
        #expect(!text.contains(":"))
        #expect(!text.contains("Session"))
        #expect(!text.contains(controller.pomodoro.phaseLabel))
        #expect(controller.mode.isClockEnabled)

        // Outside the disc, preserve sectors and original hands, without clock marks or dots.
        let normal = try render(NSHostingView(rootView: ZStack {
            PomodoroView(model: controller.pomodoro, clockDate: now, showsSessionDots: false)
            ClockHands(date: now)
                .foregroundStyle(.white.opacity(0.42))
                .padding(CountdownAppearance.circleInset)
        }))
        for angle in stride(from: 0.0, to: 360.0, by: 5) {
            let actual = try sample(bitmap, angle: angle, radius: 0.42)
            let expected = try sample(normal, angle: angle, radius: 0.42)
            #expect(abs(actual.redComponent - expected.redComponent) < 0.03)
            #expect(abs(actual.greenComponent - expected.greenComponent) < 0.03)
            #expect(abs(actual.blueComponent - expected.blueComponent) < 0.03)
        }
    }

    @Test(arguments: [false, true])
    func timerPopupShowsWholeMinutesEvenWithLabelsDisabled(clockEnabled: Bool) throws {
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
        #expect(try recognizedText(render(hosting)) == ["10"])
        now += 78
        controller.update()
        let text = try recognizedText(render(hosting)).joined(separator: " ")
        #expect(!text.contains(":"))
        #expect(!text.contains(controller.mode.label))
        try expectPopupMinutes(render(hosting), remaining: 540)
        controller.toggleRunning()
        try expectPopupMinutes(render(hosting), remaining: 540)
        #expect(try !recognizedText(render(hosting)).contains("Paused"))
    }

    // Vision can omit isolated single digits. Compare the rendered center instead.
    private func expectPopupMinutes(_ bitmap: NSBitmapImageRep, remaining: TimeInterval) throws {
        let expected = try render(NSHostingView(rootView: CountdownPopupOverlay(remaining: remaining)))
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let dx = Double(x) / Double(bitmap.pixelsWide) - 0.5
                let dy = Double(y) / Double(bitmap.pixelsHigh) - 0.5
                guard dx * dx + dy * dy < 0.17 * 0.17 else { continue }
                let actualColor = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                let expectedColor = try #require(expected.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                #expect(abs(actualColor.redComponent - expectedColor.redComponent) < 0.03)
                #expect(abs(actualColor.greenComponent - expectedColor.greenComponent) < 0.03)
                #expect(abs(actualColor.blueComponent - expectedColor.blueComponent) < 0.03)
            }
        }
    }

    @Test
    func popupTimeRoundsUpWithoutShowingZeroEarly() {
        #expect(CountdownPopupOverlay.timeLabel(0) == "0")
        #expect(CountdownPopupOverlay.timeLabel(-1) == "0")
        #expect(CountdownPopupOverlay.timeLabel(0.1) == "1")
        #expect(CountdownPopupOverlay.timeLabel(59.1) == "1")
        #expect(CountdownPopupOverlay.timeLabel(60) == "1")
        #expect(CountdownPopupOverlay.timeLabel(60.1) == "2")
        #expect(CountdownPopupOverlay.timeLabel(3_600) == "60")
    }
}
