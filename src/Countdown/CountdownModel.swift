import AppKit
import Foundation

@MainActor
final class CountdownModel: ObservableObject {
    enum Status { case empty, prepared, active }

    @Published private(set) var status: Status = .empty
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var completionCount = 0
    @Published private(set) var isCurrentTimeoutEnabled = true
    @Published private(set) var isAutosetEnabled = false

    private var endDate: Date?
    private var completionWasReported = false
    private let stateStore: CountdownStateStore
    private let configuration: CountdownConfiguration
    private let playSound: @MainActor (URL?) -> Void
    private let now: () -> Date
    private let reportElapsed: (TimeInterval, TimeInterval) -> Void

    init(
        stateStore: CountdownStateStore = .default,
        configuration: CountdownConfiguration = .default,
        playSound: @escaping @MainActor (URL?) -> Void = CountdownModel.playSound,
        now: @escaping () -> Date = Date.init,
        reportElapsed: @escaping (TimeInterval, TimeInterval) -> Void = { _, _ in }
    ) {
        self.stateStore = stateStore
        self.configuration = configuration
        self.playSound = playSound
        self.now = now
        self.reportElapsed = reportElapsed
        isCurrentTimeoutEnabled = configuration.currentTimeoutEnabled
        isAutosetEnabled = configuration.autosetEnabled
        restore()
        autoset()
    }

    static let maximumDuration: TimeInterval = 60 * 60

    var proportion: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, remaining / duration))
    }

    var hourProportion: Double {
        min(1, max(0, remaining / Self.maximumDuration))
    }

    var remainingMinutes: Int {
        Int(ceil(max(0, remaining) / 60))
    }

    var isPaused: Bool { status == .prepared && remaining > 0 }

    func setCurrentTimeoutEnabled(_ enabled: Bool) {
        isCurrentTimeoutEnabled = enabled
        CountdownConfiguration.saveEnablement("current_timeout_enabled", enabled: enabled)
    }

    func setAutosetEnabled(_ enabled: Bool) {
        isAutosetEnabled = enabled
        CountdownConfiguration.saveEnablement("autoset_enabled", enabled: enabled)
    }

    func autoset() {
        guard isAutosetEnabled else { return }
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
        completionWasReported = false

        if status == .prepared {
            endDate = nil
        } else {
            endDate = nextHour
            status = .active
        }
        save()
    }

    func setDuration(from proportion: Double) {
        let clampedProportion = min(1, max(0, proportion))
        duration = (clampedProportion * Self.maximumDuration).rounded()
        remaining = duration
        completionWasReported = false

        guard duration > 0 else {
            clear()
            return
        }

        if status == .prepared {
            endDate = nil
        } else {
            endDate = now().addingTimeInterval(remaining)
            status = .active
        }
        save()
    }

    func adjustDuration(by amount: TimeInterval) {
        guard amount != 0 else { return }

        update()
        let adjustedRemaining = min(Self.maximumDuration, max(0, remaining + amount)).rounded()
        guard adjustedRemaining != remaining else { return }

        if adjustedRemaining == 0 {
            clear()
            return
        }

        switch status {
        case .active:
            duration = min(Self.maximumDuration, max(0, duration + amount))
            remaining = adjustedRemaining
            endDate = now().addingTimeInterval(adjustedRemaining)
        case .prepared:
            duration = adjustedRemaining
            remaining = adjustedRemaining
            endDate = nil
        case .empty:
            duration = adjustedRemaining
            remaining = adjustedRemaining
            endDate = now().addingTimeInterval(remaining)
            status = .active
        }
        completionWasReported = false
        save()
    }

    func toggleRunning() {
        switch status {
        case .active:
            stop()
        case .prepared:
            start()
        case .empty:
            break
        }
    }

    func start() {
        guard status == .prepared, remaining > 0 else { return }
        endDate = now().addingTimeInterval(remaining)
        status = .active
        completionWasReported = false
        save()
    }

    func stop() {
        guard status == .active else { return }
        update()
        guard status == .active else { return }
        endDate = nil
        status = .prepared
        duration = remaining
        save()
    }

    func clear() {
        status = .empty
        duration = 0
        remaining = 0
        endDate = nil
        completionWasReported = false
        stateStore.remove()
    }

    func update(reportCompletion: Bool = true) {
        guard status == .active, let endDate else { return }

        let previousRemaining = remaining
        remaining = max(0, endDate.timeIntervalSince(now()))
        reportElapsed(previousRemaining, remaining)

        if remaining == 0 {
            self.endDate = nil
            status = .empty
            duration = 0
            if reportCompletion && !completionWasReported {
                completionWasReported = true
                completionCount += 1
                if configuration.alarmEnabled {
                    playSound(configuration.alarmNotificationURL)
                }
            }
            stateStore.remove()
            autoset()
        }
    }

    func save() {
        guard remaining > 0 else {
            stateStore.remove()
            return
        }

        switch status {
        case .active:
            guard let endDate else {
                stateStore.remove()
                return
            }
            stateStore.save(.init(status: .active, duration: duration, remaining: remaining, endDate: endDate, savedAt: now()))
        case .prepared:
            stateStore.save(.init(status: .prepared, duration: duration, remaining: remaining, endDate: nil, savedAt: now()))
        case .empty:
            stateStore.remove()
        }
    }

    static func playSound(at soundURL: URL?) {
        guard let soundURL,
              let sound = NSSound(contentsOf: soundURL, byReference: true)
        else {
            NSSound.beep()
            return
        }
        sound.play()
    }

    private func restore() {
        guard let saved = stateStore.load(), saved.duration > 0, saved.remaining > 0 else { return }
        guard now().timeIntervalSince(saved.savedAt) <= saved.duration else {
            stateStore.remove()
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
            update(reportCompletion: false)
        case .prepared:
            status = .prepared
        }
    }
}

