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
    func transitionUsesDisplayPositionForTheCanvasEdgeAnchor() {
        let transition = CountdownPanelTransition()
        // Include a non-square display with an offset global origin.
        for screen in [NSRect(x: 0, y: 0, width: 1_000, height: 1_000),
                       NSRect(x: -1_600, y: 400, width: 1_600, height: 900)] {
            for anchor in [NSPoint(x: 0, y: 0), NSPoint(x: 0.5, y: 0), NSPoint(x: 1, y: 0),
                           NSPoint(x: 0, y: 0.5), NSPoint(x: 1, y: 0.5),
                           NSPoint(x: 0, y: 1), NSPoint(x: 0.5, y: 1), NSPoint(x: 1, y: 1)] {
                let compact = NSRect(
                    x: screen.minX + (0.1 + anchor.x * 0.8) * screen.width - 16,
                    y: screen.minY + (0.1 + anchor.y * 0.8) * screen.height - 16,
                    width: 32, height: 32
                )
                let actual = transition.scaleAnchor(compactFrame: compact, screenFrame: screen)
                #expect(abs(actual.x - anchor.x) < 1e-9)
                #expect(abs(actual.y - anchor.y) < 1e-9)
            }
        }
        let centered = NSRect(x: 484, y: 484, width: 32, height: 32)
        #expect(transition.scaleAnchor(compactFrame: centered,
                                      screenFrame: NSRect(x: 0, y: 0, width: 1_000, height: 1_000))
            == NSPoint(x: 0.5, y: 0.5))
        #expect(transition.scaleAnchor(compactFrame: centered, screenFrame: .zero)
            == NSPoint(x: 0.5, y: 0.5))
    }

    @Test
    func transitionSlidesAndScalesTogetherWithoutCrossingDisplayEdges() {
        let transition = CountdownPanelTransition()
        let screen = NSRect(x: -1_000, y: 200, width: 1_000, height: 800)
        let normal = NSRect(x: -700, y: 450, width: 188, height: 188)
        for x in [screen.minX, screen.midX - 16, screen.maxX - 32] {
            for y in [screen.minY, screen.midY - 16, screen.maxY - 32] {
                let compact = NSRect(x: x, y: y, width: 32, height: 32)
                let anchor = transition.scaleAnchor(compactFrame: compact, screenFrame: screen)
                #expect(transition.frame(from: compact, to: normal, anchor: anchor, progress: 0) == compact)
                #expect(transition.frame(from: compact, to: normal, anchor: anchor, progress: 1) == normal)
                for step in 1..<100 {
                    let progress = CGFloat(step) / 100
                    let frame = transition.frame(from: compact, to: normal, anchor: anchor, progress: progress)
                    let reverse = transition.frame(from: normal, to: compact, anchor: anchor, progress: 1 - progress)
                    #expect(frame.width > compact.width && frame.width < normal.width)
                    #expect(frame.width == frame.height)
                    #expect(screen.contains(frame))
                    #expect(abs(frame.minX - reverse.minX) < 1e-9)
                    #expect(abs(frame.minY - reverse.minY) < 1e-9)
                    #expect(abs(frame.width - reverse.width) < 1e-9)
                    let expectedX = compact.minX + compact.width * anchor.x
                        + ((normal.minX + normal.width * anchor.x)
                            - (compact.minX + compact.width * anchor.x)) * progress
                    #expect(abs(frame.minX + frame.width * anchor.x - expectedX) < 1e-9)
                }
            }
        }
        #expect(transition.duration == 0.36)
    }

    @Test
    func animationFinishesAtTheExactDestination() async throws {
        let compact = NSRect(x: 100, y: 200, width: 32, height: 32)
        let normal = NSRect(x: 400, y: 500, width: 188, height: 188)
        let panel = NSPanel(contentRect: compact, styleMask: .borderless, backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }
        let transition = CountdownPanelTransition()
        for destination in [normal, compact] {
            var completions = 0
            transition.animate(panel, to: destination, anchor: NSPoint(x: 0.5, y: 1)) {
                completions += 1
            }
            for _ in 0..<100 {
                if completions > 0 { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(completions == 1)
            #expect(panel.frame == destination)
        }
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
