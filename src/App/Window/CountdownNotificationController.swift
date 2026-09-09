import AppKit
import SwiftUI

/// A separate, stationary notification. It never changes the countdown window.
@MainActor
final class CountdownNotificationController {
    private(set) var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?
    private let fadeDuration: TimeInterval

    init(fadeDuration: TimeInterval = 1.5) {
        self.fadeDuration = fadeDuration
    }

    func show(content: NSView, screenFrame: NSRect, size: NSSize, duration: TimeInterval,
              fadeDuration: TimeInterval? = nil, peakAlpha: Double = 1) {
        dismiss()
        let frame = NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width, height: size.height
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
        panel.contentView = content
        // Set both position and zero visibility before the panel enters the screen.
        panel.alphaValue = 0
        self.panel = panel
        panel.orderFrontRegardless()

        let fadeDuration = fadeDuration ?? self.fadeDuration
        dismissalTask = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            await Self.fade(panel, to: CGFloat(peakAlpha), duration: fadeDuration)
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await Self.fade(panel, to: 0, duration: fadeDuration)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissalTask?.cancel()
        dismissalTask = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private static func fade(_ panel: NSPanel, to opacity: CGFloat, duration: TimeInterval) async {
        await withCheckedContinuation { continuation in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                panel.animator().alphaValue = opacity
            } completionHandler: {
                continuation.resume()
            }
        }
    }
}
