import AppKit
import Combine
import SwiftUI

@MainActor
final class CountdownWindowController {
    private typealias Presentation = CountdownWindowStateStore.Presentation

    private let panel: CountdownPanel
    private let countdown: CountdownController
    private var scrollTimeAdjuster: ScrollTimeAdjuster?
    private var normalFrame: NSRect?
    private var presentation: Presentation = .normal
    private var isTransitioning = false
    private var notificationSubscription: AnyCancellable?
    private var testNotificationSubscription: AnyCancellable?
    private let notification: CountdownNotificationController

    private let windowState = CountdownWindowStateStore()
    private let transition = CountdownPanelTransition()
    private let configuration: CountdownConfiguration
    private let normalSize: NSSize
    private let compactSize: NSSize

    init(countdown: CountdownController, configuration: CountdownConfiguration = .default) {
        self.countdown = countdown
        self.configuration = configuration
        notification = CountdownNotificationController(fadeDuration: configuration.notificationFadeTimeSeconds)
        let normalSide = CountdownAppearance.normalSize * configuration.size
        let compactSide = CountdownAppearance.compactSize * configuration.compactSize
        normalSize = NSSize(width: normalSide, height: normalSide)
        compactSize = NSSize(width: compactSide, height: compactSide)
        presentation = windowState.presentation
        let initialSize = presentation == .compact ? compactSize : normalSize
        panel = Self.makePanel(size: initialSize, hasShadow: presentation == .normal)
        panel.contentView = contentView(isCompact: presentation == .compact)
        restoreOrPosition(panel, for: presentation, size: initialSize)
        normalFrame = windowState.restoredFrame(for: .normal, size: normalSize)
        panel.makeKeyAndOrderFront(nil)

        observeNotificationIntervals(from: countdown.notifications)
        testNotificationSubscription = countdown.testNotificationRequested.sink { [weak self] configuration in
            self?.showNotification(configuration: configuration)
        }
        scrollTimeAdjuster = ScrollTimeAdjuster(countdown: countdown, window: panel, normalScale: configuration.size, isCompact: { [weak self] in
            self?.presentation == .compact
        })
    }

    func save() {
        notification.dismiss()
        countdown.save()
        savePanelState()
    }

    private static func makePanel(size: NSSize, hasShadow: Bool) -> CountdownPanel {
        let panel = CountdownPanel(
            contentRect: NSRect(origin: NSPoint(x: 100, y: 120), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = hasShadow
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func observeNotificationIntervals(from model: NotificationScheduler) {
        notificationSubscription = model.$notificationIntervalCount
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleNotificationInterval()
            }
    }

    private func handleNotificationInterval() {
        guard presentation == .compact else { return }
        showNotification(configuration: configuration)
    }

    private func showNotification(configuration: CountdownConfiguration) {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        notification.show(
            content: NSHostingView(rootView: CountdownView(
                countdown: countdown, isNotification: true, notificationFontSizePt: configuration.notificationFontSizePt,
                notificationFont: configuration.notificationFont,
                notificationFontVariations: configuration.notificationFontVariations, changePresentation: {}
            )),
            screenFrame: screen.frame, size: screen.frame.size,
            duration: TimeInterval(configuration.notificationTimeSeconds),
            fadeDuration: configuration.notificationFadeTimeSeconds,
            peakAlpha: configuration.notificationFontAlpha,
            fadeIn: configuration.notificationFadeIn,
            fadeOut: configuration.notificationFadeOut
        )
    }

    private func contentView(isCompact: Bool) -> NSView {
        NSHostingView(rootView: CountdownView(
            countdown: countdown, isCompact: isCompact,
            scale: isCompact ? configuration.compactSize : configuration.size,
            allowsClick: { [weak self] in self?.panel.allowsClick ?? true },
            changePresentation: { [weak self] in
                if isCompact { self?.showNormalWindow() } else { self?.showCompactWindow() }
            }
        ))
    }

    private func restoreOrPosition(_ panel: NSPanel, for mode: Presentation, size: NSSize) {
        if let frame = windowState.restoredFrame(for: mode, size: size)
            ?? windowState.topTrailingFrame(for: size) {
            panel.setFrame(frame, display: false)
        }
    }

    private func savePanelState(frame: NSRect? = nil) {
        windowState.save(frame: frame ?? panel.frame, presentation: presentation)
    }

    private func scaleAnchor(for compactFrame: NSRect) -> NSPoint {
        let center = NSPoint(x: compactFrame.midX, y: compactFrame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.frame.intersects(compactFrame) }
            ?? panel.screen ?? NSScreen.main
        return transition.scaleAnchor(compactFrame: compactFrame, screenFrame: screen?.frame ?? .zero)
    }

    private func showCompactWindow() {
        guard presentation == .normal, !isTransitioning else { return }
        let panel = panel

        isTransitioning = true
        normalFrame = panel.frame
        savePanelState(frame: normalFrame)
        presentation = .compact
        panel.hasShadow = false
        let compactFrame = windowState.restoredFrame(for: .compact, size: compactSize)
            ?? windowState.topTrailingFrame(for: compactSize)
            ?? NSRect(origin: panel.frame.origin, size: compactSize)

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.contentView = contentView(isCompact: true)
            panel.setFrame(compactFrame, display: true)
            savePanelState(frame: compactFrame)
            isTransitioning = false
            return
        }

        // Cross-fade the content while the panel shrinks and travels, so the
        // clock face and hands fade out with the circle instead of vanishing
        // the moment the transition starts.
        let incoming = transition.crossFadeTo(contentView(isCompact: true), in: panel)

        transition.animate(panel, to: compactFrame, anchor: scaleAnchor(for: compactFrame)) { [weak self] in
            guard let self else { return }
            self.transition.replaceContent(of: panel, with: incoming)
            self.savePanelState(frame: compactFrame)
            self.isTransitioning = false
        }
    }

    private func showNormalWindow() {
        guard presentation == .compact, !isTransitioning else { return }
        let panel = panel

        notification.dismiss()
        isTransitioning = true
        savePanelState()
        presentation = .normal
        let fullFrame = normalFrame
            ?? windowState.restoredFrame(for: .normal, size: normalSize)
            ?? windowState.topTrailingFrame(for: normalSize)
            ?? NSRect(origin: panel.frame.origin, size: normalSize)

        let finishTransition = { [weak self] in
            guard let self else { return }
            panel.hasShadow = true
            self.savePanelState(frame: fullFrame)
            self.normalFrame = nil
            self.isTransitioning = false
            panel.makeKeyAndOrderFront(nil)
        }

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.contentView = contentView(isCompact: false)
            panel.setFrame(fullFrame, display: true)
            finishTransition()
            return
        }

        // Cross-fade while moving and growing around the compact position's
        // canvas-edge anchor. The reverse transition uses the same anchor.
        let incoming = transition.crossFadeTo(contentView(isCompact: false), in: panel)

        transition.animate(panel, to: fullFrame, anchor: scaleAnchor(for: panel.frame)) { [weak self] in
            guard let self else { return }
            self.transition.replaceContent(of: panel, with: incoming)
            finishTransition()
        }
    }

}
