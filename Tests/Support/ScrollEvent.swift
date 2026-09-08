import AppKit
import Testing

/// Real Quartz scroll input at a Cocoa window point, without posting to the user's event queue.
@MainActor
func scrollEvent(in window: NSWindow, at point: NSPoint, delta: Int32, option: Bool = false,
                 phase: NSEvent.Phase = [], momentum: Bool = false) throws -> NSEvent {
    let event = try #require(CGEvent(
        scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
        wheel1: delta, wheel2: 0, wheel3: 0
    ))
    let screenPoint = window.convertPoint(toScreen: point)
    let screen = try #require(NSScreen.screens.first)
    event.location = CGPoint(x: screenPoint.x, y: screen.frame.maxY - screenPoint.y)
    event.flags = option ? .maskAlternate : []
    // Quartz and AppKit use different phase bit values.
    let phases: [(NSEvent.Phase, CGScrollPhase)] = [
        (.began, .began), (.changed, .changed), (.ended, .ended),
        (.cancelled, .cancelled), (.mayBegin, .mayBegin)
    ]
    let quartzPhase = phases.reduce(Int64(0)) { value, pair in
        phase.contains(pair.0) ? value | Int64(pair.1.rawValue) : value
    }
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: quartzPhase)
    event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum ? 1 : 0)
    return try #require(NSEvent(cgEvent: event))
}
