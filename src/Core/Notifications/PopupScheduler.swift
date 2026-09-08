import Combine
import Foundation

/// App-wide interval notifications, shared by all modes.
@MainActor
final class PopupScheduler: ObservableObject {
    @Published private(set) var isPopupEnabled: Bool
    @Published private(set) var popupIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let saveEnablement: (String, Bool) -> Void
    private let now: () -> Date
    private var nextPopupDate: Date?

    private var popupInterval: TimeInterval { TimeInterval(configuration.popupIntervalMinutes) * 60 }

    init(
        configuration: CountdownConfiguration,
        state: CountdownPreferences = CountdownPreferences(),
        playSound: @escaping @MainActor (URL?) -> Void,
        now: @escaping () -> Date = Date.init,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownPreferencesStore().saveEnablement($0, enabled: $1) }
    ) {
        self.now = now
        self.configuration = configuration
        self.playSound = playSound
        self.saveEnablement = saveEnablement
        isPopupEnabled = state.popupEnabled
    }

    func setPopupEnabled(_ enabled: Bool) {
        if enabled != isPopupEnabled {
            nextPopupDate = enabled ? firstPopup(after: now()) : nil
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
        guard let nextPopupDate, nextPopupDate <= date else { return }
        let intervals = floor(date.timeIntervalSince(nextPopupDate) / popupInterval) + 1
        self.nextPopupDate = nextPopupDate.addingTimeInterval(intervals * popupInterval)
    }

    /// Duration edits do not emit popups. Late updates emit at most once.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        guard isPopupEnabled else { return }
        guard remaining > 0 else {
            nextPopupDate = nil
            return
        }
        let currentTime = now()
        if nextPopupDate == nil {
            let elapsed = max(0, previousRemaining - remaining)
            nextPopupDate = firstPopup(after: currentTime.addingTimeInterval(-elapsed))
        }
        guard previousRemaining > remaining,
              let nextPopupDate, currentTime >= nextPopupDate else { return }
        advanceSchedule(past: currentTime)
        popupIntervalCount += 1
        let sound: URL?
        switch CountdownUrgency(remaining: remaining) {
        case .normal: sound = configuration.greenNotificationURL
        case .warning: sound = configuration.yellowNotificationURL
        case .urgent: sound = configuration.redNotificationURL
        }
        playSound(sound)
    }
}
