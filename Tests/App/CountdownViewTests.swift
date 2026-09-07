import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownViewTests {
    @Test(arguments: [true, false])
    func defaultPomodoroRendersFixedScaleSectorsAndOnlyFocusText(timeoutEnabled: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, currentTimeoutEnabled: timeoutEnabled, reminderEnabled: false),
            playSound: { _ in }
        )
        timer.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: {}))
        let bitmap = try render(hosting)

        // Literal samples on each side of the specified 0°, 30°, and 180° boundaries.
        for angle in [3.0, 15, 27] {
            let color = try sample(bitmap, angle: angle)
            #expect(color.blueComponent > color.greenComponent + 0.15)
            #expect(color.blueComponent > color.redComponent + 0.25)
        }
        for angle in [33.0, 90, 177] {
            let color = try sample(bitmap, angle: angle)
            #expect(abs(color.redComponent - 0.24) < 0.03)
            #expect(abs(color.greenComponent - 0.68) < 0.03)
            #expect(abs(color.blueComponent - 0.42) < 0.03)
        }
        for angle in [183.0, 270, 357] {
            let color = try sample(bitmap, angle: angle)
            #expect(abs(color.redComponent - 0.11) < 0.03)
            #expect(abs(color.greenComponent - 0.11) < 0.03)
            #expect(abs(color.blueComponent - 0.12) < 0.03)
        }
        // Near the center, color is still filled; this is not a progress ring.
        let interior = try sample(bitmap, angle: 90, radius: 0.12)
        #expect(abs(interior.greenComponent - 0.68) < 0.03)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: #require(bitmap.cgImage)).perform([request])
        let text = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
        #expect(text == ["Focus"])
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousEnhancedUI = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previousEnhancedUI, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        #expect(accessibilityLabels(hosting).contains("Pomodoro running. Focus: 25 minutes remaining. Break: 5 minutes remaining."))
    }

    @Test
    func restartedPomodoroRendersSavedAllocationsAndStartsFocus() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TimerStateStore(environment: ["XDG_STATE_HOME": directory.path])
        let configuration = CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, reminderEnabled: false)
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let timer = CountdownController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        timer.selectMode(.pomodoro)
        timer.adjustPomodoroDuration(.focus, by: -300)
        timer.adjustPomodoroDuration(.shortBreak, by: 120)
        now += 1_320
        timer.update()
        #expect(timer.pomodoro.phaseLabel == "Break")
        timer.save()
        now += 7_200

        let restored = CountdownController(stateStore: store, configuration: configuration, playSound: { _ in sounds += 1 }, now: { now })
        let hosting = NSHostingView(rootView: CountdownView(countdown: restored, changePresentation: {}))
        let bitmap = try render(hosting)
        // Saved 7-minute break spans 42°; saved 20-minute focus ends at 162°.
        for angle in [3.0, 39] {
            #expect(try sample(bitmap, angle: angle).blueComponent > 0.8)
        }
        for angle in [45.0, 90, 159] {
            #expect(try sample(bitmap, angle: angle).greenComponent > 0.6)
        }
        for angle in [165.0, 270, 357] {
            #expect(try sample(bitmap, angle: angle).greenComponent < 0.2)
        }
        #expect(try recognizedText(bitmap) == ["Focus"])
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousEnhancedUI = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previousEnhancedUI, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        #expect(accessibilityLabels(hosting).contains("Pomodoro running. Focus: 20 minutes remaining. Break: 7 minutes remaining."))
        #expect(sounds == 0)
    }

    @Test
    func runningPomodoroDepletesGreenThenBlueAtFixedBoundaries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var expansions = 0
        var sounds = 0
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, autosetEnabled: true, reminderEnabled: false),
            playSound: { _ in sounds += 1 }, now: { now }
        )
        timer.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: { expansions += 1 }))
        _ = try render(hosting)
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousEnhancedUI = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previousEnhancedUI, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }

        now += 600
        timer.update()
        let focus = try render(hosting)
        for angle in [3.0, 15, 27] {
            #expect(try sample(focus, angle: angle).blueComponent > 0.8)
        }
        for angle in [33.0, 90, 117] {
            #expect(try sample(focus, angle: angle).greenComponent > 0.6)
        }
        for angle in [123.0, 177, 183, 270, 357] {
            #expect(try sample(focus, angle: angle).greenComponent < 0.2)
        }
        #expect(try recognizedText(focus) == ["Focus"])
        #expect(accessibilityLabels(hosting).contains("Pomodoro running. Focus: 15 minutes remaining. Break: 5 minutes remaining."))

        now += 900
        timer.update()
        let transition = try render(hosting)
        #expect(try sample(transition, angle: 27).blueComponent > 0.8)
        #expect(try sample(transition, angle: 33).greenComponent < 0.2)
        #expect(try recognizedText(transition) == ["Break"])

        now += 120
        timer.update()
        let shortBreak = try render(hosting)
        for angle in [3.0, 15] {
            #expect(try sample(shortBreak, angle: angle).blueComponent > 0.8)
        }
        for angle in [21.0, 27, 33, 90, 177, 270] {
            #expect(try sample(shortBreak, angle: angle).blueComponent < 0.2)
        }
        #expect(try recognizedText(shortBreak) == ["Break"])
        #expect(accessibilityLabels(hosting).contains("Pomodoro running. Break: 3 minutes remaining. Focus complete."))
        timer.togglePomodoroRunning()
        _ = try render(hosting)
        #expect(accessibilityLabels(hosting).contains("Pomodoro paused. Break: 3 minutes remaining. Focus complete."))
        timer.togglePomodoroRunning()
        now += 120
        timer.update() // Final minute must not request a presentation change.
        now += 60
        timer.update()
        timer.update()
        let completed = try render(hosting)
        // Window color management can change RGB values. All depleted sectors
        // must match the unallocated background and remain dark.
        let background = try sample(completed, angle: 270)
        for angle in [3.0, 15, 27, 33, 90, 177] {
            let color = try sample(completed, angle: angle)
            #expect(color.redComponent < 0.2 && color.greenComponent < 0.2 && color.blueComponent < 0.2)
            #expect(abs(color.redComponent - background.redComponent) < 0.01)
            #expect(abs(color.greenComponent - background.greenComponent) < 0.01)
            #expect(abs(color.blueComponent - background.blueComponent) < 0.01)
        }
        #expect(accessibilityLabels(hosting).contains("Pomodoro complete. Focus: 0 minutes remaining. Break: 0 minutes remaining."))
        #expect(expansions == 0)
        #expect(sounds == 0)
    }

    @Test(arguments: CountdownMode.allCases, [false, true])
    func hostedPressChangesPresentationWithoutChangingTimerState(mode: CountdownMode, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var expansions = 0
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, reminderEnabled: false),
            playSound: { _ in }, now: { now }
        )
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
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, reminderEnabled: false),
            playSound: { _ in }, now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        timer.adjustTimerDuration(by: 1_200)
        timer.toggleTimerRunning()
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
        #expect(try sample(preview, angle: 15).blueComponent > 0.8)
        #expect(try sample(preview, angle: 90).greenComponent > 0.6)
        timer.selectMode(.timer)
        let after = try render(hosting)
        #expect(before.representation(using: .png, properties: [:]) == after.representation(using: .png, properties: [:]))
        #expect(timer.timer.isPaused)
        #expect(timer.timer.remaining == 1_200)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: #require(after.cgImage)).perform([request])
        #expect(request.results?.contains { $0.topCandidates(1).first?.string == "20" } == true)
    }

    @Test
    func sectorScrollUpdatesHostedGeometryPhaseTextAndAccessibility() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, reminderEnabled: false),
            playSound: { _ in sounds += 1 }, now: { now }
        )
        timer.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: {}))
        _ = try render(hosting)
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousEnhancedUI = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previousEnhancedUI, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        let adapter = ScrollTimeAdjuster(countdown: timer, window: window)
        let blue = NSPoint(x: 110, y: 158)
        let green = NSPoint(x: 160, y: 94)
        adapter.handle(try scrollEvent(in: window, at: blue, delta: 1))
        let largerBreak = try render(hosting)
        #expect(try sample(largerBreak, angle: 33).blueComponent > 0.8)
        #expect(try sample(largerBreak, angle: 39).greenComponent > 0.6)
        #expect(try sample(largerBreak, angle: 183).greenComponent > 0.6)
        #expect(try sample(largerBreak, angle: 189).greenComponent < 0.2)
        #expect(accessibilityLabels(hosting).contains("Pomodoro running. Focus: 25 minutes remaining. Break: 6 minutes remaining."))
        adapter.handle(try scrollEvent(in: window, at: green, delta: 1))
        let largerFocus = try render(hosting)
        #expect(try sample(largerFocus, angle: 33).blueComponent > 0.8)
        #expect(try sample(largerFocus, angle: 189).greenComponent > 0.6)
        #expect(try sample(largerFocus, angle: 195).greenComponent < 0.2)
        adapter.handle(try scrollEvent(in: window, at: blue, delta: -1))
        let smallerBreak = try render(hosting)
        #expect(try sample(smallerBreak, angle: 27).blueComponent > 0.8)
        #expect(try sample(smallerBreak, angle: 33).greenComponent > 0.6)
        #expect(try sample(smallerBreak, angle: 183).greenComponent > 0.6)
        #expect(try sample(smallerBreak, angle: 189).greenComponent < 0.2)

        now += 600
        adapter.handle(try scrollEvent(in: window, at: NSPoint(x: 127, y: 36), delta: -1))
        let running = try render(hosting)
        #expect(try sample(running, angle: 27).blueComponent > 0.8)
        #expect(try sample(running, angle: 117).greenComponent > 0.6)
        #expect(try sample(running, angle: 123).greenComponent < 0.2)
        #expect(try recognizedText(running) == ["Focus"])
        #expect(accessibilityLabels(hosting).contains("Pomodoro running. Focus: 15 minutes remaining. Break: 5 minutes remaining."))
        timer.togglePomodoroRunning()
        now += 1_200
        adapter.handle(try scrollEvent(in: window, at: blue, delta: 1))
        let paused = try render(hosting)
        #expect(try sample(paused, angle: 33).blueComponent > 0.8)
        #expect(try sample(paused, angle: 39).greenComponent > 0.6)
        #expect(try sample(paused, angle: 123).greenComponent > 0.6)
        #expect(try sample(paused, angle: 129).greenComponent < 0.2)
        #expect(accessibilityLabels(hosting).contains("Pomodoro paused. Focus: 15 minutes remaining. Break: 6 minutes remaining."))
        adapter.handle(try scrollEvent(in: window, at: green, delta: -180, option: true))
        let shortBreak = try render(hosting)
        #expect(try sample(shortBreak, angle: 33).blueComponent > 0.8)
        #expect(try sample(shortBreak, angle: 39).greenComponent < 0.2)
        #expect(try recognizedText(shortBreak) == ["Break"])
        #expect(accessibilityLabels(hosting).contains("Pomodoro paused. Break: 6 minutes remaining. Focus complete."))
        #expect(sounds == 0)
        #expect(timer.timer.status == .empty)
    }

    @Test(arguments: [32.0, 71, 123, 188], [false, true])
    func pomodoroStaysCircularAtBothPresentationsAndSquareTransitionSizes(side: Double, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, reminderEnabled: false),
            playSound: { _ in }, now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        timer.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: isCompact, changePresentation: {}))
        let bitmap = try render(hosting, side: side)
        let radius = (side / 2 - (isCompact ? 0 : 6) - 4) / side
        #expect(try sample(bitmap, angle: 15, radius: radius).blueComponent > 0.8)
        #expect(try sample(bitmap, angle: 90, radius: radius).greenComponent > 0.6)
        #expect(try sample(bitmap, angle: 270, radius: radius).greenComponent < 0.2)
        if isCompact { #expect(try recognizedText(bitmap).isEmpty) }
        if isCompact && side == 188 {
            #expect(try sample(bitmap, angle: 27).blueComponent > 0.8)
            #expect(try sample(bitmap, angle: 33).greenComponent > 0.6)
            #expect(try sample(bitmap, angle: 177).greenComponent > 0.6)
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
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, reminderEnabled: false), playSound: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        timer.selectMode(.pomodoro)
        let side = isCompact ? 32.0 : 188
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: isCompact, changePresentation: {}))
        _ = try render(hosting, side: side)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        let adapter = ScrollTimeAdjuster(countdown: timer, window: window, isCompact: { isCompact })
        let radius = isCompact ? 14.0 : 80
        let blue = NSPoint(x: side / 2 + radius * sin(.pi / 12), y: side / 2 + radius * cos(.pi / 12))
        let green = NSPoint(x: side / 2 + radius, y: side / 2)
        adapter.handle(try scrollEvent(in: window, at: blue, delta: 30))
        #expect(timer.pomodoro.breakDuration == 360)
        #expect(timer.pomodoro.focusDuration == 1_500)
        adapter.handle(try scrollEvent(in: window, at: green, delta: 7, option: true))
        #expect(timer.pomodoro.focusDuration == 1_500)
        adapter.handle(try scrollEvent(in: window, at: green, delta: 5, option: true))
        #expect(timer.pomodoro.focusDuration == 1_560)
        let edited = try render(hosting, side: side)
        #expect(try sample(edited, angle: 24).blueComponent > 0.8)
        #expect(try sample(edited, angle: 48).greenComponent > 0.6)
        #expect(try sample(edited, angle: 180).greenComponent > 0.6)
        #expect(try sample(edited, angle: 210).greenComponent < 0.2)
        #expect(try recognizedText(edited) == (isCompact ? [] : ["Focus"]))
        #expect(timer.timer.status == .empty)
    }

    @Test
    func presentationReplacementKeepsEditedRunningAndPausedPair() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Date(timeIntervalSince1970: 1_700_000_000)
        var sounds = 0
        var presentationRequests = 0
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false, autosetEnabled: true, reminderEnabled: false),
            playSound: { _ in sounds += 1 }, now: { now }
        )
        timer.selectMode(.pomodoro)
        let normal = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: { presentationRequests += 1 }))
        let compact = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: true, changePresentation: { presentationRequests += 1 }))
        _ = try render(normal)
        _ = try render(compact, side: 32)
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previousEnhancedUI = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previousEnhancedUI, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: normal.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = normal
        defer { window.close() }
        var isCompact = false
        let adapter = ScrollTimeAdjuster(countdown: timer, window: window, isCompact: { isCompact })
        adapter.handle(try scrollEvent(in: window, at: NSPoint(x: 110, y: 158), delta: 60, option: true))
        adapter.handle(try scrollEvent(in: window, at: NSPoint(x: 160, y: 94), delta: -60, option: true))
        #expect(timer.pomodoro.focusDuration == 1_200)
        #expect(timer.pomodoro.breakDuration == 600)

        func showCompact() throws {
            isCompact = true
            window.contentView = compact
            window.setContentSize(NSSize(width: 32, height: 32))
            let bitmap = try render(compact, side: 32)
            #expect(try recognizedText(bitmap).isEmpty)
            #expect(timer.mode == .pomodoro)
            #expect(timer.pomodoro.focusDuration == 1_200)
            #expect(timer.pomodoro.breakDuration == 600)
        }
        func showNormal() throws {
            isCompact = false
            window.contentView = normal
            window.setContentSize(NSSize(width: 188, height: 188))
            _ = try render(normal)
            #expect(timer.mode == .pomodoro)
            #expect(timer.pomodoro.focusDuration == 1_200)
            #expect(timer.pomodoro.breakDuration == 600)
        }

        try showCompact()
        #expect(timer.pomodoro.status == .running)
        #expect(accessibilityLabels(compact).contains("Pomodoro running. Focus: 20 minutes remaining. Break: 10 minutes remaining."))
        let ready = try render(compact, side: 32)
        #expect(try sample(ready, angle: 30).blueComponent > 0.8)
        #expect(try sample(ready, angle: 90).greenComponent > 0.6)
        #expect(try sample(ready, angle: 210).greenComponent < 0.2)
        try showNormal()
        #expect(timer.pomodoro.status == .running)
        now += 600
        timer.update()
        try showCompact()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.focusRemaining == 600)
        #expect(timer.pomodoro.breakRemaining == 600)
        #expect(accessibilityLabels(compact).contains("Pomodoro running. Focus: 10 minutes remaining. Break: 10 minutes remaining."))
        let focus = try render(compact, side: 32)
        #expect(try sample(focus, angle: 30).blueComponent > 0.8)
        #expect(try sample(focus, angle: 90).greenComponent > 0.6)
        #expect(try sample(focus, angle: 150).greenComponent < 0.2)

        // Both hosts can exist during the app's cross-fade. Repeated updates at
        // one command time must not consume elapsed time twice or repeat a pair.
        now += 600
        timer.update()
        try showNormal()
        timer.update()
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 600)
        #expect(try recognizedText(render(normal)) == ["Break"])
        now += 120
        timer.toggleRunning()
        try showCompact()
        now += 1_200
        timer.update()
        #expect(timer.pomodoro.status == .paused)
        #expect(timer.pomodoro.breakRemaining == 480)
        #expect(accessibilityLabels(compact).contains("Pomodoro paused. Break: 8 minutes remaining. Focus complete."))
        let paused = try render(compact, side: 32)
        #expect(try sample(paused, angle: 30).blueComponent > 0.8)
        #expect(try sample(paused, angle: 90).greenComponent < 0.2)
        try showNormal()
        #expect(timer.pomodoro.status == .paused)
        #expect(timer.pomodoro.breakRemaining == 480)
        try showCompact()
        timer.toggleRunning()
        now += 420
        timer.update()
        _ = try render(compact, side: 32)
        #expect(timer.pomodoro.status == .running)
        #expect(timer.pomodoro.breakRemaining == 60)
        #expect(presentationRequests == 0)
        now += 60
        timer.update()
        timer.update()
        let completed = try render(compact, side: 32)
        #expect(timer.pomodoro.status == .completed)
        #expect(timer.pomodoro.focusRemaining == 0)
        #expect(timer.pomodoro.breakRemaining == 0)
        #expect(try sample(completed, angle: 30).blueComponent < 0.2)
        #expect(try sample(completed, angle: 90).greenComponent < 0.2)
        #expect(accessibilityLabels(compact).contains("Pomodoro complete. Focus: 0 minutes remaining. Break: 0 minutes remaining."))
        try showNormal()
        #expect(timer.pomodoro.status == .completed)
        #expect(presentationRequests == 0)
        #expect(sounds == 0)
        #expect(timer.timer.status == .active)
        #expect(!timer.countdown.isPaused)
        #expect(timer.features.reminderIntervalCount == 0)
    }

    @Test
    func modeAwareCompactKeepsCountdownRenderingAndPausedReturn() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false), playSound: { _ in },
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
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
        timer.toggleTimerRunning()
        try expectUnchangedBitmap() // Paused Countdown.
        timer.selectMode(.pomodoro)
        let pomodoro = try render(hosting, side: 32)
        #expect(try sample(pomodoro, angle: 15).blueComponent > 0.8)
        #expect(try recognizedText(pomodoro).isEmpty)
        timer.selectMode(.timer)
        #expect(timer.timer.isPaused)
        #expect(timer.timer.remaining == 1_200)
        try expectUnchangedBitmap()
    }

    @Test(arguments: CountdownMode.allCases)
    func compactDirectionFollowsClockFaceSetting(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 22, minute: 20))!
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: true, clockHandsEnabled: false, reminderEnabled: false),
            playSound: { _ in }, now: { now }, saveEnablement: { _, _ in }
        )
        timer.adjustTimerDuration(by: 1_800)
        timer.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: true, changePresentation: {}))
        let clock = try render(hosting, side: 32)
        #expect(try sample(clock, angle: 240).greenComponent > 0.6)
        #expect(try sample(clock, angle: 15).greenComponent < 0.2)
        #expect(try sample(clock, angle: 15).blueComponent < 0.2)
        if mode == .pomodoro { #expect(try sample(clock, angle: 282).blueComponent > 0.8) }
        timer.features.setClockFaceEnabled(false)
        let duration = try render(hosting, side: 32)
        #expect(try sample(duration, angle: 240).greenComponent < 0.2)
        #expect(try sample(duration, angle: 90).greenComponent > 0.6)
        timer.features.setClockHandsEnabled(true)
        #expect(try render(hosting, side: 32).representation(using: .png, properties: [:]) == duration.representation(using: .png, properties: [:]))
        timer.features.setClockFaceEnabled(true)
        #expect(try render(hosting, side: 32).representation(using: .png, properties: [:]) == clock.representation(using: .png, properties: [:]))
    }

    @Test(arguments: CountdownMode.allCases)
    func sharedClockControlsChangeBothModeDisplays(mode: CountdownMode) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockFaceEnabled: false, clockHandsEnabled: false),
            playSound: { _ in }, saveEnablement: { _, _ in }
        )
        timer.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: timer, changePresentation: {}))
        func image() throws -> Data? {
            try render(hosting).representation(using: .png, properties: [:])
        }
        let plain = try image()
        timer.features.setClockFaceEnabled(true)
        let face = try image()
        #expect(face != plain)
        timer.features.setClockFaceEnabled(false)
        #expect(try image() == plain)
        timer.features.setClockHandsEnabled(true)
        let hands = try image()
        #expect(hands != plain)
        #expect(hands != face)
        timer.features.setClockHandsEnabled(false)
        #expect(try image() == plain)
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
