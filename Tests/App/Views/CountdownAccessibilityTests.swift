import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
struct CountdownAccessibilityTests {
    @Test(arguments: CountdownMode.allCases, [false, true])
    func hostedPressChangesPresentationWithoutChangingTimerState(mode: CountdownMode, isCompact: Bool) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var now = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!
        var expansions = 0
        let controller = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(reminderEnabled: false),
            playSound: { _ in }, now: { now }
        )
        controller.selectMode(.countdown)
        controller.adjustTimerDuration(by: 1_800)
        controller.toggleRunning()
        controller.selectMode(mode)
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, isCompact: isCompact, changePresentation: { expansions += 1 }))
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
        #expect(accessibilityLabels(hosting).contains(mode == .pomodoro ? controller.pomodoro.accessibilityDescription : "30 minutes remaining"))
        #expect(pressTimer(hosting, labelPrefix: mode == .pomodoro ? "Pomodoro " : "30 minutes remaining"))
        #expect(expansions == 1)
        #expect(controller.controlLabel == "Resume")
        controller.toggleRunning()
        #expect(controller.controlLabel == "Pause")
        now += 60
        controller.update()
        _ = try render(hosting)
        #expect(pressTimer(hosting, labelPrefix: mode == .pomodoro ? "Pomodoro " : "29 minutes remaining"))
        #expect(expansions == 2)
        #expect(controller.controlLabel == "Pause")
        controller.toggleRunning()
        #expect(controller.controlLabel == "Resume")
        now += 1_200
        controller.update()
        _ = try render(hosting)
        #expect(pressTimer(hosting, labelPrefix: mode == .pomodoro ? "Pomodoro " : "29 minutes remaining"))
        #expect(expansions == 3)
        #expect(controller.controlLabel == "Resume")
        controller.toggleRunning()
        #expect(controller.controlLabel == "Pause")
    }
}
