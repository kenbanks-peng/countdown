/// The three timer presentations. Each mode fixes its timing model and clock display.
enum CountdownMode: String, CaseIterable, Codable {
    case pomodoro = "Pomodoro"
    case timer = "Timer"
    case countdown = "Countdown"

    var label: String { rawValue }
    var usesTimer: Bool { self != .pomodoro }
    var isClockEnabled: Bool { self != .countdown }
}
