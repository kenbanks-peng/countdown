import AppKit
import SwiftUI

/// A separate, stationary notification. It never changes the countdown window.
@MainActor
final class CountdownNotificationController {
    private(set) var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?
    private let fadeDuration: TimeInterval
    private let reduceMotion: () -> Bool

    init(fadeDuration: TimeInterval = 1.5,
         reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.fadeDuration = fadeDuration
        self.reduceMotion = reduceMotion
    }

    func show(content: NSView, screenFrame: NSRect, size: NSSize, duration: TimeInterval,
              fadeDuration: TimeInterval? = nil, peakAlpha: Double = 1,
              fadeIn: NotificationFadeCurve = .easeIn, fadeOut: NotificationFadeCurve = .easeOut) {
        dismiss()
        let fadeDuration = fadeDuration ?? self.fadeDuration
        let scales = !reduceMotion() && fadeDuration > 0
        // Reserve transparent space so the outward scale is not clipped by the panel.
        let panelSize = scales ? NSSize(width: size.width * 3, height: size.height * 3) : size
        let frame = NSRect(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.midY - panelSize.height / 2,
            width: panelSize.width, height: panelSize.height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Scale a separate container, not the hosted view or the panel frame.
        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        container.wantsLayer = true
        content.frame = NSRect(x: (panelSize.width - size.width) / 2,
                               y: (panelSize.height - size.height) / 2,
                               width: size.width, height: size.height)
        content.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        container.addSubview(content)
        panel.contentView = container
        container.layer?.sublayerTransform = Self.scaleTransform(size: panelSize, scale: scales ? 0.9 : 1)
        // Set both position and zero visibility before the panel enters the screen.
        panel.alphaValue = 0
        self.panel = panel
        panel.orderFrontRegardless()

        dismissalTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            if scales, let layer = container.layer {
                Self.animateScale(layer, to: CATransform3DIdentity, duration: fadeDuration,
                                  curve: .easeOut)
            }
            await Self.fade(panel, to: CGFloat(peakAlpha), duration: fadeDuration, curve: fadeIn)
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if scales, let layer = container.layer {
                Self.animateScale(layer, to: Self.scaleTransform(size: panelSize, scale: 3),
                                  duration: fadeDuration, curve: .easeIn)
            }
            await Self.fade(panel, to: 0, duration: fadeDuration, curve: fadeOut)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel?.contentView?.layer?.removeAllAnimations()
        panel = nil
    }

    static func animateScale(_ layer: CALayer, to transform: CATransform3D,
                             duration: TimeInterval, curve: CAMediaTimingFunctionName) {
        let animation = CABasicAnimation(keyPath: "sublayerTransform")
        animation.fromValue = layer.sublayerTransform
        animation.toValue = transform
        animation.duration = duration
        // Scale timing is independent of the configured opacity curve.
        animation.timingFunction = CAMediaTimingFunction(name: curve)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayerTransform = transform
        layer.add(animation, forKey: "notificationScale")
        CATransaction.commit()
    }

    static func scaleTransform(size: NSSize, scale: CGFloat) -> CATransform3D {
        // Keep the visual center fixed throughout both scale effects.
        var transform = CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        return CATransform3DTranslate(transform, -size.width / 2, -size.height / 2, 0)
    }

    static func timingFunctionName(for curve: NotificationFadeCurve) -> CAMediaTimingFunctionName {
        switch curve {
        case .linear: .linear
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInEaseOut
        }
    }

    private static func fade(_ panel: NSPanel, to opacity: CGFloat, duration: TimeInterval,
                             curve: NotificationFadeCurve) async {
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: timingFunctionName(for: curve))
                panel.animator().alphaValue = opacity
            } completionHandler: {
                continuation.resume()
            }
        }
    }
}
