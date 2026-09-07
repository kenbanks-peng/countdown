import AppKit

/// Keeps native window dragging separate from the content's click action.
@MainActor
final class CountdownPanel: NSPanel {
    private var mouseDownOrigin: NSPoint?
    private var didDrag = false
    private var isDispatchingPointerEvent = false

    var allowsClick: Bool {
        // Keyboard and accessibility activation must not depend on the last drag.
        !isDispatchingPointerEvent || (!didDrag && mouseDownOrigin == frame.origin)
    }

    override func sendEvent(_ event: NSEvent) {
        let wasDispatchingPointerEvent = isDispatchingPointerEvent
        isDispatchingPointerEvent = [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type)
        defer { isDispatchingPointerEvent = wasDispatchingPointerEvent }

        switch event.type {
        case .leftMouseDown:
            mouseDownOrigin = frame.origin
            didDrag = false
        case .leftMouseDragged:
            didDrag = true
        default:
            break
        }
        // Keep forwarding the release so the button can clear its pressed state.
        // Native window dragging can consume drag events, so also compare origins.
        super.sendEvent(event)
    }
}
