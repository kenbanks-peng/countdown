import AppKit
import SwiftUI
import Testing
@testable import Countdown

@MainActor
@Suite(.serialized)
struct PomodoroCycleSelectionTests {
    @Test(arguments: [1, 2, 4], [false, true])
    func selectionStartsFullWorkAndSavesState(stage: Int, notifications: Bool) {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.notifications.setNotificationEnabled(notifications)
        let focus = controller.pomodoro.focusDuration
        session.now += focus + 60
        controller.update()
        controller.toggleRunning()
        let count = controller.notifications.notificationIntervalCount
        controller.restartPomodoroStage(stage)
        #expect(controller.pomodoro.stage == stage)
        #expect(controller.pomodoro.focusRemaining == focus)
        #expect(controller.pomodoro.restRemaining == controller.pomodoro.activeRestDuration)
        #expect(controller.pomodoro.completedFocusPeriods == stage - 1)
        #expect(!controller.engine.isPaused)
        #expect(controller.pomodoro.status == .running)
        #expect(controller.timer.remaining == focus + controller.pomodoro.activeRestDuration)
        #expect(controller.notifications.notificationIntervalCount == count + (notifications ? 1 : 0))
        if notifications { #expect(controller.notifications.lastEvent == .work) }
        let restored = session.makeController()
        #expect(restored.pomodoro.stage == stage)
        #expect(restored.pomodoro.focusRemaining == focus)
        #expect(!restored.engine.isPaused)
        session.now += 10
        controller.update()
        #expect(controller.pomodoro.focusRemaining == focus - 10)
        controller.restartPomodoroStage(stage)
        #expect(controller.pomodoro.focusRemaining == focus)
    }

    @Test
    func invalidSelectionAndOtherModesDoNothing() {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.restartPomodoroStage(2)
        #expect(controller.timer.remaining == 0)
        controller.selectMode(.pomodoro)
        let schedule = controller.pomodoro.clockSchedule
        for stage in [0, 5] { controller.restartPomodoroStage(stage) }
        #expect(controller.pomodoro.stage == 1)
        #expect(controller.pomodoro.clockSchedule?.focusEnd == schedule?.focusEnd)
    }

    @Test(arguments: [false, true])
    func pointerSelectsCycleWithoutChangingPresentation(allowsClick: Bool) throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = makeUIController(session)
        controller.selectMode(.pomodoro)
        var changes = 0
        let panel = CountdownPanel(contentRect: NSRect(x: 100, y: 120, width: 188, height: 188),
                                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: CountdownView(
            countdown: controller, allowsClick: { allowsClick }, changePresentation: { changes += 1 }
        ))
        panel.orderFront(nil)
        defer { panel.close() }
        panel.contentView?.layoutSubtreeIfNeeded()
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: NSPoint(x: 101, y: 62), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApplication.shared.sendEvent(event)
        }
        #expect(controller.pomodoro.stage == (allowsClick ? 3 : 1))
        #expect(changes == 0)
    }

    private func makeUIController(_ session: ClockTestSession) -> CountdownController {
        CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": session.directory.path]),
            preferences: CountdownPreferences(notificationEnabled: false),
            playSound: { _ in }, now: { session.now }
        )
    }

    @Test
    func hostedCyclePressDoesNotChangePresentation() throws {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = makeUIController(session)
        controller.selectMode(.pomodoro)
        var presentationChanges = 0
        let hosting = NSHostingView(rootView: CountdownView(countdown: controller, changePresentation: { presentationChanges += 1 }))
        _ = try render(hosting)
        let enhancedUI = NSAccessibility.Attribute(rawValue: "AXEnhancedUserInterface")
        let previous = NSApplication.shared.accessibilityAttributeValue(enhancedUI)
        NSApplication.shared.accessibilitySetValue(true, forAttribute: enhancedUI)
        defer { NSApplication.shared.accessibilitySetValue(previous, forAttribute: enhancedUI) }
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        #expect(pressTimer(hosting, labelPrefix: "Start Pomodoro cycle 3"))
        #expect(controller.pomodoro.stage == 3)
        #expect(presentationChanges == 0)
    }
}
