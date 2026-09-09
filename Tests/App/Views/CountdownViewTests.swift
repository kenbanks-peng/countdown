import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownViewTests {
    @Test(arguments: [CountdownMode.timer, .countdown])
    func compactViewDoesNotExpandDuringFinalMinute(mode: CountdownMode) async throws {
        let session = ClockTestSession(clock: mode == .timer)
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(by: 61)
        var presentationChanges = 0
        let hosting = NSHostingView(rootView: CountdownView(
            countdown: controller, isCompact: true,
            changePresentation: { presentationChanges += 1 }
        ))
        _ = try render(hosting, side: 32)

        for remaining in [60.0, 59, 1, 0] {
            session.now += controller.timer.remaining - remaining
            // Let the view's update task advance the timer, not the test.
            for _ in 0..<100 {
                if controller.timer.remaining == remaining { break }
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(controller.timer.remaining == remaining)
            #expect(presentationChanges == 0)
        }
        withExtendedLifetime(hosting) {}
    }

    @Test(arguments: CountdownMode.allCases, [false, true])
    func pauseIconAppearsAndDisappearsInEveryMode(mode: CountdownMode, isCompact: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.adjustTimerDuration(by: 1_800)
        controller.selectMode(mode)
        let side = isCompact ? 32.0 : 188
        let hosting = NSHostingView(rootView: CountdownView(
            countdown: controller, isCompact: isCompact, changePresentation: {}
        ))
        let running = try render(hosting, side: side)
        controller.toggleRunning()
        let paused = try render(hosting, side: side)
        var changedPixels = 0
        // Inspect the center only, away from the labels and session dots.
        for x in Int(Double(paused.pixelsWide) * 0.38)..<Int(Double(paused.pixelsWide) * 0.62) {
            for y in Int(Double(paused.pixelsHigh) * 0.38)..<Int(Double(paused.pixelsHigh) * 0.62) {
                if paused.colorAt(x: x, y: y) != running.colorAt(x: x, y: y) {
                    changedPixels += 1
                }
            }
        }
        #expect(changedPixels > 0)
        controller.toggleRunning()
        let resumed = try render(hosting, side: side)
        #expect(resumed.representation(using: .png, properties: [:]) == running.representation(using: .png, properties: [:]))
    }

    @Test(arguments: [false, true], [false, true])
    func editedClockPresentationAndRestartKeepTheSchedule(paused: Bool, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path])
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        func makeController() -> CountdownController {
            CountdownController(sessionStore: store, configuration: CountdownConfiguration(alarmNotificationURL: nil),
                                preferences: CountdownPreferences(notificationEnabled: false), playSound: { _ in }, now: { now })
        }
        let controller = makeController()
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, steps: -1)
        controller.adjustPomodoroDuration(.rest, steps: 1)
        now += 1_320
        controller.update()
        if paused { controller.toggleRunning() }
        controller.save()
        #expect(controller.pomodoro.phaseLabel == "Rest")
        #expect(controller.pomodoro.focusRemaining == 0)
        #expect(controller.pomodoro.restRemaining == 480)
        let side = isCompact ? 32.0 : 188
        func image(_ value: CountdownController) throws -> Data? {
            try render(NSHostingView(rootView: CountdownView(countdown: value, isCompact: isCompact, changePresentation: {})), side: side)
                .representation(using: .png, properties: [:])
        }
        let before = try image(controller)
        _ = try render(NSHostingView(rootView: CountdownView(countdown: controller, isCompact: !isCompact, changePresentation: {})))
        #expect(try image(controller) == before)
        let restored = makeController()
        #expect(try image(restored) == before)
        #expect(restored.pomodoro.accessibilityDescription == controller.pomodoro.accessibilityDescription)
        #expect(restored.engine.isPaused == paused)
        now += 60
        restored.update()
        #expect(restored.pomodoro.restRemaining == (paused ? 480 : 420))
    }

    @Test
    func returningToCountdownRestoresItsRenderedPausedDisplay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { _ in }, now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        controller.selectMode(.countdown)
        controller.adjustTimerDuration(by: 1_200)
        controller.toggleRunning()
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, changePresentation: {}))
        let before = try render(hosting)
        controller.selectMode(.pomodoro)
        let adapter = ScrollTimeAdjuster(countdown: controller)
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: 30, wheel2: 0, wheel3: 0
        ))
        event.location = CGPoint(x: 120, y: 50)
        adapter.handle(try #require(NSEvent(cgEvent: event)))
        let preview = try render(hosting)
        #expect(preview.representation(using: .png, properties: [:]) != before.representation(using: .png, properties: [:]))
        controller.selectMode(.countdown)
        let after = try render(hosting)
        #expect(before.representation(using: .png, properties: [:]) == after.representation(using: .png, properties: [:]))
        #expect(controller.timer.isPaused)
        #expect(controller.timer.remaining == 1_200)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: #require(after.cgImage)).perform([request])
        #expect(request.results?.contains { $0.topCandidates(1).first?.string == "20" } == true)
    }

    @Test(arguments: [false, true])
    func sectorScrollUsesTheRenderedCircleInBothPresentations(isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(notificationEnabled: false), playSound: { _ in },
            now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        controller.selectMode(.pomodoro)
        let side = isCompact ? 32.0 : 188
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: isCompact, changePresentation: {}))
        _ = try render(hosting, side: side)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        let adapter = ScrollTimeAdjuster(countdown: controller, window: window, isCompact: { isCompact }, uptime: { 0 })
        let radius = isCompact ? 14.0 : 80
        let blue = NSPoint(x: side / 2 + radius * sin(11 * .pi / 12), y: side / 2 + radius * cos(11 * .pi / 12))
        let green = NSPoint(x: side / 2 + radius, y: side / 2)
        adapter.handle(try scrollEvent(in: window, at: blue, delta: 12))
        #expect(controller.pomodoro.restDuration == 600)
        #expect(controller.pomodoro.focusDuration == 1_500)
        adapter.handle(try scrollEvent(in: window, at: green, delta: 36, option: true, precise: true))
        #expect(controller.pomodoro.focusDuration == 1_560)
        adapter.handle(try scrollEvent(in: window, at: green, delta: 5, option: true, precise: true))
        #expect(controller.pomodoro.focusDuration == 1_560)
        let edited = try render(hosting, side: side)
        #expect(try sample(edited, angle: 180).blueComponent > 0.8)
        #expect(try sample(edited, angle: 72).greenComponent > 0.6)
        #expect(try sample(edited, angle: 144).greenComponent > 0.6)
        #expect(try sample(edited, angle: 252).greenComponent < 0.2)
        // OCR can read the four rings as punctuation; there must be no phase label.
        #expect(try recognizedText(edited).allSatisfy { $0 != "Focus" && $0 != "Rest" })
        #expect(controller.timer.remaining == 2_160)
    }

    @Test
    func modeAwareCompactKeepsCountdownRenderingAndPausedReturn() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(), playSound: { _ in },
            now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        controller.selectMode(.countdown)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: true, changePresentation: {}))
        let original = NSHostingView(rootView: TimerView(model: controller.timer, isCompact: true))
        func expectUnchangedBitmap() throws {
            let actual = try render(hosting, side: 32)
            let expected = try render(original, side: 32)
            #expect(actual.representation(using: .png, properties: [:]) == expected.representation(using: .png, properties: [:]))
        }
        try expectUnchangedBitmap() // Empty Countdown.
        controller.adjustTimerDuration(by: 1_200)
        try expectUnchangedBitmap() // Active Countdown.
        controller.toggleRunning()
        try expectUnchangedBitmap() // Paused Countdown.
        controller.selectMode(.pomodoro)
        let pomodoro = try render(hosting, side: 32)
        #expect(controller.mode.isClockEnabled)
        #expect(try recognizedText(pomodoro).isEmpty)
        controller.selectMode(.countdown)
        #expect(controller.timer.isPaused)
        #expect(controller.timer.remaining == 1_200)
        try expectUnchangedBitmap()
    }

    @Test(arguments: CountdownMode.allCases)
    func compactDirectionFollowsTimerMode(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 20))!
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        controller.adjustTimerDuration(by: 1_800)
        controller.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: true, changePresentation: {}))
        let initial = try render(hosting, side: 32)
        if mode.isClockEnabled {
            #expect(try sample(initial, angle: 240).greenComponent > 0.6)
            #expect(try sample(initial, angle: 15).greenComponent < 0.2)
        } else {
            #expect(try sample(initial, angle: 90).greenComponent > 0.6)
            #expect(try sample(initial, angle: 240).greenComponent < 0.2)
        }
        if mode == .pomodoro { #expect(try sample(initial, angle: 282).blueComponent > 0.8) }
        for other in CountdownMode.allCases { controller.selectMode(other) }
        controller.selectMode(mode)
        #expect(try render(hosting, side: 32).representation(using: .png, properties: [:]) == initial.representation(using: .png, properties: [:]))
    }

    @Test(arguments: CountdownMode.allCases)
    func modeSelectionChangesDisplayAndReturnsToTheSameImage(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(),
            playSound: { _ in }, now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }, saveEnablement: { _, _ in }
        )
        controller.adjustTimerDuration(by: 1_800)
        controller.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, changePresentation: {}))
        func image() throws -> Data? {
            try render(hosting).representation(using: .png, properties: [:])
        }
        let initial = try image()
        for other in CountdownMode.allCases where other != mode {
            controller.selectMode(other)
            #expect(try image() != initial)
        }
        controller.selectMode(mode)
        #expect(try image() == initial)
    }
}
