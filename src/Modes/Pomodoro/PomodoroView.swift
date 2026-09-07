import SwiftUI

struct PomodoroView: View {
    static let circleInset: CGFloat = 6
    let model: PomodoroModel
    var isCompact = false
    var clockDate: Date? = nil

    private var arcs: (focus: CountdownArcLayout, shortBreak: CountdownArcLayout) {
        CountdownArcLayout.pomodoro(
            focusRemaining: model.focusRemaining, breakRemaining: model.breakRemaining,
            breakDuration: model.breakDuration, at: clockDate
        )
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.countdownSurface)
            RadialSector(proportion: arcs.shortBreak.proportion, startProportion: arcs.shortBreak.startProportion)
                .fill(Color.pomodoroBlue)
            RadialSector(
                proportion: arcs.focus.proportion,
                startProportion: arcs.focus.startProportion
            )
            .fill(Color.countdownGreen)
            Circle()
                .stroke(Color.countdownTrack.opacity(0.7), lineWidth: isCompact ? 1 : 3)
                .padding(isCompact ? 0.5 : 2)
            if !isCompact {
                Text(model.phaseLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .offset(y: 32)
            }
        }
        .clipShape(Circle())
        .padding(isCompact ? 0 : Self.circleInset)
    }
}
