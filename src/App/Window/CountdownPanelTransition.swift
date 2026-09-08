import AppKit
import QuartzCore

/// Owns panel motion and content cross-fades, not window or countdown state.
@MainActor
struct CountdownPanelTransition {
    let slideDuration: TimeInterval = 0.07
    let resizeDuration: TimeInterval = 0.29
    private let slideProgress: CGFloat = 0.18
    private let compactSize = NSSize(width: CountdownAppearance.compactSize, height: CountdownAppearance.compactSize)
    private var contentFadeDuration: TimeInterval { slideDuration + resizeDuration }

    func animate(
        _ panel: NSPanel,
        to frame: NSRect,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunctionName,
        completion: @escaping () -> Void
    ) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: timingFunction)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: {
            completion()
        }
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
            context.duration = contentFadeDuration
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

    private func frame(size: NSSize, centeredAt center: NSPoint) -> NSRect {
        NSRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    func waypoint(from compactFrame: NSRect, to normalFrame: NSRect) -> NSRect {
        let compactCenter = compactFrame.center
        let normalCenter = normalFrame.center
        let waypointCenter = NSPoint(
            x: compactCenter.x + (normalCenter.x - compactCenter.x) * slideProgress,
            y: compactCenter.y + (normalCenter.y - compactCenter.y) * slideProgress
        )
        return frame(size: compactSize, centeredAt: waypointCenter)
    }
}

private extension NSRect {
    var center: NSPoint {
        NSPoint(x: midX, y: midY)
    }
}
