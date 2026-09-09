import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownNotificationViewTests {
    @Test(arguments: [0.0, 1_500, 1_560, 1_800, 6_900, 7_200, 8_100])
    func pomodoroNotificationShowsFocusMinutesOrRest(elapsed: TimeInterval) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // Start on a clock mark so both displays have the same phase times.
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(.pomodoro)
        now += elapsed
        controller.update()
        let variations = NotificationFontVariations(weight: 800, width: 85, opticalSize: 48)
        let hosting = NSHostingView(rootView: CountdownView(
            countdown: controller, isNotification: true, notificationFontVariations: variations, changePresentation: {}
        ))
        let bitmap = try render(hosting, side: 512)
        let text = try recognizedText(bitmap).joined(separator: " ")
        let model = controller.pomodoro
        if model.focusRemaining > 0 {
            try expectNotificationMinutes(bitmap, remaining: model.focusRemaining, fontVariations: variations)
        } else {
            #expect(text == "REST")
            try expectNotificationMinutes(bitmap, remaining: 0, fontVariations: variations, isRest: true)
        }
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
    func timerNotificationShowsWholeMinutesEvenWithLabelsDisabled(clockEnabled: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(showsRemainingMinutes: false, notificationEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(clockEnabled ? .timer : .countdown)
        controller.adjustTimerDuration(by: 600)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isNotification: true, changePresentation: {}))
        #expect(try recognizedText(render(hosting, side: 512)) == ["10"])
        now += 78
        controller.update()
        let text = try recognizedText(render(hosting, side: 512)).joined(separator: " ")
        #expect(!text.contains(":"))
        #expect(!text.contains(controller.mode.label))
        try expectNotificationMinutes(render(hosting, side: 512), remaining: 540)
        controller.toggleRunning()
        try expectNotificationMinutes(render(hosting, side: 512), remaining: 540)
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
            countdown: controller, isNotification: true, scale: scale,
            notificationFontSizePt: fontSize, changePresentation: {}
        ))
        try expectNotificationMinutes(render(hosting, side: 512), remaining: 600, fontSize: fontSize)
    }

    @Test(arguments: [CountdownMode.countdown, .pomodoro], ["Impact", ""])
    func configuredFontReachesNotification(mode: CountdownMode, fontName: String) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            playSound: { _ in }
        )
        controller.selectMode(mode)
        if mode.usesTimer { controller.adjustTimerDuration(by: 600) }
        let variations = NotificationFontVariations(weight: 800, width: 85, opticalSize: 48)
        let hosting = NSHostingView(rootView: CountdownView(
            countdown: controller, isNotification: true, notificationFont: fontName,
            notificationFontVariations: variations, changePresentation: {}
        ))
        let remaining = mode.usesTimer ? controller.timer.remaining : controller.pomodoro.focusRemaining
        try expectNotificationMinutes(render(hosting, side: 512), remaining: remaining,
                                      fontName: fontName, fontVariations: variations)
    }

    // Vision can omit isolated single digits. Compare the complete rendered image instead.
    private func expectNotificationMinutes(_ bitmap: NSBitmapImageRep, remaining: TimeInterval,
                                       fontSize: Double = 144, fontName: String = "",
                                       fontVariations: NotificationFontVariations = NotificationFontVariations(),
                                       isRest: Bool = false) throws {
        let expected = try render(NSHostingView(rootView: CountdownNotificationOverlay(
            remaining: remaining, isRest: isRest, fontSizePt: fontSize,
            fontName: fontName, fontVariations: fontVariations
        )), side: 512)
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

    @Test(arguments: [
        NotificationFontVariations(weight: 900),
        NotificationFontVariations(width: 60),
        NotificationFontVariations(opticalSize: 17),
    ])
    func eachAxisChangesRenderedText(variations: NotificationFontVariations) throws {
        let normal = try render(NSHostingView(rootView: CountdownNotificationOverlay(remaining: 600)), side: 512)
        let varied = try render(NSHostingView(rootView: CountdownNotificationOverlay(
            remaining: 600, fontVariations: variations
        )), side: 512)
        #expect(normal.tiffRepresentation != varied.tiffRepresentation)
    }

    @Test
    func notificationTimeRoundsUpWithoutShowingZeroEarly() {
        #expect(CountdownNotificationOverlay.timeLabel(0) == "0")
        #expect(CountdownNotificationOverlay.timeLabel(-1) == "0")
        #expect(CountdownNotificationOverlay.timeLabel(0.1) == "1")
        #expect(CountdownNotificationOverlay.timeLabel(59.1) == "1")
        #expect(CountdownNotificationOverlay.timeLabel(60) == "1")
        #expect(CountdownNotificationOverlay.timeLabel(60.1) == "2")
        #expect(CountdownNotificationOverlay.timeLabel(3_600) == "60")
    }
}
