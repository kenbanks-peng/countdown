import Combine
import Foundation

/// Interval notifications counted backwards from the active countdown endpoint.
@MainActor
final class NotificationScheduler: ObservableObject {
    enum Event: Equatable {
        case remaining(TimeInterval)
        case work
        case rest
    }

    private(set) var lastEvent: Event?
    private(set) var lastEventWasUserInitiated = false
    @Published private(set) var isNotificationEnabled: Bool
    @Published private(set) var notificationIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let saveEnablement: (String, Bool) -> Void

    private var notificationInterval: TimeInterval { TimeInterval(configuration.notificationIntervalMinutes) * 60 }

    init(
        configuration: CountdownConfiguration,
        state: CountdownPreferences = CountdownPreferences(),
        playSound: @escaping @MainActor (URL?) -> Void,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownPreferencesStore().saveEnablement($0, enabled: $1) }
    ) {
        self.configuration = configuration
        self.playSound = playSound
        self.saveEnablement = saveEnablement
        isNotificationEnabled = configuration.notificationEnabled && state.notificationEnabled
    }

    func setNotificationEnabled(_ enabled: Bool) {
        isNotificationEnabled = enabled
        saveEnablement("notification_enabled", enabled)
    }

    /// Call only for elapsed time, not duration edits. Late updates emit at most once.
    /// Remaining-time multiples place every notification on the endpoint's clock schedule,
    /// including zero. No stored schedule can become stale after an endpoint edit.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        guard configuration.notificationEnabled, previousRemaining.isFinite, remaining.isFinite,
              previousRemaining > remaining, previousRemaining > 0,
              ceil(previousRemaining / notificationInterval) > ceil(max(0, remaining) / notificationInterval) else { return }
        notify(remaining: remaining, event: .remaining(remaining))
    }

    /// Phase boundaries notify even when they do not cross an interval mark.
    func reportPhaseChange(remaining: TimeInterval, isUserInitiated: Bool = false) {
        guard configuration.notificationEnabled, remaining.isFinite else { return }
        notify(remaining: remaining, event: remaining > 0 ? .work : .rest,
               isUserInitiated: isUserInitiated)
    }

    private func notify(remaining: TimeInterval, event: Event, isUserInitiated: Bool = false) {
        guard isNotificationEnabled else { return }
        // Set the payload before the published count calls its subscribers.
        lastEvent = event
        lastEventWasUserInitiated = isUserInitiated
        notificationIntervalCount += 1
        guard configuration.notificationAudioEnabled else { return }
        let sound: URL?
        switch CountdownUrgency(remaining: remaining) {
        case .normal: sound = configuration.greenNotificationURL
        case .warning: sound = configuration.yellowNotificationURL
        case .urgent: sound = configuration.redNotificationURL
        }
        playSound(sound)
    }
}
