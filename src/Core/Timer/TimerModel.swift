import Combine
import Foundation

/// A core Timer record. CountdownEngine controls its shared run state;
/// the UI supplies permission for timeout actions.
@MainActor
final class TimerModel: ObservableObject {
    enum Status { case empty, prepared, active }

    @Published private(set) var status: Status = .empty
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var completionCount = 0
    @Published private(set) var showsRemainingMinutes = true
    @Published private(set) var isAutoSetToNextHourEnabled = false

    // The engine can be paused even when this record is empty.
    var isEnginePaused = false
    private(set) var endDate: Date?
    private(set) var pausedAt: Date?
    private(set) var isClockEnabled: Bool
    private let sessionStore: TimerSessionStore
    private let configuration: CountdownConfiguration
    private let preferencesStore: CountdownPreferencesStore
    private let isAlarmEnabled: Bool
    private let playSound: @MainActor (URL?) -> Void
    private let now: () -> Date
    private let reportElapsed: (TimeInterval, TimeInterval) -> Void
    private let timeoutActionsEnabled: () -> Bool

    init(
        sessionStore: TimerSessionStore = .default,
        configuration: CountdownConfiguration = .default,
        preferences: CountdownPreferences? = nil,
        isClockEnabled: Bool,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownSound.play,
        now: @escaping () -> Date = Date.init,
        reportElapsed: @escaping (TimeInterval, TimeInterval) -> Void = { _, _ in },
        timeoutActionsEnabled: @escaping () -> Bool = { true }
    ) {
        self.sessionStore = sessionStore
        self.configuration = configuration
        self.playSound = playSound
        self.now = now
        self.reportElapsed = reportElapsed
        self.timeoutActionsEnabled = timeoutActionsEnabled
        preferencesStore = CountdownPreferencesStore(
            fileManager: sessionStore.fileManager, stateDirectory: sessionStore.stateDirectory
        )
        let state = preferences ?? preferencesStore.load()
        showsRemainingMinutes = state.showsRemainingMinutes
        isAutoSetToNextHourEnabled = state.autoSetToNextHourEnabled
        isAlarmEnabled = configuration.alarmEnabled && state.alarmEnabled
        self.isClockEnabled = isClockEnabled
        restore()
        if timeoutActionsEnabled() { autoSetToNextHour() }
    }

    static let maximumDuration: TimeInterval = 60 * 60

    var hourProportion: Double {
        min(1, max(0, remaining / Self.maximumDuration))
    }

    var remainingMinutes: Int {
        Int(ceil(max(0, remaining) / 60))
    }

    var isPaused: Bool { status == .prepared && remaining > 0 }

    func setRemainingMinutesVisible(_ enabled: Bool) {
        showsRemainingMinutes = enabled
        preferencesStore.saveEnablement("current_timeout_enabled", enabled: enabled)
    }

    func setAutoSetToNextHourEnabled(_ enabled: Bool) {
        isAutoSetToNextHourEnabled = enabled
        preferencesStore.saveEnablement("autoset_enabled", enabled: enabled)
    }

    func autoSetToNextHour() {
        guard isAutoSetToNextHourEnabled else { return }
        setDurationToNextHour()
    }

    func setDurationToNextHour() {
        let currentTime = now()
        let calendar = Calendar.current
        guard let nextHour = calendar.nextDate(
            after: currentTime,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }

        duration = nextHour.timeIntervalSince(currentTime)
        remaining = duration

        if status == .prepared || isEnginePaused {
            pausedAt = isClockEnabled ? currentTime : nil
            endDate = isClockEnabled ? nextHour : nil
            status = .prepared
        } else {
            endDate = nextHour
            status = .active
        }
        save()
    }

    func setDuration(from proportion: Double) {
        let clampedProportion = min(1, max(0, proportion))
        if isClockEnabled {
            let date = now()
            let target = ClockBoundary.nearest(date + clampedProportion * Self.maximumDuration,
                                               minimum: date + 300, maximum: date + Self.maximumDuration)
            if clampedProportion == 0 { clear() } else { setClockEndpoint(target, at: date) }
            return
        }
        duration = (clampedProportion * Self.maximumDuration).rounded()
        remaining = duration

        guard duration > 0 else {
            clear()
            return
        }

        if status == .prepared || isEnginePaused {
            endDate = nil
            status = .prepared
        } else {
            endDate = now().addingTimeInterval(remaining)
            status = .active
        }
        save()
    }

    func adjustDuration(by amount: TimeInterval, at date: Date? = nil) {
        guard amount.isFinite, amount != 0 else { return }

        let date = date ?? now()
        update(at: date)
        if isClockEnabled {
            let reference = pausedAt ?? date
            let end = endDate ?? reference
            let target = ClockBoundary.nearest(end + amount, minimum: reference + 300,
                                               maximum: reference + Self.maximumDuration)
            if status == .empty && amount < 0 { return }
            setClockEndpoint(target, at: reference)
            return
        }
        let adjustedRemaining = min(Self.maximumDuration, max(0, remaining + amount))
        guard adjustedRemaining != remaining else { return }

        if adjustedRemaining == 0 {
            clear()
            return
        }

        switch status {
        case .active:
            duration = min(Self.maximumDuration, max(0, duration + amount))
            remaining = adjustedRemaining
            endDate = date.addingTimeInterval(adjustedRemaining)
        case .prepared:
            duration = adjustedRemaining
            remaining = adjustedRemaining
            endDate = nil
        case .empty:
            duration = adjustedRemaining
            remaining = adjustedRemaining
            endDate = isEnginePaused ? nil : date.addingTimeInterval(remaining)
            status = isEnginePaused ? .prepared : .active
        }
        save()
    }

    func setClockEnabled(_ enabled: Bool) {
        update()
        guard enabled != isClockEnabled else { return }
        isClockEnabled = enabled
        if status == .prepared {
            pausedAt = enabled ? now() : nil
            endDate = enabled ? now() + remaining : nil
        }
        save()
    }

    func adjustClockEndpoint(steps: Int, at date: Date) {
        guard steps != 0, status != .empty || steps > 0 else { return }
        update(at: date)
        let reference = pausedAt ?? date
        let end = endDate ?? reference
        let target = ClockBoundary.move(end, steps: steps, minimum: reference + 300,
                                        maximum: reference + Self.maximumDuration)
        setClockEndpoint(target, at: reference)
    }

    private func setClockEndpoint(_ end: Date, at date: Date) {
        endDate = end
        remaining = max(0, end.timeIntervalSince(date))
        duration = remaining
        status = isEnginePaused || status == .prepared ? .prepared : .active
        pausedAt = status == .prepared ? date : nil
        save()
    }

    func resume() {
        guard status == .prepared, remaining > 0 else { return }
        let date = now()
        if isClockEnabled {
            let resumedEndDate = ClockBoundary.nearest(date + remaining, minimum: date + 1, maximum: date + Self.maximumDuration)
            endDate = resumedEndDate
            remaining = max(0, resumedEndDate.timeIntervalSince(date))
            duration = remaining
        } else {
            endDate = date.addingTimeInterval(remaining)
        }
        pausedAt = nil
        status = .active
        save()
    }

    func pause() {
        guard status == .active else { return }
        update()
        guard status == .active else { return }
        pausedAt = isClockEnabled ? now() : nil
        if !isClockEnabled { endDate = nil }
        status = .prepared
        duration = remaining
        save()
    }

    func clear() {
        status = .empty
        duration = 0
        remaining = 0
        endDate = nil
        pausedAt = nil
        sessionStore.remove()
    }

    func update(reportEvents: Bool = true, at date: Date? = nil) {
        guard status == .active, let endDate else { return }

        let previousRemaining = remaining
        remaining = max(0, endDate.timeIntervalSince(date ?? now()))
        if reportEvents { reportElapsed(previousRemaining, remaining) }

        if remaining == 0 {
            self.endDate = nil
            status = .empty
            duration = 0
            // The empty status prevents later updates from reporting this completion again.
            if reportEvents && timeoutActionsEnabled() {
                completionCount += 1
                if isAlarmEnabled {
                    playSound(configuration.alarmNotificationURL)
                }
            }
            sessionStore.remove()
            if timeoutActionsEnabled() { autoSetToNextHour() }
        }
    }

    func save() {
        guard remaining > 0, status != .empty, status != .active || endDate != nil else {
            sessionStore.remove()
            return
        }
        sessionStore.save(.init(
            status: status == .active ? .active : .prepared,
            duration: duration, remaining: remaining, endDate: endDate,
            savedAt: now(), pausedAt: status == .prepared ? pausedAt : nil
        ))
    }

    private func restore() {
        guard let saved = sessionStore.load(), saved.duration > 0, saved.remaining > 0 else { return }
        guard (isClockEnabled && saved.status == .prepared) || now().timeIntervalSince(saved.savedAt) <= saved.duration else {
            sessionStore.remove()
            return
        }

        duration = saved.duration
        remaining = saved.remaining
        switch saved.status {
        case .active:
            guard let endDate = saved.endDate else {
                clear()
                return
            }
            self.endDate = endDate
            status = .active
            update(reportEvents: false)
        case .prepared:
            status = .prepared
            if isClockEnabled {
                pausedAt = saved.pausedAt ?? now()
                endDate = saved.endDate ?? now() + remaining
            }
        }
    }
}

