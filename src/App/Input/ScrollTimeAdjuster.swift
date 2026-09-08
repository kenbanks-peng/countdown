import AppKit
import Combine

@MainActor
final class ScrollTimeAdjuster {
    private enum Target: Equatable {
        case timer
        case pomodoro(PomodoroModel.Phase)
    }

    private weak var countdown: CountdownController?
    private weak var window: NSWindow?
    private let normalScale: CGFloat
    private let isCompact: () -> Bool
    private let uptime: () -> TimeInterval
    private var previousTarget: Target?
    private var monitor: Any?
    private var modeSubscription: AnyCancellable?
    private var lastEventAt: TimeInterval?
    private var gesturePoint: NSPoint?
    private var lastDirection = 0
    private var accumulatedDistance = 0.0
    private var wasPreciseScrolling: Bool?
    private var wasOptionPressed: Bool?
    private let preciseStepDistance = 12.0
    private let gestureTimeout: TimeInterval = 0.35

    init(countdown: CountdownController, window: NSWindow? = nil, normalScale: CGFloat = 1, isCompact: @escaping () -> Bool = { false },
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.countdown = countdown
        self.window = window
        self.normalScale = normalScale
        self.isCompact = isCompact
        self.uptime = uptime
        modeSubscription = countdown.$mode.sink { [weak self] _ in
            self?.resetGesture()
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return event
        }
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func handle(_ event: NSEvent) {
        guard let countdown else { return }
        // Inertial scrolling must not keep changing a setting after the fingers stop.
        guard event.momentumPhase.isEmpty else {
            resetGesture()
            return
        }
        if let window, let eventWindow = event.window, eventWindow !== window {
            resetGesture()
            return
        }
        let now = uptime()
        let point = event.window.map { $0.convertPoint(toScreen: event.locationInWindow) }
            ?? event.locationInWindow
        let pointerMoved = gesturePoint.map { hypot(point.x - $0.x, point.y - $0.y) > 3 } ?? false
        if event.phase.contains(.began) || pointerMoved
            || (event.phase.isEmpty && lastEventAt.map({ now - $0 >= gestureTimeout }) == true) {
            resetGesture()
        }
        defer {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) { resetGesture() }
        }
        let delta = event.scrollingDeltaY
        guard delta.isFinite, delta != 0 else { return }
        // Timer modes have one setting: every point in the circle is a target,
        // regardless of the remaining sector. Do not capture input outside the circle.
        if countdown.mode.usesTimer && circleOffset(for: event) == nil {
            resetGesture()
            return
        }
        countdown.update()
        // Hold the target while the pointer stays still, even when its sector shrinks.
        let target = previousTarget ?? (countdown.mode.usesTimer
            ? .timer : pomodoroTarget(for: event, countdown: countdown))
        guard let target else { return }
        previousTarget = target
        if gesturePoint == nil { gesturePoint = point }
        lastEventAt = now
        let direction = delta > 0 ? 1 : -1
        let isPreciseScrolling = event.hasPreciseScrollingDeltas
        let isOptionPressed = event.modifierFlags.contains(.option)
        if direction != lastDirection || isPreciseScrolling != wasPreciseScrolling || isOptionPressed != wasOptionPressed {
            accumulatedDistance = 0
        }
        lastDirection = direction
        wasPreciseScrolling = isPreciseScrolling
        wasOptionPressed = isOptionPressed
        // Wheel notches respond independently. Trackpads use distance, not event timing.
        // Option requires three times the travel without changing the five-minute marks.
        let threshold = (isPreciseScrolling ? preciseStepDistance : 1) * (isOptionPressed ? 3 : 1)
        accumulatedDistance += abs(delta)
        guard accumulatedDistance >= threshold else { return }
        // Limit accelerated events to one mark; never retain a backlog at a limit.
        accumulatedDistance.formTruncatingRemainder(dividingBy: threshold)
        adjust(target, steps: direction, countdown: countdown)
    }

    private func resetGesture() {
        previousTarget = nil
        lastEventAt = nil
        gesturePoint = nil
        lastDirection = 0
        accumulatedDistance = 0
        wasPreciseScrolling = nil
        wasOptionPressed = nil
    }

    private func adjust(_ target: Target, steps: Int, countdown: CountdownController) {
        switch target {
        case .timer: countdown.adjustTimerDuration(steps: steps)
        case .pomodoro(let phase): countdown.adjustPomodoroDuration(phase, steps: steps)
        }
    }

    private func circleOffset(for event: NSEvent) -> NSPoint? {
        guard let window, let content = window.contentView,
              event.window == nil || event.window === window else { return nil }
        // AppKit uses screen coordinates when an event has no associated window.
        let windowPoint = event.window == nil
            ? window.convertPoint(fromScreen: event.locationInWindow) : event.locationInWindow
        let point = content.convert(windowPoint, from: nil)
        let x = point.x - content.bounds.midX
        let y = (content.isFlipped ? -1.0 : 1.0) * (point.y - content.bounds.midY)
        let inset = isCompact() ? 0 : CountdownAppearance.circleInset * normalScale
        let radius = min(content.bounds.width, content.bounds.height) / 2 - inset
        let distance = hypot(x, y)
        // Coordinate conversion can put a perimeter point a few ULPs outside.
        guard radius > 0, distance <= radius + 1e-9 else { return nil }
        return NSPoint(x: x, y: y)
    }

    private func pomodoroTarget(for event: NSEvent, countdown: CountdownController) -> Target? {
        let model = countdown.pomodoro
        guard let offset = circleOffset(for: event), hypot(offset.x, offset.y) > 0 else { return nil }
        var degrees = atan2(offset.x, offset.y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        // Remove floating-point noise at exact shared boundaries, not a visible hit margin.
        degrees = ((degrees * 1_000_000_000).rounded() / 1_000_000_000).truncatingRemainder(dividingBy: 360)
        // Follow the visible clock sectors, including their moving start and hour wrap.
        let arcs = CountdownArcLayout.pomodoro(
            focusRemaining: model.focusRemaining,
            restRemaining: model.restRemaining,
            restDuration: model.activeRestDuration,
            at: countdown.currentTime,
            schedule: model.clockSchedule, restPhase: model.restPhase
        )
        if arcs.rest.contains(degrees / 360) { return .pomodoro(model.restPhase) }
        if arcs.focus.contains(degrees / 360) { return .pomodoro(.focus) }
        return nil
    }
}
