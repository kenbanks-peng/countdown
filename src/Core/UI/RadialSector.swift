import SwiftUI

struct RadialSector: Shape {
    let proportion: Double
    var startProportion: Double = 0

    func path(in rect: CGRect) -> Path {
        guard proportion > 0 else { return Path() }
        if proportion >= 1 { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle.degrees(-90 + 360 * startProportion)
        let end = Angle.degrees(-90 + 360 * (startProportion + proportion))
        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(
            x: center.x + radius * cos(start.radians),
            y: center.y + radius * sin(start.radians)
        ))
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}
