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
    private let isCompact: () -> Bool
    private var previousTarget: Target?
    private var monitor: Any?
    private var modeCancellable: AnyCancellable?
    private var clockFaceCancellable: AnyCancellable?
    private var optionScrollDelta: CGFloat = 0
    private let preciseScrollThreshold: CGFloat = 12

    init(countdown: CountdownController, window: NSWindow? = nil, isCompact: @escaping () -> Bool = { false }) {
        self.countdown = countdown
        self.window = window
        self.isCompact = isCompact
        modeCancellable = countdown.$mode.sink { [weak self] _ in
            self?.optionScrollDelta = 0
            self?.previousTarget = nil
        }
        clockFaceCancellable = countdown.features.$isClockFaceEnabled.sink { [weak self] _ in
            self?.optionScrollDelta = 0
            self?.previousTarget = nil
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            Task { @MainActor in
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
        countdown.update()
        let target: Target? = countdown.mode == .timer
            ? .timer : pomodoroTarget(for: event, countdown: countdown)
        if target != previousTarget {
            optionScrollDelta = 0
            previousTarget = target
        }
        guard let target else { return }
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        guard event.modifierFlags.contains(.option) else {
            optionScrollDelta = 0
            adjust(target, by: delta > 0 ? 60 : -60, countdown: countdown)
            return
        }

        optionScrollDelta += delta
        guard abs(optionScrollDelta) >= preciseScrollThreshold else { return }

        let minutes = Int(optionScrollDelta / preciseScrollThreshold)
        optionScrollDelta -= CGFloat(minutes) * preciseScrollThreshold
        adjust(target, by: TimeInterval(minutes * 60), countdown: countdown)
    }

    private func adjust(_ target: Target, by amount: TimeInterval, countdown: CountdownController) {
        switch target {
        case .timer: countdown.adjustTimerDuration(by: amount)
        case .pomodoro(let phase): countdown.adjustPomodoroDuration(phase, by: amount)
        }
    }

    private func pomodoroTarget(for event: NSEvent, countdown: CountdownController) -> Target? {
        let model = countdown.pomodoro
        guard let window, let content = window.contentView,
              event.window == nil || event.window === window else { return nil }
        // AppKit uses screen coordinates when an event has no associated window.
        let windowPoint = event.window == nil
            ? window.convertPoint(fromScreen: event.locationInWindow) : event.locationInWindow
        let point = content.convert(windowPoint, from: nil)
        let x = point.x - content.bounds.midX
        let y = (content.isFlipped ? -1.0 : 1.0) * (point.y - content.bounds.midY)
        let inset = isCompact() ? 0 : PomodoroView.circleInset
        let radius = min(content.bounds.width, content.bounds.height) / 2 - inset
        let distance = hypot(x, y)
        // Coordinate conversion can put a perimeter point a few ULPs outside.
        guard radius > 0, distance > 0, distance <= radius + 1e-9 else { return nil }
        var degrees = atan2(x, y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        // Remove floating-point noise at exact shared boundaries, not a visible hit margin.
        degrees = ((degrees * 1_000_000_000).rounded() / 1_000_000_000).truncatingRemainder(dividingBy: 360)
        let clockEnabled = countdown.features.isClockFaceEnabled
        // Duration-only mode keeps allocated targets after their color has depleted.
        // Clock mode follows the visible sectors, including their moving start and hour wrap.
        let arcs = CountdownArcLayout.pomodoro(
            focusRemaining: clockEnabled ? model.focusRemaining : model.focusDuration,
            breakRemaining: clockEnabled ? model.breakRemaining : model.breakDuration,
            breakDuration: model.breakDuration,
            at: clockEnabled ? countdown.currentTime : nil
        )
        if arcs.shortBreak.contains(degrees / 360) { return .pomodoro(.shortBreak) }
        if arcs.focus.contains(degrees / 360) { return .pomodoro(.focus) }
        return nil
    }
}
