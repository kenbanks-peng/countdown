import AppKit
import QuartzCore

/// Owns panel motion and content cross-fades, not window or countdown state.
@MainActor
struct CountdownPanelTransition {
    let duration: TimeInterval = 0.36

    func animate(
        _ panel: NSPanel,
        to frame: NSRect,
        anchor: NSPoint,
        completion: @escaping () -> Void
    ) {
        let start = panel.frame
        let startedAt = CACurrentMediaTime()
        // Set size and position together. Native window resize animation can
        // update the content size separately from its screen position.
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { timer in
            MainActor.assumeIsolated {
                let elapsed = min(1, (CACurrentMediaTime() - startedAt) / duration)
                let progress = CGFloat((1 - cos(.pi * elapsed)) / 2)
                panel.setFrame(self.frame(from: start, to: frame, anchor: anchor, progress: progress), display: true)
                if elapsed >= 1 {
                    timer.invalidate()
                    completion()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Stacks `incoming` over the panel's current content and fades between the
    /// two over the same span as the window transition. The returned view is the
    /// one to install as the panel's content once the transition finishes.
    func crossFadeTo(_ incoming: NSView, in panel: NSPanel) -> NSView {
        guard let outgoing = panel.contentView else {
            panel.contentView = incoming
            return incoming
        }

        let container = NSView(frame: outgoing.frame)
        outgoing.frame = container.bounds
        outgoing.autoresizingMask = [.width, .height]
        incoming.frame = container.bounds
        incoming.autoresizingMask = [.width, .height]
        incoming.alphaValue = 0
        container.addSubview(outgoing)
        container.addSubview(incoming)
        panel.contentView = container

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            outgoing.animator().alphaValue = 0
            incoming.animator().alphaValue = 1
        }

        return incoming
    }

    /// Removes the transition container and installs the faded-in view as the
    /// panel's content.
    func replaceContent(of panel: NSPanel, with view: NSView) {
        view.removeFromSuperview()
        view.frame = panel.contentView?.frame ?? panel.frame
        panel.contentView = view
    }

    /// Project the compact position onto the canvas edge. AppKit coordinates
    /// start at the bottom left, so top middle is (0.5, 1).
    func scaleAnchor(compactFrame: NSRect, screenFrame: NSRect) -> NSPoint {
        guard screenFrame.width > 0, screenFrame.height > 0 else {
            return NSPoint(x: 0.5, y: 0.5)
        }
        let x = (compactFrame.midX - screenFrame.midX) / screenFrame.width
        let y = (compactFrame.midY - screenFrame.midY) / screenFrame.height
        let distance = max(abs(x), abs(y))
        guard distance > 0 else { return NSPoint(x: 0.5, y: 0.5) }
        return NSPoint(x: 0.5 + x / distance / 2, y: 0.5 + y / distance / 2)
    }

    /// Move the same normalized anchor between endpoints while scaling the
    /// canvas around it. One progress value controls both motion and size.
    func frame(from start: NSRect, to end: NSRect, anchor: NSPoint, progress: CGFloat) -> NSRect {
        let progress = min(1, max(0, progress))
        if progress == 0 { return start }
        if progress == 1 { return end }
        func interpolate(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        let width = interpolate(start.width, end.width)
        let height = interpolate(start.height, end.height)
        let x = interpolate(start.minX + start.width * anchor.x, end.minX + end.width * anchor.x)
        let y = interpolate(start.minY + start.height * anchor.y, end.minY + end.height * anchor.y)
        return NSRect(x: x - width * anchor.x, y: y - height * anchor.y, width: width, height: height)
    }
}
