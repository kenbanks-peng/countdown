import AppKit
import Testing
@testable import Countdown

@MainActor
struct CountdownReminderControllerTests {
    @Test
    func reminderStartsInvisibleAtScreenCenterAndNeverMoves() async throws {
        let reminder = CountdownReminderController(fadeDuration: 0.02)
        defer { reminder.dismiss() }
        let screen = NSRect(x: -1_920, y: 200, width: 1_920, height: 1_080)
        reminder.show(content: NSView(), screenFrame: screen,
                   size: NSSize(width: 188, height: 188), duration: 0.15)
        let panel = try #require(reminder.panel)
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
            if reminder.panel == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(reminder.panel == nil)
        #expect(!panel.isVisible)
        #expect(panel.alphaValue == 0)
    }

    @Test
    func newReminderCancelsOldDismissalAndDismissHidesPanel() async throws {
        let reminder = CountdownReminderController(fadeDuration: 0.01)
        defer { reminder.dismiss() }
        let screen = NSRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let size = NSSize(width: 188, height: 188)
        reminder.show(content: NSView(), screenFrame: screen, size: size, duration: 0.01)
        let old = try #require(reminder.panel)
        reminder.show(content: NSView(), screenFrame: screen, size: size, duration: 60)
        let current = try #require(reminder.panel)
        #expect(!old.isVisible)
        #expect(current !== old)
        #expect(current.alphaValue == 0)
        for _ in 0..<100 {
            if current.alphaValue == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(reminder.panel === current)
        #expect(current.alphaValue == 1)
        reminder.dismiss()
        #expect(reminder.panel == nil)
        #expect(!current.isVisible)
    }
}
