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
                Button(action: timer.togglePomodoroRunning) {
                    PomodoroView(model: timer.pomodoro)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(timer.pomodoro.accessibilityDescription)
                .accessibilityHint("Click to \(timer.pomodoro.controlLabel.lowercased()). Use the context menu to reset the pair.")
                .help("Click to \(timer.pomodoro.controlLabel.lowercased()). Scroll blue to adjust break; scroll green to adjust focus. Option-scroll is slower. Each phase is at least 1 minute; the pair is at most 60 minutes.")
                .task {
                    while !Task.isCancelled {
                        timer.update()
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                }
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
            } else {
                Button(timer.pomodoro.controlLabel, action: timer.togglePomodoroRunning)
                Button("Reset", action: timer.resetPomodoro)
            }
            Divider()
            Button("Quit Countdown") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
