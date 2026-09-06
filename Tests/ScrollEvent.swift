import AppKit
import Testing

/// Real Quartz scroll input at a Cocoa window point, without posting to the user's event queue.
@MainActor
func scrollEvent(in window: NSWindow, at point: NSPoint, delta: Int32, option: Bool = false) throws -> NSEvent {
    let event = try #require(CGEvent(
        scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
        wheel1: delta, wheel2: 0, wheel3: 0
    ))
    let screenPoint = window.convertPoint(toScreen: point)
    let screen = try #require(NSScreen.screens.first)
    event.location = CGPoint(x: screenPoint.x, y: screen.frame.maxY - screenPoint.y)
    event.flags = option ? .maskAlternate : []
    return try #require(NSEvent(cgEvent: event))
}
