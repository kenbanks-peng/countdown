import SwiftUI

struct PomodoroView: View {
    let model: PomodoroModel

    var body: some View {
        ZStack {
            Circle().fill(Color.countdownSurface)
            RadialSector(proportion: model.breakDuration / 3_600)
                .fill(Color.pomodoroBlue)
            RadialSector(
                proportion: model.focusDuration / 3_600,
                startProportion: model.breakDuration / 3_600
            )
            .fill(Color.countdownGreen)
            Circle()
                .stroke(Color.countdownTrack.opacity(0.7), lineWidth: 3)
                .padding(2)
            Text(model.phaseLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .offset(y: 32)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.accessibilityDescription)
        .help("Pomodoro allocation preview: 25 minutes of focus and 5 minutes of break.")
        .padding(6)
    }
}
