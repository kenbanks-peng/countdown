import Combine
import Foundation

/// App-wide interval notifications, shared by all modes.
@MainActor
final class CountdownFeatures: ObservableObject {
    @Published private(set) var isPopupEnabled: Bool
    @Published private(set) var popupIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let saveEnablement: (String, Bool) -> Void
    private let now: () -> Date
    private var nextPopup: Date?

    private var popupInterval: TimeInterval { TimeInterval(configuration.popupTime) * 60 }

    init(
        configuration: CountdownConfiguration,
        state: CountdownFeatureState = CountdownFeatureState(),
        playSound: @escaping @MainActor (URL?) -> Void,
        now: @escaping () -> Date = Date.init,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownFeatureStateStore().saveEnablement($0, enabled: $1) }
    ) {
        self.now = now
        self.configuration = configuration
        self.playSound = playSound
        self.saveEnablement = saveEnablement
        isPopupEnabled = state.popupEnabled
    }

    func setPopupEnabled(_ enabled: Bool) {
        if enabled != isPopupEnabled {
            nextPopup = enabled ? firstPopup(after: now()) : nil
        }
        isPopupEnabled = enabled
        saveEnablement("popup_enabled", enabled)
    }

    /// Skip paused clock boundaries without changing the original schedule.
    func skipPausedPopups() {
        advanceSchedule(past: now())
    }

    private func firstPopup(after start: Date) -> Date {
        let earliest = start.addingTimeInterval(popupInterval)
        let calendar = Calendar.current
        let minute = calendar.dateInterval(of: .minute, for: earliest)!.start
        let remainder = calendar.component(.minute, from: minute) % 5
        if remainder == 0 && earliest == minute { return minute }
        return minute.addingTimeInterval(TimeInterval(5 - remainder) * 60)
    }

    private func advanceSchedule(past date: Date) {
        guard let nextPopup, nextPopup <= date else { return }
        let intervals = floor(date.timeIntervalSince(nextPopup) / popupInterval) + 1
        self.nextPopup = nextPopup.addingTimeInterval(intervals * popupInterval)
    }

    /// Duration edits do not emit popups. Late updates emit at most once.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        guard isPopupEnabled else { return }
        guard remaining > 0 else {
            nextPopup = nil
            return
        }
        let currentTime = now()
        if nextPopup == nil {
            let elapsed = max(0, previousRemaining - remaining)
            nextPopup = firstPopup(after: currentTime.addingTimeInterval(-elapsed))
        }
        guard previousRemaining > remaining,
              let nextPopup, currentTime >= nextPopup else { return }
        advanceSchedule(past: currentTime)
        popupIntervalCount += 1
        let sound: URL?
        switch remaining {
        case 1_200...: sound = configuration.greenNotificationURL
        case 600...: sound = configuration.yellowNotificationURL
        default: sound = configuration.redNotificationURL
        }
        playSound(sound)
    }
}
