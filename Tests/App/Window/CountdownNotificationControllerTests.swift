import AppKit
import Testing
@testable import Countdown

@MainActor
struct CountdownNotificationControllerTests {
    @Test
    func entranceScaleKeepsContentCenterFixed() {
        let size = NSSize(width: 400, height: 180)
        let transform = CountdownNotificationController.entranceTransform(size: size, scale: 0.9)
        #expect(transform.m11 == 0.9)
        #expect(transform.m22 == 0.9)
        #expect(abs(size.width / 2 * transform.m11 + transform.m41 - size.width / 2) < 0.001)
        #expect(abs(size.height / 2 * transform.m22 + transform.m42 - size.height / 2) < 0.001)
    }

    @Test(arguments: [false, true], [0.0, 0.2])
    func entranceRespectsMotionPreferenceAndSettlesAtFullSize(reduceMotion: Bool,
                                                             fadeDuration: Double) async throws {
        let notification = CountdownNotificationController(fadeDuration: fadeDuration,
                                                          reduceMotion: { reduceMotion })
        defer { notification.dismiss() }
        notification.show(content: NSView(), screenFrame: NSRect(x: 0, y: 0, width: 800, height: 600),
                          size: NSSize(width: 400, height: 180), duration: 60, peakAlpha: 0.4)
        let panel = try #require(notification.panel)
        let layer = try #require(panel.contentView?.layer)
        let scalesIn = !reduceMotion && fadeDuration > 0
        #expect(layer.sublayerTransform.m11 == (scalesIn ? 0.9 : 1))
        #expect(panel.alphaValue == 0)
        let frame = panel.frame
        // The full suite can hold the main actor longer than the animation.
        // Check the settled state, not a transient frame.
        for _ in 0..<100 {
            if abs(panel.alphaValue - 0.4) < 0.001 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        try await Task.sleep(for: .milliseconds(300))
        #expect(CATransform3DIsIdentity(layer.sublayerTransform))
        #expect(layer.animation(forKey: "notificationEntrance") == nil)
        #expect(panel.frame == frame)
        #expect(abs(panel.alphaValue - 0.4) < 0.001)
        notification.dismiss()
        #expect(!panel.isVisible)
    }

    @Test
    func dismissalRemovesEntranceAnimation() throws {
        let notification = CountdownNotificationController(fadeDuration: 1, reduceMotion: { false })
        defer { notification.dismiss() }
        notification.show(content: NSView(), screenFrame: NSRect(x: 0, y: 0, width: 800, height: 600),
                          size: NSSize(width: 188, height: 188), duration: 60)
        let panel = try #require(notification.panel)
        let layer = try #require(panel.contentView?.layer)
        // Submit directly so the checks do not depend on main-actor scheduling.
        CountdownNotificationController.animateEntrance(layer, duration: 1)
        let animation = try #require(layer.animation(forKey: "notificationEntrance") as? CABasicAnimation)
        let start = try #require(animation.fromValue as? CATransform3D)
        let end = try #require(animation.toValue as? CATransform3D)
        #expect(start.m11 == 0.9)
        #expect(CATransform3DIsIdentity(end))
        #expect(animation.duration == 1)
        #expect(animation.timingFunction == CAMediaTimingFunction(name: .easeOut))
        #expect(CATransform3DIsIdentity(layer.sublayerTransform))
        notification.dismiss()
        #expect(layer.animation(forKey: "notificationEntrance") == nil)
        #expect(!panel.isVisible)
    }

    @Test
    func fadeCurvesMapToAnimationTimingFunctions() {
        #expect(CountdownNotificationController.timingFunctionName(for: .linear) == .linear)
        #expect(CountdownNotificationController.timingFunctionName(for: .easeIn) == .easeIn)
        #expect(CountdownNotificationController.timingFunctionName(for: .easeOut) == .easeOut)
        #expect(CountdownNotificationController.timingFunctionName(for: .easeInOut) == .easeInEaseOut)
    }

    @Test(arguments: NotificationFadeCurve.allCases)
    func zeroHoldNotificationCompletesWithEachCurve(curve: NotificationFadeCurve) async throws {
        let notification = CountdownNotificationController(fadeDuration: 0.02)
        defer { notification.dismiss() }
        notification.show(content: NSView(), screenFrame: NSRect(x: 0, y: 0, width: 800, height: 600),
                          size: NSSize(width: 188, height: 188), duration: 0, fadeIn: curve, fadeOut: curve)
        let panel = try #require(notification.panel)
        for _ in 0..<100 {
            if notification.panel == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notification.panel == nil)
        #expect(!panel.isVisible)
        #expect(panel.alphaValue == 0)
    }

    @Test(arguments: [0.0, 0.4, 1.0])
    func notificationStartsInvisibleAtScreenCenterAndNeverMoves(peakAlpha: Double) async throws {
        let notification = CountdownNotificationController(fadeDuration: 0.02)
        defer { notification.dismiss() }
        let screen = NSRect(x: -1_920, y: 200, width: 1_920, height: 1_080)
        notification.show(content: NSView(), screenFrame: screen,
                   size: NSSize(width: 188, height: 188), duration: 0.15, peakAlpha: peakAlpha)
        let panel = try #require(notification.panel)
        let frame = panel.frame
        #expect(frame.midX == screen.midX)
        #expect(frame.midY == screen.midY)
        #expect(panel.alphaValue == 0)
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.isMovable)
        #expect(!panel.isKeyWindow)
        #expect(!panel.hasShadow)
        for _ in 0..<100 {
            #expect(panel.frame == frame)
            if notification.panel == nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notification.panel == nil)
        #expect(!panel.isVisible)
        #expect(panel.alphaValue == 0)
    }

    @Test(arguments: [0.0, 0.4, 1.0], [0.0, 0.02])
    func notificationHoldsConfiguredPeakAlpha(peakAlpha: Double, fadeDuration: Double) async throws {
        let notification = CountdownNotificationController(fadeDuration: fadeDuration)
        defer { notification.dismiss() }
        notification.show(content: NSView(), screenFrame: NSRect(x: 0, y: 0, width: 800, height: 600),
                          size: NSSize(width: 188, height: 188), duration: 60, peakAlpha: peakAlpha)
        let panel = try #require(notification.panel)
        #expect(panel.alphaValue == 0)
        // Let the fade run, including when the requested peak is zero.
        try await Task.sleep(for: .milliseconds(100))
        for _ in 0..<100 {
            if abs(panel.alphaValue - CGFloat(peakAlpha)) < 0.001 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notification.panel === panel)
        #expect(abs(panel.alphaValue - CGFloat(peakAlpha)) < 0.001)
    }

    @Test
    func newNotificationCancelsOldDismissalAndDismissHidesPanel() async throws {
        let notification = CountdownNotificationController(fadeDuration: 0.01)
        defer { notification.dismiss() }
        let screen = NSRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let size = NSSize(width: 188, height: 188)
        notification.show(content: NSView(), screenFrame: screen, size: size, duration: 0.01)
        let old = try #require(notification.panel)
        notification.show(content: NSView(), screenFrame: screen, size: size, duration: 60)
        let current = try #require(notification.panel)
        #expect(!old.isVisible)
        #expect(current !== old)
        #expect(current.alphaValue == 0)
        for _ in 0..<100 {
            if current.alphaValue == 1 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(notification.panel === current)
        #expect(current.alphaValue == 1)
        notification.dismiss()
        #expect(notification.panel == nil)
        #expect(!current.isVisible)
    }
}
