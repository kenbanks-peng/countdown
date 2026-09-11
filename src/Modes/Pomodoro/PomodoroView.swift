import SwiftUI

struct PomodoroView: View {
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
        let arcs = arcs
        let dotStates = model.dotStates
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
                PomodoroCycleGrid(count: model.focusPeriodsPerCycle) { index, diameter in
                    PomodoroCycleIndicator(state: dotStates[index], diameter: diameter)
                        .padding(1)
                }
                .fixedSize()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .offset(y: 32)
            }
            if model.status == .paused {
                CountdownPauseIndicator(isCompact: isCompact)
            }
        }
        .clipShape(Circle())
        .padding(isCompact ? 0 : CountdownAppearance.circleInset)
    }
}

struct PomodoroCycleIndicator: View {
    let state: PomodoroModel.DotState
    var diameter: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().strokeBorder(.white, lineWidth: 1)
            if state == .completed {
                Circle().fill(.white)
            } else if state == .current {
                Circle().fill(.white).padding(diameter * 0.3125)
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

struct PomodoroCycleControls: View {
    let model: PomodoroModel
    let selectStage: (Int) -> Void

    var body: some View {
        PomodoroCycleGrid(count: model.focusPeriodsPerCycle) { index, diameter in
            Button { selectStage(index + 1) } label: {
                PomodoroCycleIndicator(state: model.dotStates[index], diameter: diameter)
                    .padding(1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start Pomodoro cycle \(index + 1)")
            .accessibilityHint("Hold Option while clicking to restore default durations.")
            .help("Start work at cycle \(index + 1). Hold Option to restore default durations.")
        }
        .fixedSize()
        .offset(y: 32)
    }
}
