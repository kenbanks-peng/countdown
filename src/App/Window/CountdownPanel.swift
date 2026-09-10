import AppKit

/// Keeps native window dragging separate from the content's click action.
@MainActor
final class CountdownPanel: NSPanel {
    private var mouseDownOrigin: NSPoint?
    private var mouseDownPoint: NSPoint?
    private let dragThreshold: CGFloat = 3
    private var didDrag = false
    private var isDispatchingPointerEvent = false
    private var pointerModifierFlags: NSEvent.ModifierFlags = []

    var clickModifierFlags: NSEvent.ModifierFlags {
        isDispatchingPointerEvent ? pointerModifierFlags : NSEvent.modifierFlags
    }

    var allowsClick: Bool {
        // Keyboard and accessibility activation must not depend on the last drag.
        !isDispatchingPointerEvent || (!didDrag && !exceedsDragThreshold(from: mouseDownOrigin, to: frame.origin))
    }

    override func sendEvent(_ event: NSEvent) {
        let wasDispatchingPointerEvent = isDispatchingPointerEvent
        let previousModifierFlags = pointerModifierFlags
        isDispatchingPointerEvent = [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type)
        pointerModifierFlags = event.modifierFlags
        defer {
            isDispatchingPointerEvent = wasDispatchingPointerEvent
            pointerModifierFlags = previousModifierFlags
        }

        switch event.type {
        case .leftMouseDown:
            mouseDownOrigin = frame.origin
            mouseDownPoint = convertPoint(toScreen: event.locationInWindow)
            didDrag = false
        case .leftMouseDragged, .leftMouseUp:
            // A small movement while pressing is still a click. Use screen
            // coordinates because native dragging moves the window too.
            didDrag = didDrag || exceedsDragThreshold(
                from: mouseDownPoint, to: convertPoint(toScreen: event.locationInWindow)
            ) || exceedsDragThreshold(from: mouseDownOrigin, to: frame.origin)
        default:
            break
        }
        // Keep forwarding the release so the button can clear its pressed state.
        // Native window dragging can consume drag events, so also compare origins.
        super.sendEvent(event)
    }

    private func exceedsDragThreshold(from start: NSPoint?, to end: NSPoint) -> Bool {
        guard let start else { return false }
        return hypot(end.x - start.x, end.y - start.y) > dragThreshold
    }
}
