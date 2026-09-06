import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private enum PanelMode { case normal, compact }

    private var panel: NSPanel?
    private var timer: TimerController?
    private var scrollTimeAdjuster: ScrollTimeAdjuster?
    private var normalFrame: NSRect?
    private var panelMode: PanelMode = .normal
    private var isModeTransitionInProgress = false
    private var intervalAlertCancellable: AnyCancellable?
    private var timerModeCancellable: AnyCancellable?
    private var returnToCompactTask: Task<Void, Never>?

    private let normalFrameKey = "Countdown.TimerPanel.NormalFrame"
    private let compactFrameKey = "Countdown.TimerPanel.CompactFrame"
    private let panelModeKey = "Countdown.TimerPanel.IsCompact"
    private let normalSize = NSSize(width: 188, height: 188)
    private let compactSize = NSSize(width: 32, height: 32)
    private let slideDuration: TimeInterval = 0.07
    private let resizeDuration: TimeInterval = 0.29
    private let slideProgress: CGFloat = 0.18

    /// How long the content cross-fade runs; it spans the whole window transition.
    private var contentFadeDuration: TimeInterval { slideDuration + resizeDuration }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let timer = TimerController()
        panelMode = UserDefaults.standard.bool(forKey: panelModeKey) ? .compact : .normal
        let initialSize = panelMode == .compact ? compactSize : normalSize
        let panel = makePanel(size: initialSize)
        panel.contentView = panelMode == .compact
            ? compactContentView(for: timer)
            : normalContentView(for: timer)
        panel.delegate = self
        restoreOrPosition(panel, for: panelMode, size: initialSize)
        normalFrame = restoredFrame(forKey: normalFrameKey, size: normalSize)
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.timer = timer
        observeWakeupIntervals(from: timer.countdown)
        timerModeCancellable = timer.$mode.dropFirst().sink { [weak self] _ in
            self?.returnToCompactTask?.cancel()
        }
        scrollTimeAdjuster = ScrollTimeAdjuster(timer: timer)
    }

    func applicationWillTerminate(_ notification: Notification) {
        returnToCompactTask?.cancel()
        timer?.save()
        savePanelState()
    }

    private func makePanel(size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: NSPoint(x: 100, y: 120), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = panelMode == .normal
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    @MainActor
    private func observeWakeupIntervals(from model: CountdownModel) {
        intervalAlertCancellable = model.$wakeupIntervalCount
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleWakeupInterval()
            }
    }

    private func handleWakeupInterval() {
        guard timer?.mode == .countdown, panelMode == .compact else { return }

        exitCompactMode()
        returnToCompactTask?.cancel()
        returnToCompactTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.enterCompactMode()
        }
    }

    private func normalContentView(for timer: TimerController) -> NSView {
        NSHostingView(rootView: TimerView(
            timer: timer,
            compact: { [weak self] in self?.enterCompactMode() }
        ))
    }

    private func compactContentView(for timer: TimerController) -> NSView {
        NSHostingView(rootView: CompactCountdownView(model: timer.countdown, expand: { [weak self] in
            self?.exitCompactMode()
        }))
    }

    private func restoreOrPosition(_ panel: NSPanel, for mode: PanelMode, size: NSSize) {
        let frameKey = mode == .compact ? compactFrameKey : normalFrameKey
        if let restoredFrame = restoredFrame(forKey: frameKey, size: size) {
            panel.setFrame(restoredFrame, display: false)
        } else {
            positionAtTopTrailingCorner(panel)
        }
    }

    private func restoredFrame(forKey key: String, size: NSSize) -> NSRect? {
        guard let frameString = UserDefaults.standard.string(forKey: key) else { return nil }
        let frame = NSRectFromString(frameString)
        let restoredFrame = NSRect(origin: frame.origin, size: size)
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(restoredFrame) }) else { return nil }
        return restoredFrame
    }

    private func positionAtTopTrailingCorner(_ panel: NSPanel) {
        guard let frame = topTrailingFrame(for: panel.frame.size) else { return }
        panel.setFrameOrigin(frame.origin)
    }

    private func topTrailingFrame(for size: NSSize) -> NSRect? {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return nil }
        let visibleFrame = screen.visibleFrame
        return NSRect(
            x: visibleFrame.maxX - size.width - 24,
            y: visibleFrame.maxY - size.height - 24,
            width: size.width,
            height: size.height
        )
    }

    private func savePanelState(frame: NSRect? = nil) {
        guard let panel else { return }
        let key = panelMode == .compact ? compactFrameKey : normalFrameKey
        UserDefaults.standard.set(NSStringFromRect(frame ?? panel.frame), forKey: key)
        UserDefaults.standard.set(panelMode == .compact, forKey: panelModeKey)
    }

    private func enterCompactMode() {
        guard timer?.mode == .countdown,
              panelMode == .normal,
              !isModeTransitionInProgress,
              let panel,
              let timer else { return }

        isModeTransitionInProgress = true
        normalFrame = panel.frame
        savePanelState(frame: normalFrame)
        panelMode = .compact
        panel.hasShadow = false
        let compactFrame = restoredFrame(forKey: compactFrameKey, size: compactSize)
            ?? topTrailingFrame(for: compactSize)
            ?? NSRect(origin: panel.frame.origin, size: compactSize)

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.contentView = compactContentView(for: timer)
            panel.setFrame(compactFrame, display: true)
            savePanelState(frame: compactFrame)
            isModeTransitionInProgress = false
            return
        }

        // Cross-fade the content while the panel shrinks and travels, so the
        // clock face and hands fade out with the circle instead of vanishing
        // the moment the transition starts.
        let incoming = crossFadeTo(compactContentView(for: timer), in: panel)

        let slideWaypoint = transitionWaypoint(from: compactFrame, to: panel.frame)
        animate(panel, to: slideWaypoint, duration: resizeDuration, timingFunction: .easeIn) { [weak self] in
            guard let self else { return }
            self.animate(
                panel,
                to: compactFrame,
                duration: self.slideDuration,
                timingFunction: .easeOut
            ) { [weak self] in
                guard let self else { return }
                self.replaceContent(of: panel, with: incoming)
                self.savePanelState(frame: compactFrame)
                self.isModeTransitionInProgress = false
            }
        }
    }

    private func exitCompactMode() {
        guard panelMode == .compact,
              !isModeTransitionInProgress,
              let panel,
              let timer else { return }

        isModeTransitionInProgress = true
        savePanelState()
        panelMode = .normal
        let fullFrame = normalFrame
            ?? restoredFrame(forKey: normalFrameKey, size: normalSize)
            ?? topTrailingFrame(for: normalSize)
            ?? NSRect(origin: panel.frame.origin, size: normalSize)

        let finishTransition = { [weak self] in
            guard let self else { return }
            panel.hasShadow = true
            self.savePanelState(frame: fullFrame)
            self.normalFrame = nil
            self.isModeTransitionInProgress = false
            panel.makeKeyAndOrderFront(nil)
        }

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.contentView = normalContentView(for: timer)
            panel.setFrame(fullFrame, display: true)
            finishTransition()
            return
        }

        // Cross-fade the content while the panel slides and grows, so the clock
        // face and hands fade in with the circle instead of popping in after it
        // lands. Keeping the panel square and compact-sized while it travels
        // still prevents the growing circle from being clipped into a square.
        let incoming = crossFadeTo(normalContentView(for: timer), in: panel)

        let slideWaypoint = transitionWaypoint(from: panel.frame, to: fullFrame)
        animate(panel, to: slideWaypoint, duration: slideDuration, timingFunction: .easeIn) { [weak self] in
            guard let self else { return }
            self.animate(
                panel,
                to: fullFrame,
                duration: self.resizeDuration,
                timingFunction: .easeOut
            ) { [weak self] in
                guard let self else { return }
                self.replaceContent(of: panel, with: incoming)
                finishTransition()
            }
        }
    }

    private func animate(
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
    private func crossFadeTo(_ incoming: NSView, in panel: NSPanel) -> NSView {
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
    private func replaceContent(of panel: NSPanel, with view: NSView) {
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

    private func transitionWaypoint(from compactFrame: NSRect, to normalFrame: NSRect) -> NSRect {
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
