import Combine
import Foundation

/// Notifications at intervals or exact marks before the active countdown endpoint.
@MainActor
final class NotificationScheduler: ObservableObject {
    enum Event: Equatable {
        case remaining(TimeInterval)
        case alarm(String)
        case work
        case rest
    }

    var alarmMessage: String? {
        isAlarmEnabled && !configuration.alarmMessage.isEmpty ? configuration.alarmMessage : nil
    }
    private(set) var lastEvent: Event?
    private(set) var lastEventWasUserInitiated = false
    @Published private(set) var isNotificationEnabled: Bool
    @Published private(set) var isAlarmEnabled: Bool
    @Published private(set) var notificationIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let saveEnablement: (String, Bool) -> Void

    private var notificationInterval: TimeInterval { TimeInterval(configuration.notificationIntervalMinutes) * 60 }

    init(
        configuration: CountdownConfiguration,
        state: CountdownPreferences = CountdownPreferences(),
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownPreferencesStore().saveEnablement($0, enabled: $1) }
    ) {
        self.configuration = configuration
        self.saveEnablement = saveEnablement
        isNotificationEnabled = state.notificationEnabled
        isAlarmEnabled = state.alarmEnabled
    }

    func setNotificationEnabled(_ enabled: Bool) {
        isNotificationEnabled = enabled
        saveEnablement("notification_enabled", enabled)
    }

    func setAlarmEnabled(_ enabled: Bool) {
        isAlarmEnabled = enabled
        saveEnablement("alarm_enabled", enabled)
    }

    /// Call only for elapsed time, not duration edits. Late updates emit at most once.
    /// Both schedules include zero. No stored schedule can become stale after an endpoint edit.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        guard previousRemaining.isFinite, remaining.isFinite,
              previousRemaining > remaining, previousRemaining > 0 else { return }
        let crossedMark: Bool
        if let marks = configuration.notificationMarksMinutes {
            crossedMark = remaining <= 0 || marks.contains { minutes in
                let mark = TimeInterval(minutes) * 60
                return previousRemaining > mark && remaining <= mark
            }
        } else {
            crossedMark = ceil(previousRemaining / notificationInterval) > ceil(max(0, remaining) / notificationInterval)
        }
        guard crossedMark else { return }
        let event: Event = remaining <= 0
            ? alarmMessage.map(Event.alarm) ?? .remaining(remaining) : .remaining(remaining)
        notify(event: event)
    }

    /// Phase boundaries notify even when they do not cross an interval mark.
    func reportPhaseChange(remaining: TimeInterval, isUserInitiated: Bool = false) {
        guard remaining.isFinite else { return }
        notify(event: remaining > 0 ? .work : .rest,
               isUserInitiated: isUserInitiated)
    }

    private func notify(event: Event, isUserInitiated: Bool = false) {
        guard isNotificationEnabled else { return }
        // Set the payload before the published count calls its subscribers.
        lastEvent = event
        lastEventWasUserInitiated = isUserInitiated
        notificationIntervalCount += 1
    }
}
