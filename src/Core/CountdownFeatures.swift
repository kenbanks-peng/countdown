import Combine
import Foundation

/// App-wide display settings and interval notifications, shared by both modes.
@MainActor
final class CountdownFeatures: ObservableObject {
    @Published private(set) var isClockEnabled: Bool
    @Published private(set) var isReminderEnabled: Bool
    @Published private(set) var reminderIntervalCount = 0

    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let saveEnablement: (String, Bool) -> Void
    private let now: () -> Date
    private var nextReminder: Date?

    private var reminderInterval: TimeInterval { TimeInterval(configuration.reminderTime) * 60 }

    init(
        configuration: CountdownConfiguration,
        playSound: @escaping @MainActor (URL?) -> Void,
        now: @escaping () -> Date = Date.init,
        saveEnablement: @escaping (String, Bool) -> Void = { CountdownConfiguration.saveEnablement($0, enabled: $1) }
    ) {
        self.now = now
        self.configuration = configuration
        self.playSound = playSound
        self.saveEnablement = saveEnablement
        isClockEnabled = configuration.clockEnabled
        isReminderEnabled = configuration.reminderEnabled
    }

    func setClockEnabled(_ enabled: Bool) {
        isClockEnabled = enabled
        saveEnablement("clock_enabled", enabled)
    }

    func setReminderEnabled(_ enabled: Bool) {
        if enabled != isReminderEnabled {
            nextReminder = enabled ? firstReminder(after: now()) : nil
        }
        isReminderEnabled = enabled
        saveEnablement("reminder_enabled", enabled)
    }

    /// Skip paused clock boundaries without changing the original schedule.
    func skipPausedReminders() {
        advanceSchedule(past: now())
    }

    private func firstReminder(after start: Date) -> Date {
        let earliest = start.addingTimeInterval(reminderInterval)
        let calendar = Calendar.current
        let minute = calendar.dateInterval(of: .minute, for: earliest)!.start
        let remainder = calendar.component(.minute, from: minute) % 5
        if remainder == 0 && earliest == minute { return minute }
        return minute.addingTimeInterval(TimeInterval(5 - remainder) * 60)
    }

    private func advanceSchedule(past date: Date) {
        guard let nextReminder, nextReminder <= date else { return }
        let intervals = floor(date.timeIntervalSince(nextReminder) / reminderInterval) + 1
        self.nextReminder = nextReminder.addingTimeInterval(intervals * reminderInterval)
    }

    /// Duration edits do not emit reminders. Late updates emit at most once.
    func reportElapsed(previousRemaining: TimeInterval, remaining: TimeInterval) {
        guard isReminderEnabled else { return }
        guard remaining > 0 else {
            nextReminder = nil
            return
        }
        let currentTime = now()
        if nextReminder == nil {
            let elapsed = max(0, previousRemaining - remaining)
            nextReminder = firstReminder(after: currentTime.addingTimeInterval(-elapsed))
        }
        guard previousRemaining > remaining,
              let nextReminder, currentTime >= nextReminder else { return }
        advanceSchedule(past: currentTime)
        reminderIntervalCount += 1
        let sound: URL?
        switch remaining {
        case 1_200...: sound = configuration.greenNotificationURL
        case 600...: sound = configuration.yellowNotificationURL
        default: sound = configuration.redNotificationURL
        }
        playSound(sound)
    }
}
