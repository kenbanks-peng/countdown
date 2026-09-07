/// The two UI modes supported by Countdown.
enum CountdownMode: String, CaseIterable, Codable {
    case timer = "Timer"
    case pomodoro = "Pomodoro"

    var label: String { rawValue }
}
