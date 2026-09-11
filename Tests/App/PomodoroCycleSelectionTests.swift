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

    @Test(arguments: [false, true])
    func defaultsAreRestoredOnlyWhenRequested(restoringDefaults: Bool) {
        let session = ClockTestSession()
        defer { session.close() }
        let controller = session.controller
        controller.selectMode(.pomodoro)
        controller.adjustPomodoroDuration(.focus, by: -300)
        controller.adjustPomodoroDuration(.rest, by: 300)
        controller.adjustPomodoroDuration(.longRest, by: 300)
        controller.notifications.setNotificationEnabled(true)
        controller.restartPomodoroStage(4, restoringDefaults: restoringDefaults)
        #expect(controller.pomodoro.focusRemaining == (restoringDefaults ? 1_500 : 1_200))
        #expect(controller.pomodoro.restDuration == (restoringDefaults ? 300 : 600))
        #expect(controller.pomodoro.restRemaining == (restoringDefaults ? 900 : 1_200))
        #expect(controller.notifications.lastEvent == .work)
        let restored = session.makeController()
        #expect(restored.pomodoro.focusDuration == controller.pomodoro.focusDuration)
        #expect(restored.pomodoro.restDuration == controller.pomodoro.restDuration)
        #expect(restored.pomodoro.longRestDuration == controller.pomodoro.longRestDuration)
    }

    @Test
    func normalRestartRestoresSavedFocusAndKeepsExplicitZeroFocus() {
        let now = Date(timeIntervalSince1970: 1_699_999_800)
        var model = PomodoroModel()
        model.setClockEnabled(true, at: now)
        model.autoAlign(at: now + 600)
        #expect(model.focusDuration != 1_500)
        model.restartStage(2, at: now + 600)
        #expect(model.focusRemaining == 1_500)

        var zeroFocus = PomodoroModel(focusDuration: 0, defaultDurations: (1_500, 300, 1_200))
        zeroFocus.restartStage(2, at: now)
        #expect(zeroFocus.focusDuration == 0)
        zeroFocus.restartStage(3, restoringDefaults: true, at: now)
        #expect(zeroFocus.focusRemaining == 1_500)
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

    @Test(arguments: (1...15).flatMap { count in [true, false].map { (count, $0) } }, [false, true])
    func pointerSelectsCycleWithoutChangingPresentation(selection: (Int, Bool), option: Bool) throws {
        let (count, allowsClick) = selection
        let session = ClockTestSession()
        defer { session.close() }
        let controller = makeUIController(session, count: count)
        controller.selectMode(.pomodoro)
        let defaultFocus = controller.pomodoro.focusDuration
        controller.adjustPomodoroDuration(.focus, by: -300)
        var changes = 0
        let panel = CountdownPanel(contentRect: NSRect(x: 100, y: 120, width: 188, height: 188),
                                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: CountdownView(
            countdown: controller, allowsClick: { allowsClick },
            clickModifierFlags: { [weak panel] in panel?.clickModifierFlags ?? [] },
            changePresentation: { changes += 1 }
        ))
        panel.orderFront(nil)
        defer { panel.close() }
        panel.contentView?.layoutSubtreeIfNeeded()
        let layout = PomodoroCycleLayout(count: count)
        let pitch = layout.diameter + 2 + layout.spacing
        let lastRow = try #require(layout.rows.last)
        let x = 94 + CGFloat(lastRow.count - 1) / 2 * pitch
        let y = 62 - CGFloat(layout.rows.count - 1) / 2 * pitch
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: NSPoint(x: x, y: y), modifierFlags: option ? [.option] : [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApplication.shared.sendEvent(event)
        }
        #expect(controller.pomodoro.stage == (allowsClick ? count : 1))
        #expect(controller.pomodoro.focusDuration == (allowsClick && option ? defaultFocus : defaultFocus - 300))
        #expect(changes == 0)
    }

    private func makeUIController(_ session: ClockTestSession, count: Int = 8) -> CountdownController {
        CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": session.directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil, pomodoroFocusPeriodsPerCycle: count),
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
