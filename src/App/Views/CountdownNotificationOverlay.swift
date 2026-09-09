import CoreText
import SwiftUI

/// Remaining focus/timer minutes or REST, centered on a transparent surface.
struct CountdownNotificationOverlay: View {
    let remaining: TimeInterval
    var isRest = false
    var fontSizePt: CGFloat = CountdownConfiguration.defaultNotificationFontSizePt
    var fontName = ""
    var fontVariations = NotificationFontVariations()

    static func timeLabel(_ remaining: TimeInterval) -> String {
        String(Int(ceil(max(0, remaining) / 60)))
    }

    var body: some View {
        Canvas { context, size in
            // The label contains only ASCII digits or REST. Draw its glyphs directly:
            // attributed text can reuse a named font's previously cached weight.
            let font = NotificationFont.make(name: fontName, size: fontSizePt, variations: fontVariations)
            let characters = Array((isRest ? "REST" : Self.timeLabel(remaining)).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
            var advances = [CGSize](repeating: .zero, count: glyphs.count)
            CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
            var width: CGFloat = 0
            let positions = advances.map { advance in
                defer { width += advance.width - 1 }
                return CGPoint(x: width, y: 0)
            }
            width += 1
            context.withCGContext { graphics in
                graphics.translateBy(x: (size.width - width) / 2,
                                     y: (size.height + CTFontGetAscent(font) - CTFontGetDescent(font)) / 2)
                graphics.scaleBy(x: 1, y: -1)
                // Draw the outline first so the white fill keeps its original weight.
                graphics.setStrokeColor(CGColor(gray: 0, alpha: 0.85))
                graphics.setLineWidth(2)
                graphics.setLineJoin(.round)
                graphics.setTextDrawingMode(.stroke)
                CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, graphics)
                graphics.setTextDrawingMode(.fill)
                graphics.setFillColor(CGColor.white)
                CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, graphics)
            }
        }
        .shadow(color: .black.opacity(0.7), radius: 2)
        .allowsHitTesting(false)
        .accessibilityLabel(isRest ? "REST" : "\(Self.timeLabel(remaining)) minutes remaining")
    }
}
