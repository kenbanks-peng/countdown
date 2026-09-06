import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct TimerViewTests {
    @Test(arguments: [true, false])
    func defaultPomodoroRendersFixedScaleSectorsAndOnlyFocusText(timeoutEnabled: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, currentTimeoutEnabled: timeoutEnabled),
            playSound: { _ in }
        )
        timer.selectMode(.pomodoro)
        let hosting = NSHostingView(rootView: TimerView(timer: timer, compact: {}))
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
        #expect(accessibilityLabels(hosting).contains("Pomodoro ready. Focus: 25 minutes allocated. Break: 5 minutes allocated."))
    }

    @Test
    func returningToCountdownRestoresItsRenderedPausedDisplay() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let timer = TimerController(
            stateStore: CountdownStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, clockHandsEnabled: false),
            playSound: { _ in }, now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        timer.adjustCountdownDuration(by: 1_200)
        timer.toggleCountdownRunning()
        let hosting = NSHostingView(rootView: TimerView(timer: timer, compact: {}))
        let before = try render(hosting)
        timer.selectMode(.pomodoro)
        let adapter = ScrollTimeAdjuster(timer: timer)
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
            wheel1: 30, wheel2: 0, wheel3: 0
        ))
        event.location = CGPoint(x: 120, y: 50)
        adapter.handle(try #require(NSEvent(cgEvent: event)))
        let preview = try render(hosting)
        #expect(try sample(preview, angle: 15).blueComponent > 0.8)
        #expect(try sample(preview, angle: 90).greenComponent > 0.6)
        timer.selectMode(.countdown)
        let after = try render(hosting)
        #expect(before.representation(using: .png, properties: [:]) == after.representation(using: .png, properties: [:]))
        #expect(timer.countdown.isPaused)
        #expect(timer.countdown.remaining == 1_200)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: #require(after.cgImage)).perform([request])
        #expect(request.results?.contains { $0.topCandidates(1).first?.string == "20" } == true)
    }

    private func render<V: View>(_ hosting: NSHostingView<V>) throws -> NSBitmapImageRep {
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.frame = NSRect(x: 0, y: 0, width: 188, height: 188)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        return bitmap
    }

    private func sample(_ bitmap: NSBitmapImageRep, angle: Double, radius: Double = 0.35) throws -> NSColor {
        let radians = angle * .pi / 180
        let x = Int(Double(bitmap.pixelsWide) * (0.5 + radius * sin(radians)))
        let y = Int(Double(bitmap.pixelsHigh) * (0.5 - radius * cos(radians)))
        return try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
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
