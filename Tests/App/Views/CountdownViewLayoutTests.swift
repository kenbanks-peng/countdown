import SwiftUI
import Testing
@testable import Countdown

@MainActor
struct CountdownViewLayoutTests {
    @Test(arguments: CountdownMode.allCases, [0.8, 1.0, 1.5])
    func normalViewRemainsSquareAtIntermediateTransitionSizes(mode: CountdownMode, scale: Double) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateStore = TimerSessionStore(environment: [
            "XDG_STATE_HOME": directory.path
        ])
        let configuration = CountdownConfiguration(alarmNotificationURL: nil)
        let timer = CountdownController(
            sessionStore: stateStore,
            configuration: configuration,
            playSound: { _ in }
        )
        timer.selectMode(mode)
        for isCompact in [false, true] {
            let hostingView = NSHostingView(rootView: CountdownView(countdown: timer, isCompact: isCompact, scale: scale, changePresentation: {}))
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = NSColor.clear.cgColor

            for baseSide in stride(from: 32.0, through: 188.0, by: 13.0) {
                let side = baseSide * scale
                hostingView.frame = NSRect(x: 0, y: 0, width: side, height: side)
                hostingView.layoutSubtreeIfNeeded()
                guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
                    Issue.record("Could not render at side \(side)")
                    continue
                }
                bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
                hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
                let maxX = bitmap.pixelsWide - 1
                let maxY = bitmap.pixelsHigh - 1
                for (x, y) in [(1, 1), (maxX - 1, 1), (1, maxY - 1), (maxX - 1, maxY - 1)] {
                    #expect((bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1) < 0.05, "Transparent corner at side \(side)")
                }
                #expect((bitmap.colorAt(x: maxX / 2, y: maxY / 2)?.alphaComponent ?? 0) > 0.5)
                let inset = max(1, Int(8 * scale * CGFloat(bitmap.pixelsWide) / side))
                for (x, y) in [(maxX / 2, inset), (maxX / 2, maxY - inset), (inset, maxY / 2), (maxX - inset, maxY / 2)] {
                    #expect((bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5)
                }
            }
        }
    }

    @Test
    func transitionUsesScaledCompactFrame() {
        let compact = NSRect(x: 10, y: 20, width: 25.6, height: 25.6)
        let normal = NSRect(x: 200, y: 300, width: 282, height: 282)
        let waypoint = CountdownPanelTransition().waypoint(from: compact, to: normal)
        #expect(waypoint.size == compact.size)
        #expect(abs(waypoint.midX - (compact.midX + (normal.midX - compact.midX) * 0.18)) < 1e-9)
        #expect(abs(waypoint.midY - (compact.midY + (normal.midY - compact.midY) * 0.18)) < 1e-9)
    }
}
