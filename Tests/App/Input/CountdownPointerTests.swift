import AppKit
import SwiftUI
import Testing
@testable import Countdown

@MainActor
@Suite(.serialized)
struct CountdownPointerTests {
    @Test(arguments: [false, true], [false, true])
    func movingWindowDoesNotChangePresentation(isCompact: Bool, sendsDragEvent: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: true, sendsDragEvent: sendsDragEvent)
    }

    @Test(arguments: [false, true], [3.01, 8.0])
    func dragWithoutWindowMovementDoesNotChangePresentation(isCompact: Bool, distance: Double) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false, sendsDragEvent: true, pointerMovement: distance)
    }

    @Test(arguments: [false, true])
    func releaseBeyondThresholdDoesNotChangePresentation(isCompact: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false, pointerMovement: 8)
    }

    @Test(arguments: [false, true])
    func draggingBackToStartDoesNotChangePresentation(isCompact: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false, sendsDragEvent: true,
                               pointerMovement: 8, returnsToStart: true)
    }

    @Test(arguments: [false, true])
    func clickChangesPresentation(isCompact: Bool) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false)
    }

    @Test(arguments: [false, true], [0.0, 1.0, 3.0])
    func slightPointerMovementStillChangesPresentation(isCompact: Bool, distance: Double) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: false, sendsDragEvent: true, pointerMovement: distance)
    }

    @Test(arguments: [false, true], [1.0, 3.0])
    func slightWindowMovementStillChangesPresentation(isCompact: Bool, distance: Double) throws {
        try checkPointerAction(isCompact: isCompact, movesWindow: true, windowMovement: distance)
    }

    private func checkPointerAction(isCompact: Bool, movesWindow: Bool, sendsDragEvent: Bool = false,
                                    pointerMovement: CGFloat = 0, windowMovement: CGFloat = 100,
                                    returnsToStart: Bool = false) throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let countdown = CountdownController(
            sessionStore: TimerSessionStore(environment: ["XDG_STATE_HOME": directory.path]),
            configuration: CountdownConfiguration(alarmNotificationURL: nil),
            preferences: CountdownPreferences(popupEnabled: false),
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
        var point = NSPoint(x: side / 2, y: side / 2)
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
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX + windowMovement, y: panel.frame.minY))
        }
        point.x += pointerMovement
        if sendsDragEvent {
            try send(.leftMouseDragged)
        }
        if returnsToStart {
            point.x -= pointerMovement
            try send(.leftMouseDragged)
        }
        try send(.leftMouseUp)
        let expectedChanges = (movesWindow && windowMovement > 3) || pointerMovement > 3 ? 0 : 1
        #expect(changes == expectedChanges)
        #expect(panel.allowsClick) // Non-pointer activation remains available after a drag.

        // A drag must not suppress the next separate click.
        try send(.leftMouseDown)
        try send(.leftMouseUp)
        #expect(changes == expectedChanges + 1)
    }
}
