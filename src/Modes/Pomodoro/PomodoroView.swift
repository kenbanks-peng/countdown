import SwiftUI

struct PomodoroView: View {
    static let circleInset: CGFloat = 6
    let model: PomodoroModel
    var isCompact = false
    var clockDate: Date? = nil
    var showsSessionDots = true

    private var arcs: (focus: CountdownArcLayout, rest: CountdownArcLayout) {
        CountdownArcLayout.pomodoro(
            focusRemaining: model.focusRemaining, restRemaining: model.restRemaining,
            restDuration: model.activeRestDuration, at: clockDate,
            schedule: model.clockSchedule, restPhase: model.restPhase
        )
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.countdownSurface)
            RadialSector(proportion: arcs.rest.proportion, startProportion: arcs.rest.startProportion)
                .fill(Color.pomodoroBlue)
            RadialSector(
                proportion: arcs.focus.proportion,
                startProportion: arcs.focus.startProportion
            )
            .fill(Color.countdownGreen)
            Circle()
                .stroke(Color.countdownTrack.opacity(0.7), lineWidth: isCompact ? 1 : 3)
                .padding(isCompact ? 0.5 : 2)
            if !isCompact && showsSessionDots {
                HStack(spacing: model.cycles > 6 ? 2 : 6) {
                    ForEach(0..<model.cycles, id: \.self) { index in
                        ZStack {
                            Circle().strokeBorder(.white, lineWidth: 1)
                            if model.dotStates[index] == .completed {
                                Circle().fill(.white)
                            } else if model.dotStates[index] == .current {
                                Circle().fill(.white).padding(2.5)
                            }
                        }
                        .frame(width: 8, height: 8)
                    }
                }
                .fixedSize()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .offset(y: 32)
            }
        }
        .clipShape(Circle())
        .padding(isCompact ? 0 : Self.circleInset)
    }
}
