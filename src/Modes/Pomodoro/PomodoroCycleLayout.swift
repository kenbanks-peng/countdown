import SwiftUI

/// Balanced, centered rows keep the cycle controls below the clock center.
struct PomodoroCycleLayout {
    let rows: [Range<Int>]
    let diameter: CGFloat
    let spacing: CGFloat = 4

    init(count: Int) {
        let count = PomodoroModel.normalizedFocusPeriodCount(count)
        let rowCount = count <= 4 ? 1 : count <= 10 ? 2 : 3
        switch count {
        case 1...2: diameter = 12
        case 3...4: diameter = 10
        case 5...8: diameter = 9
        case 9...12: diameter = 8
        default: diameter = 7
        }
        var start = 0
        rows = (0..<rowCount).map { row in
            let length = count / rowCount + (row < count % rowCount ? 1 : 0)
            defer { start += length }
            return start..<(start + length)
        }
    }
}

struct PomodoroCycleGrid<Content: View>: View {
    let count: Int
    @ViewBuilder let content: (Int, CGFloat) -> Content

    var body: some View {
        let layout = PomodoroCycleLayout(count: count)
        VStack(spacing: layout.spacing) {
            ForEach(layout.rows.indices, id: \.self) { row in
                HStack(spacing: layout.spacing) {
                    ForEach(layout.rows[row], id: \.self) { index in
                        content(index, layout.diameter)
                    }
                }
            }
        }
    }
}
