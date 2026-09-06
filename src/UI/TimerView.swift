import AppKit
import SwiftUI

/// Normal presentation. Compact Pomodoro is supplied by its own feature slice.
struct TimerView: View {
    @ObservedObject var timer: TimerController
    let compact: () -> Void

    var body: some View {
        Group {
            switch timer.mode {
            case .countdown:
                CountdownView(model: timer.countdown, compact: compact)
            case .pomodoro:
                PomodoroView(model: timer.pomodoro)
            }
        }
        .contextMenu {
            Picker("Timer Mode", selection: Binding(get: { timer.mode }, set: timer.selectMode)) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.inline)
            Divider()
            if timer.mode == .countdown {
                CountdownContextMenu(model: timer.countdown, timer: timer)
                Divider()
            }
            Button("Quit Countdown") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
