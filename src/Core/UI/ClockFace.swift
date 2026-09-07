import AppKit
import SwiftUI

struct ClockFace: View {
    private static let image = loadImage(named: "clock")

    var body: some View {
        if let image = Self.image {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .foregroundStyle(.white.opacity(0.42))
                .allowsHitTesting(false)
        }
    }
}

struct ClockHands: View {
    let date: Date

    private static let hourImage = loadImage(named: "hour")
    private static let minuteImage = loadImage(named: "minute")

    private var time: DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    private var minuteAngle: Double {
        Double(time.minute ?? 0) * 6
    }

    private var hourAngle: Double {
        let hour = Double((time.hour ?? 0) % 12)
        let minute = Double(time.minute ?? 0)
        return (hour + minute / 60) * 30
    }

    var body: some View {
        ZStack {
            if let hourImage = Self.hourImage {
                Image(nsImage: hourImage)
                    .renderingMode(.template)
                    .resizable()
                    .rotationEffect(.degrees(hourAngle))
            }

            if let minuteImage = Self.minuteImage {
                Image(nsImage: minuteImage)
                    .renderingMode(.template)
                    .resizable()
                    .rotationEffect(.degrees(minuteAngle))
            }

            Circle()
                .frame(width: 7, height: 7)
        }
    }
}

private func loadImage(named name: String) -> NSImage? {
    guard let url = Bundle.module.url(forResource: name, withExtension: "svg") else { return nil }
    return NSImage(contentsOf: url)
}
