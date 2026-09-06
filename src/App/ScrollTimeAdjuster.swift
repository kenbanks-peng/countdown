import AppKit
import Combine

@MainActor
final class ScrollTimeAdjuster {
    private weak var timer: TimerController?
    private var monitor: Any?
    private var modeCancellable: AnyCancellable?
    private var optionScrollDelta: CGFloat = 0
    private let preciseScrollThreshold: CGFloat = 12

    init(timer: TimerController) {
        self.timer = timer
        modeCancellable = timer.$mode.sink { [weak self] _ in
            self?.optionScrollDelta = 0
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
        guard let timer, timer.mode == .countdown else {
            optionScrollDelta = 0
            return
        }
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        guard event.modifierFlags.contains(.option) else {
            optionScrollDelta = 0
            timer.adjustCountdownDuration(by: delta > 0 ? 60 : -60)
            return
        }

        optionScrollDelta += delta
        guard abs(optionScrollDelta) >= preciseScrollThreshold else { return }

        let minutes = Int(optionScrollDelta / preciseScrollThreshold)
        optionScrollDelta -= CGFloat(minutes) * preciseScrollThreshold
        timer.adjustCountdownDuration(by: TimeInterval(minutes * 60))
    }
}
