import Combine
import Foundation

/// Interval notifications counted backwards from the active countdown endpoint.
@MainActor
final class PopupScheduler: ObservableObject {
    @Published private(set) var isPopupEnabled: Bool
    @Published private(set) var popupIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let saveEnablement: (String, Bool) -> Void

    private var popupInterval: TimeInterval { TimeInterval(configuration.popupIntervalMinutes) * 60 }

    init(
        configuration: CountdownConfiguration,
        state: CountdownPreferences = CountdownPreferences(),
        playSound: @escaping @MainActor (URL?) -> Void,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownPreferencesStore().saveEnablement($0, enabled: $1) }
    ) {
        self.configuration = configuration
        self.playSound = playSound
        self.saveEnablement = saveEnablement
        isPopupEnabled = configuration.popupNotificationEnabled && state.popupEnabled
    }

    func setPopupEnabled(_ enabled: Bool) {
        isPopupEnabled = enabled
        saveEnablement("popup_enabled", enabled)
    }

    /// Call only for elapsed time, not duration edits. Late updates emit at most once.
    /// Remaining-time multiples place every popup on the endpoint's clock schedule,
    /// including zero. No stored schedule can become stale after an endpoint edit.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        guard configuration.notificationEnabled, previousRemaining.isFinite, remaining.isFinite,
              previousRemaining > remaining, previousRemaining > 0,
              ceil(previousRemaining / popupInterval) > ceil(max(0, remaining) / popupInterval) else { return }
        if isPopupEnabled { popupIntervalCount += 1 }
        guard configuration.audioNotificationEnabled else { return }
        let sound: URL?
        switch CountdownUrgency(remaining: remaining) {
        case .normal: sound = configuration.greenNotificationURL
        case .warning: sound = configuration.yellowNotificationURL
        case .urgent: sound = configuration.redNotificationURL
        }
        playSound(sound)
    }
}
