import AppKit
import Combine

@MainActor
final class ScrollTimeAdjuster {
    private enum Target: Equatable {
        case countdown
        case pomodoro(PomodoroModel.Phase)
    }

    private weak var timer: TimerController?
    private weak var window: NSWindow?
    private var previousTarget: Target?
    private var monitor: Any?
    private var modeCancellable: AnyCancellable?
    private var optionScrollDelta: CGFloat = 0
    private let preciseScrollThreshold: CGFloat = 12

    init(timer: TimerController, window: NSWindow? = nil) {
        self.timer = timer
        self.window = window
        modeCancellable = timer.$mode.sink { [weak self] _ in
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
        guard let timer else { return }
        let target: Target? = timer.mode == .countdown
            ? .countdown : pomodoroTarget(for: event, model: timer.pomodoro)
        if target != previousTarget {
            optionScrollDelta = 0
            previousTarget = target
        }
        guard let target else { return }
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        guard event.modifierFlags.contains(.option) else {
            optionScrollDelta = 0
            adjust(target, by: delta > 0 ? 60 : -60, timer: timer)
            return
        }

        optionScrollDelta += delta
        guard abs(optionScrollDelta) >= preciseScrollThreshold else { return }

        let minutes = Int(optionScrollDelta / preciseScrollThreshold)
        optionScrollDelta -= CGFloat(minutes) * preciseScrollThreshold
        adjust(target, by: TimeInterval(minutes * 60), timer: timer)
    }

    private func adjust(_ target: Target, by amount: TimeInterval, timer: TimerController) {
        switch target {
        case .countdown: timer.adjustCountdownDuration(by: amount)
        case .pomodoro(let phase): timer.adjustPomodoroDuration(phase, by: amount)
        }
    }

    private func pomodoroTarget(for event: NSEvent, model: PomodoroModel) -> Target? {
        guard let window, let content = window.contentView,
              event.window == nil || event.window === window else { return nil }
        // AppKit uses screen coordinates when an event has no associated window.
        let windowPoint = event.window == nil
            ? window.convertPoint(fromScreen: event.locationInWindow) : event.locationInWindow
        let point = content.convert(windowPoint, from: nil)
        let x = point.x - content.bounds.midX
        let y = (content.isFlipped ? -1.0 : 1.0) * (point.y - content.bounds.midY)
        let radius = min(content.bounds.width, content.bounds.height) / 2 - PomodoroView.circleInset
        let distance = hypot(x, y)
        // Coordinate conversion can put a perimeter point a few ULPs outside.
        guard radius > 0, distance > 0, distance <= radius + 1e-9 else { return nil }
        var degrees = atan2(x, y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        // Remove floating-point noise at exact shared boundaries, not a visible hit margin.
        degrees = ((degrees * 1_000_000_000).rounded() / 1_000_000_000).truncatingRemainder(dividingBy: 360)
        // Configured allocations remain targets after their color has depleted.
        let secondsPerDegree: TimeInterval = 3_600 / 360
        if degrees < model.breakDuration / secondsPerDegree { return .pomodoro(.shortBreak) }
        if degrees < (model.breakDuration + model.focusDuration) / secondsPerDegree { return .pomodoro(.focus) }
        return nil
    }
}
