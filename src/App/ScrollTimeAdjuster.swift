import AppKit

@MainActor
final class ScrollTimeAdjuster {
    private weak var model: CountdownModel?
    private var monitor: Any?
    private var optionScrollDelta: CGFloat = 0
    private let preciseScrollThreshold: CGFloat = 12

    init(model: CountdownModel) {
        self.model = model
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

    private func handle(_ event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }

        guard event.modifierFlags.contains(.option) else {
            optionScrollDelta = 0
            model?.adjustDuration(by: delta > 0 ? 60 : -60)
            return
        }

        optionScrollDelta += delta
        guard abs(optionScrollDelta) >= preciseScrollThreshold else { return }

        let minutes = Int(optionScrollDelta / preciseScrollThreshold)
        optionScrollDelta -= CGFloat(minutes) * preciseScrollThreshold
        model?.adjustDuration(by: TimeInterval(minutes * 60))
    }
}
