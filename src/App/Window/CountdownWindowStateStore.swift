import AppKit

/// Window placement is separate from timer sessions and menu preferences.
struct CountdownWindowStateStore {
    enum Presentation { case normal, compact }

    var defaults: UserDefaults = .standard
    private let normalFrameKey = "Countdown.TimerPanel.NormalFrame"
    private let compactFrameKey = "Countdown.TimerPanel.CompactFrame"
    private let presentationKey = "Countdown.TimerPanel.IsCompact"

    var presentation: Presentation {
        defaults.bool(forKey: presentationKey) ? .compact : .normal
    }

    func restoredFrame(for presentation: Presentation, size: NSSize,
                       visibleFrames: [NSRect] = NSScreen.screens.map(\.visibleFrame)) -> NSRect? {
        guard let savedFrame = defaults.string(forKey: frameKey(for: presentation)) else { return nil }
        let frame = NSRect(origin: NSRectFromString(savedFrame).origin, size: size)
        return visibleFrames.contains(where: { $0.intersects(frame) }) ? frame : nil
    }

    func topTrailingFrame(for size: NSSize) -> NSRect? {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        let visibleFrame = screen.visibleFrame
        return NSRect(x: visibleFrame.maxX - size.width - 24,
                      y: visibleFrame.maxY - size.height - 24,
                      width: size.width, height: size.height)
    }

    func save(frame: NSRect, presentation: Presentation) {
        defaults.set(NSStringFromRect(frame), forKey: frameKey(for: presentation))
        defaults.set(presentation == .compact, forKey: presentationKey)
    }

    private func frameKey(for presentation: Presentation) -> String {
        presentation == .compact ? compactFrameKey : normalFrameKey
    }
}
