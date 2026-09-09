import AppKit
import Testing
@testable import Countdown

@MainActor
struct CountdownNotificationControllerTests {
    @Test
    func notificationStartsInvisibleAtScreenCenterAndNeverMoves() async throws {
        let notification = CountdownNotificationController(fadeDuration: 0.02)
        defer { notification.dismiss() }
        let screen = NSRect(x: -1_920, y: 200, width: 1_920, height: 1_080)
        notification.show(content: NSView(), screenFrame: screen,
                   size: NSSize(width: 188, height: 188), duration: 0.15)
        let panel = try #require(notification.panel)
        let frame = panel.frame
        #expect(frame.midX == screen.midX)
        #expect(frame.midY == screen.midY)
        #expect(panel.alphaValue == 0)
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.isMovable)
        #expect(!panel.isKeyWindow)
        #expect(!panel.hasShadow)
        for _ in 0..<100 {
            #expect(panel.frame == frame)
            if notification.panel == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notification.panel == nil)
        #expect(!panel.isVisible)
        #expect(panel.alphaValue == 0)
    }

    @Test
    func newNotificationCancelsOldDismissalAndDismissHidesPanel() async throws {
        let notification = CountdownNotificationController(fadeDuration: 0.01)
        defer { notification.dismiss() }
        let screen = NSRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let size = NSSize(width: 188, height: 188)
        notification.show(content: NSView(), screenFrame: screen, size: size, duration: 0.01)
        let old = try #require(notification.panel)
        notification.show(content: NSView(), screenFrame: screen, size: size, duration: 60)
        let current = try #require(notification.panel)
        #expect(!old.isVisible)
        #expect(current !== old)
        #expect(current.alphaValue == 0)
        for _ in 0..<100 {
            if current.alphaValue == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notification.panel === current)
        #expect(current.alphaValue == 1)
        notification.dismiss()
        #expect(notification.panel == nil)
        #expect(!current.isVisible)
    }
}
