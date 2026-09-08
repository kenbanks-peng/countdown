import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownViewTests {
    @Test(arguments: [0.0, 600, 1_500, 1_620, 1_800, 6_900], [false, true])
    func pomodoroClockRendersCurrentSectorsAcrossPhases(elapsed: TimeInterval, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let controller = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false), playSound: { _ in }, now: { now }
        )
        controller.selectMode(.pomodoro)
        now += elapsed
        controller.update()
        let side = isCompact ? 32.0 : 188
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: isCompact, changePresentation: {}))
        let bitmap = try render(hosting, side: side)
        let model = controller.pomodoro
        let schedule = try #require(model.clockSchedule)
        func angle(at date: Date) -> Double {
            date.timeIntervalSince(Calendar.current.startOfDay(for: date))
                .truncatingRemainder(dividingBy: 3_600) / 10
        }
        if model.focusRemaining > 0 {
            let middle = now + model.focusRemaining / 2
            #expect(try sample(bitmap, angle: angle(at: middle), radius: 0.32).greenComponent > 0.6)
        }
        let restEnd = schedule.end(for: model.restPhase)
        let restMiddle = restEnd - model.restRemaining / 2
        #expect(try sample(bitmap, angle: angle(at: restMiddle), radius: 0.32).blueComponent > 0.8)
        let text = try recognizedText(bitmap)
        #expect(!text.contains("Focus") && !text.contains("Rest"))
        #expect(controller.mode.isClockEnabled)
        #expect(controller.pomodoro.stage == (elapsed < 1_800 ? 1 : elapsed < 6_900 ? 2 : 4))
    }

    @Test(arguments: [false, true], [false, true])
    func editedClockPresentationAndRestartKeepTheSchedule(paused: Bool, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        func makeController() -> CountdownController {
            CountdownController(stateStore: store, configuration: CountdownConfiguration(alarmNotificationURL: nil),
                                featureState: CountdownFeatureState(popupEnabled: false), playSound: { _ in }, now: { now })
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
        #expect(restored.countdown.isPaused == paused)
        now += 60
        restored.update()
        #expect(restored.pomodoro.restRemaining == (paused ? 480 : 420))
    }

    @Test(arguments: CountdownMode.allCases, [false, true])
    func hostedPressChangesPresentationWithoutChangingTimerState(mode: CountdownMode, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        var expansions = 0
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        timer.selectMode(.countdown)
        timer.adjustTimerDuration(by: 1_800)
        timer.toggleRunning()
        timer.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: isCompact, changePresentation: { expansions += 1 }))
        _ = try render(hosting)
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousEnhancedUI = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previousEnhancedUI, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        #expect(accessibilityLabels(hosting).contains(mode == .pomodoro ? timer.pomodoro.accessibilityDescription : "30 minutes remaining"))
        #expect(pressTimer(hosting, labelPrefix: mode == .pomodoro ? "Pomodoro " : "30 minutes remaining"))
        #expect(expansions == 1)
        #expect(timer.controlLabel == "Resume")
        timer.toggleRunning()
        #expect(timer.controlLabel == "Pause")
        now += 60
        timer.update()
        _ = try render(hosting)
        #expect(pressTimer(hosting, labelPrefix: mode == .pomodoro ? "Pomodoro " : "29 minutes remaining"))
        #expect(expansions == 2)
        #expect(timer.controlLabel == "Pause")
        timer.toggleRunning()
        #expect(timer.controlLabel == "Resume")
        now += 1_200
        timer.update()
        _ = try render(hosting)
        #expect(pressTimer(hosting, labelPrefix: mode == .pomodoro ? "Pomodoro " : "29 minutes remaining"))
        #expect(expansions == 3)
        #expect(timer.controlLabel == "Resume")
        timer.toggleRunning()
        #expect(timer.controlLabel == "Pause")
    }

    @Test
    func returningToCountdownRestoresItsRenderedPausedDisplay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { _ in }, now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        timer.selectMode(.countdown)
        timer.adjustTimerDuration(by: 1_200)
        timer.toggleRunning()
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: {}))
        let before = try render(hosting)
        timer.selectMode(.pomodoro)
        let adapter = ScrollTimeAdjuster(countdown: timer)
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: 30, wheel2: 0, wheel3: 0
        ))
        event.location = CGPoint(x: 120, y: 50)
        adapter.handle(try #require(NSEvent(cgEvent: event)))
        let preview = try render(hosting)
        #expect(preview.representation(using: .png, properties: [:]) != before.representation(using: .png, properties: [:]))
        timer.selectMode(.countdown)
        let after = try render(hosting)
        #expect(before.representation(using: .png, properties: [:]) == after.representation(using: .png, properties: [:]))
        #expect(timer.timer.isPaused)
        #expect(timer.timer.remaining == 1_200)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: #require(after.cgImage)).perform([request])
        #expect(request.results?.contains { $0.topCandidates(1).first?.string == "20" } == true)
    }

    @Test(arguments: [32.0, 71, 123, 188], [false, true])
    func pomodoroStaysCircularAtBothPresentationsAndSquareTransitionSizes(side: Double, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { _ in }, now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        timer.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: isCompact, changePresentation: {}))
        let bitmap = try render(hosting, side: side)
        let radius = (side / 2 - (isCompact ? 0 : 6) - 4) / side
        #expect(try sample(bitmap, angle: 165, radius: radius).blueComponent > 0.8)
        #expect(try sample(bitmap, angle: 90, radius: radius).greenComponent > 0.6)
        #expect(try sample(bitmap, angle: 255, radius: min(radius, 0.32)).greenComponent < 0.2)
        if isCompact { #expect(try recognizedText(bitmap).isEmpty) }
        if isCompact && side == 188 {
            #expect(try sample(bitmap, angle: 153).blueComponent > 0.8)
            #expect(try sample(bitmap, angle: 33).greenComponent > 0.6)
            #expect(try sample(bitmap, angle: 147).greenComponent > 0.6)
            #expect(try sample(bitmap, angle: 183).greenComponent < 0.2)
        }
        #expect(try sample(bitmap, angle: 90, radius: 0.12).greenComponent > 0.6)
        let maxX = bitmap.pixelsWide - 1
        let maxY = bitmap.pixelsHigh - 1
        for (x, y) in [(1, 1), (maxX - 1, 1), (1, maxY - 1), (maxX - 1, maxY - 1)] {
            #expect(try #require(bitmap.colorAt(x: x, y: y)).alphaComponent < 0.05)
        }
        for angle in [0.0, 90, 180, 270] {
            #expect(try sample(bitmap, angle: angle, radius: radius).alphaComponent > 0.95)
        }
        let scale = Double(bitmap.pixelsWide) / side
        let outerRadius = (side / 2 - (isCompact ? 0 : 6) + 1) * scale
        var outsideAlpha: CGFloat = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if hypot(Double(x) + 0.5 - Double(bitmap.pixelsWide) / 2,
                         Double(y) + 0.5 - Double(bitmap.pixelsHigh) / 2) > outerRadius {
                    outsideAlpha = max(outsideAlpha, bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1)
                }
            }
        }
        #expect(outsideAlpha < 0.05)
    }

    @Test(arguments: [false, true])
    func sectorScrollUsesTheRenderedCircleInBothPresentations(isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false), playSound: { _ in },
            now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        timer.selectMode(.pomodoro)
        let side = isCompact ? 32.0 : 188
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: isCompact, changePresentation: {}))
        _ = try render(hosting, side: side)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        let adapter = ScrollTimeAdjuster(countdown: timer, window: window, isCompact: { isCompact }, uptime: { 0 })
        let radius = isCompact ? 14.0 : 80
        let blue = NSPoint(x: side / 2 + radius * sin(11 * .pi / 12), y: side / 2 + radius * cos(11 * .pi / 12))
        let green = NSPoint(x: side / 2 + radius, y: side / 2)
        adapter.handle(try scrollEvent(in: window, at: blue, delta: 12))
        #expect(timer.pomodoro.restDuration == 600)
        #expect(timer.pomodoro.focusDuration == 1_500)
        adapter.handle(try scrollEvent(in: window, at: green, delta: 36, option: true, precise: true))
        #expect(timer.pomodoro.focusDuration == 1_800)
        adapter.handle(try scrollEvent(in: window, at: green, delta: 5, option: true, precise: true))
        #expect(timer.pomodoro.focusDuration == 1_800)
        let edited = try render(hosting, side: side)
        #expect(try sample(edited, angle: 210).blueComponent > 0.8)
        #expect(try sample(edited, angle: 72).greenComponent > 0.6)
        #expect(try sample(edited, angle: 174).greenComponent > 0.6)
        #expect(try sample(edited, angle: 252).greenComponent < 0.2)
        // OCR can read the four rings as punctuation; there must be no phase label.
        #expect(try recognizedText(edited).allSatisfy { $0 != "Focus" && $0 != "Rest" })
        #expect(timer.timer.status == .empty)
    }

    @Test
    func modeAwareCompactKeepsCountdownRenderingAndPausedReturn() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(), playSound: { _ in },
            now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }
        )
        timer.selectMode(.countdown)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: true, changePresentation: {}))
        let original = NSHostingView(rootView: CompactTimerView(model: timer.timer))
        func expectUnchangedBitmap() throws {
            let actual = try render(hosting, side: 32)
            let expected = try render(original, side: 32)
            #expect(actual.representation(using: .png, properties: [:]) == expected.representation(using: .png, properties: [:]))
        }
        try expectUnchangedBitmap() // Empty Countdown.
        timer.adjustTimerDuration(by: 1_200)
        try expectUnchangedBitmap() // Active Countdown.
        timer.toggleRunning()
        try expectUnchangedBitmap() // Paused Countdown.
        timer.selectMode(.pomodoro)
        let pomodoro = try render(hosting, side: 32)
        #expect(timer.mode.isClockEnabled)
        #expect(try recognizedText(pomodoro).isEmpty)
        timer.selectMode(.countdown)
        #expect(timer.timer.isPaused)
        #expect(timer.timer.remaining == 1_200)
        try expectUnchangedBitmap()
    }

    @Test(arguments: CountdownMode.allCases)
    func compactDirectionFollowsTimerMode(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 20))!
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        timer.adjustTimerDuration(by: 1_800)
        timer.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: true, changePresentation: {}))
        let initial = try render(hosting, side: 32)
        if mode.isClockEnabled {
            #expect(try sample(initial, angle: 240).greenComponent > 0.6)
            #expect(try sample(initial, angle: 15).greenComponent < 0.2)
        } else {
            #expect(try sample(initial, angle: 90).greenComponent > 0.6)
            #expect(try sample(initial, angle: 240).greenComponent < 0.2)
        }
        if mode == .pomodoro { #expect(try sample(initial, angle: 282).blueComponent > 0.8) }
        for other in CountdownMode.allCases { timer.selectMode(other) }
        timer.selectMode(mode)
        #expect(try render(hosting, side: 32).representation(using: .png, properties: [:]) == initial.representation(using: .png, properties: [:]))
    }

    @Test(arguments: CountdownMode.allCases)
    func modeSelectionChangesDisplayAndReturnsToTheSameImage(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(),
            playSound: { _ in }, now: { Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))! }, saveEnablement: { _, _ in }
        )
        timer.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: {}))
        func image() throws -> Data? {
            try render(hosting).representation(using: .png, properties: [:])
        }
        let initial = try image()
        for other in CountdownMode.allCases where other != mode {
            timer.selectMode(other)
            #expect(try image() != initial)
        }
        timer.selectMode(mode)
        #expect(try image() == initial)
    }

    @Test(arguments: [0.0, 1_500, 1_800, 3_600, 5_400, 6_900, 7_800])
    func fourDotsRenderCompletedCurrentAndPendingFocus(elapsed: TimeInterval) throws {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        var model = PomodoroModel()
        model.toggleRunning(at: start)
        model.update(at: start + elapsed)
        let bitmap = try render(NSHostingView(rootView: PomodoroView(model: model)))
        let scale = Double(bitmap.pixelsWide) / 188
        var areas: [PomodoroModel.DotState: [Int]] = [:]
        for index in 0..<4 {
            let centerX = 73.0 + Double(index) * 14
            var whitePixels = 0
            for y in Int(122 * scale)..<Int(130 * scale) {
                for x in Int((centerX - 4) * scale)..<Int((centerX + 4) * scale) {
                    let color = try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    if min(color.redComponent, color.greenComponent, color.blueComponent) > 0.8 {
                        whitePixels += 1
                    }
                }
            }
            #expect(whitePixels > 0, "Dot \(index + 1) must be visible")
            areas[model.dotStates[index], default: []].append(whitePixels)
        }
        if let completed = areas[.completed]?.min(), let current = areas[.current]?.max() {
            #expect(completed > current)
        }
        if let current = areas[.current]?.min(), let pending = areas[.pending]?.max() {
            #expect(current > pending)
        }
        if let completed = areas[.completed]?.min(), let pending = areas[.pending]?.max() {
            #expect(completed > pending)
        }
    }

    @Test(arguments: [0.0, 1_500, 1_800, 6_900])
    func popupShowsCurrentPhaseTimeAndSession(elapsed: TimeInterval) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // Start on a clock mark so both displays have the same phase times.
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(popupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        timer.selectMode(.pomodoro)
        now += elapsed
        timer.update()
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isPopup: true, changePresentation: {}))
        let bitmap = try render(hosting)
        let text = try recognizedText(bitmap).joined(separator: " ")
        #expect(text.contains(timer.pomodoro.phaseLabel))
        #expect(text.contains(elapsed == 1_500 ? "5:00" : elapsed == 6_900 ? "15:00" : "25:00"))
        #expect(text.contains("Session \(timer.pomodoro.stage) of 4"))
        #expect(!text.contains("Next"))
        #expect(timer.mode.isClockEnabled)

        // The popup does not change sector geometry outside its label.
        let normal = try render(NSHostingView(rootView: PomodoroView(
            model: timer.pomodoro, clockDate: now
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
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(currentTimeoutEnabled: false, popupEnabled: false),
            playSound: { _ in }, now: { now }
        )
        timer.selectMode(clockEnabled ? .timer : .countdown)
        timer.adjustTimerDuration(by: 600)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isPopup: true, changePresentation: {}))
        #expect(try recognizedText(render(hosting)).contains("10:00"))
        now += 78
        timer.update()
        let text = try recognizedText(render(hosting)).joined(separator: " ")
        #expect(text.contains(timer.mode.label))
        #expect(text.contains("8:42"))
        #expect(!text.contains("Session"))
        timer.toggleRunning()
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

    private func render<V: View>(_ hosting: NSHostingView<V>, side: Double = 188) throws -> NSBitmapImageRep {
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(x: 0, y: 0, width: side, height: side)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    private func recognizedText(_ bitmap: NSBitmapImageRep) throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: #require(bitmap.cgImage)).perform([request])
        return request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
    }

    private func sample(_ bitmap: NSBitmapImageRep, angle: Double, radius: Double = 0.35) throws -> NSColor {
        let radians = angle * .pi / 180
        let x = Int(Double(bitmap.pixelsWide) * (0.5 + radius * sin(radians)))
        let y = Int(Double(bitmap.pixelsHigh) * (0.5 - radius * cos(radians)))
        return try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
    }

    private func pressTimer(_ element: Any, labelPrefix: String) -> Bool {
        if let element = element as? NSAccessibilityProtocol {
            if element.accessibilityLabel()?.hasPrefix(labelPrefix) == true {
                return element.accessibilityPerformPress()
            }
            return (element.accessibilityChildren() ?? []).contains { pressTimer($0, labelPrefix: labelPrefix) }
        }
        guard let element = element as? NSObject else { return false }
        let label = element.accessibilityAttributeValue(.description) as? String
            ?? (element.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXAttributedDescription")) as? NSAttributedString)?.string
        let press = NSSelectorFromString("accessibilityPerformPress")
        if label?.hasPrefix(labelPrefix) == true, element.responds(to: press) {
            // SwiftUI exposes the public AppKit action without declaring
            // NSAccessibilityProtocol conformance. Keep its BOOL return type.
            let action = unsafeBitCast(element.method(for: press), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
            return action(element, press)
        }
        return (element.accessibilityAttributeValue(.children) as? [Any] ?? []).contains { pressTimer($0, labelPrefix: labelPrefix) }
    }

    private func accessibilityLabels(_ element: Any) -> [String] {
        if let element = element as? NSAccessibilityProtocol {
            let label = element.accessibilityLabel().map { [$0] } ?? []
            return label + (element.accessibilityChildren() ?? []).flatMap(accessibilityLabels)
        }
        guard let element = element as? NSObject else { return [] }
        // SwiftUI nodes use the informal AppKit accessibility API.
        let label = element.accessibilityAttributeValue(.description) as? String
            ?? (element.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AXAttributedDescription")) as? NSAttributedString)?.string
        let children = element.accessibilityAttributeValue(.children) as? [Any] ?? []
        return (label.map { [$0] } ?? []) + children.flatMap(accessibilityLabels)
    }
}
