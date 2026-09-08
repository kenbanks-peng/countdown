import AppKit
import Testing
@testable import Countdown

@MainActor
struct CountdownWindowStateTests {
    @Test
    func presentationsKeepSeparateOriginsAndUseCurrentSizes() throws {
        let suite = "countdown.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CountdownWindowStateStore(defaults: defaults)
        let screen = NSRect(x: 0, y: 0, width: 1_000, height: 1_000)
        #expect(store.presentation == .normal)
        #expect(store.restoredFrame(for: .normal, size: .zero, visibleFrames: [screen]) == nil)
        store.save(frame: NSRect(x: 100, y: 200, width: 188, height: 188), presentation: .normal)
        store.save(frame: NSRect(x: 500, y: 600, width: 32, height: 32), presentation: .compact)
        #expect(store.presentation == .compact)
        let size = NSSize(width: 64, height: 64)
        #expect(store.restoredFrame(for: .normal, size: size, visibleFrames: [screen])
            == NSRect(x: 100, y: 200, width: 64, height: 64))
        #expect(store.restoredFrame(for: .compact, size: size, visibleFrames: [screen])
            == NSRect(x: 500, y: 600, width: 64, height: 64))
        #expect(defaults.bool(forKey: "Countdown.TimerPanel.IsCompact"))
        #expect(defaults.string(forKey: "Countdown.TimerPanel.NormalFrame") != nil)
        #expect(defaults.string(forKey: "Countdown.TimerPanel.CompactFrame") != nil)
        #expect(store.restoredFrame(for: .normal, size: size, visibleFrames: []) == nil)
        #expect(store.restoredFrame(for: .normal, size: size,
                                   visibleFrames: [NSRect(x: -1_000, y: 0, width: 500, height: 500)]) == nil)
    }

    @Test
    func transitionWaypointKeepsTheCompactSizeAndExistingMotion() {
        let transition = CountdownPanelTransition()
        let compact = NSRect(x: 100, y: 200, width: 32, height: 32)
        let normal = NSRect(x: 400, y: 500, width: 188, height: 188)
        let waypoint = transition.waypoint(from: compact, to: normal)
        #expect(waypoint.size == compact.size)
        #expect(abs(waypoint.midX - (compact.midX + (normal.midX - compact.midX) * 0.18)) < 1e-9)
        #expect(abs(waypoint.midY - (compact.midY + (normal.midY - compact.midY) * 0.18)) < 1e-9)
        #expect(transition.slideDuration == 0.07)
        #expect(transition.resizeDuration == 0.29)
    }

    @Test
    func replacingTransitionContentRemovesTheTemporaryContainer() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 188, height: 188),
                            styleMask: .borderless, backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }
        let container = NSView(frame: panel.frame)
        let content = NSView(frame: .zero)
        container.addSubview(content)
        panel.contentView = container
        CountdownPanelTransition().replaceContent(of: panel, with: content)
        #expect(panel.contentView === content)
        #expect(container.subviews.isEmpty)
        #expect(content.frame.size == NSSize(width: 188, height: 188))
    }
}
