import AppKit
import SwiftUI
import Testing
@testable import Countdown

@MainActor
struct CountdownPointerTests {
    @Test(arguments: [false, true], [false, true])
    func movingWindowDoesNotChangePresentation(isCompact: Bool, sendsDragEvent: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: true, sendsDragEvent: sendsDragEvent)
    }

    @Test(arguments: [false, true])
    func dragWithoutWindowMovementDoesNotChangePresentation(isCompact: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false, sendsDragEvent: true)
    }

    @Test(arguments: [false, true])
    func clickChangesPresentation(isCompact: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false)
    }

    private func checkPointerAction(isCompact: Bool, movesWindow: Bool, sendsDragEvent: Bool = false) throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let countdown = CountdownController(
            stateStore: TimerStateStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            featureState: CountdownFeatureState(clockEnabled: false, reminderEnabled: false),
            playSound: { _ in }
        )
        var changes = 0
        let side: CGFloat = isCompact ? 32 : 188
        let panel = CountdownPanel(contentRect: NSRect(x: 100, y: 120, width: side, height: side),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: CountdownView(
            countdown: countdown, isCompact: isCompact,
            allowsClick: { [weak panel] in panel?.allowsClick ?? true },
            changePresentation: { changes += 1 }
        ))
        panel.orderFront(nil)
        defer { panel.close() }
        panel.contentView?.layoutSubtreeIfNeeded()
        let point = NSPoint(x: side / 2, y: side / 2)
        func send(_ type: NSEvent.EventType) throws {
            let event = try #require(NSEvent.mouseEvent(
                with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1
            ))
            NSApplication.shared.sendEvent(event)
        }
        try send(.leftMouseDown)
        if movesWindow {
            // Native background dragging keeps the pointer at the same window-local point.
            panel.setFrameOrigin(NSPoint(x: 200, y: 220))
        }
        if sendsDragEvent {
            try send(.leftMouseDragged)
        }
        try send(.leftMouseUp)
        let expectedChanges = movesWindow || sendsDragEvent ? 0 : 1
        #expect(changes == expectedChanges)
        #expect(panel.allowsClick) // Non-pointer activation remains available after a drag.

        // A drag must not suppress the next separate click.
        try send(.leftMouseDown)
        try send(.leftMouseUp)
        #expect(changes == expectedChanges + 1)
    }
}
