import CoreText
import SwiftUI

/// Remaining minutes, an alarm message, or a phase label on a transparent surface.
struct CountdownNotificationOverlay: View {
    let remaining: TimeInterval
    var alarmMessage: String? = nil
    var isRest = false
    var isWork = false
    var fontSizePt: CGFloat = CountdownConfiguration.defaultNotificationFontSizePt
    var fontName = ""
    var fontVariations = NotificationFontVariations()

    static func timeLabel(_ remaining: TimeInterval) -> String {
        String(Int(ceil(max(0, remaining) / 60)))
    }

    var label: String {
        isRest ? "REST" : isWork ? "WORK" : alarmMessage ?? Self.timeLabel(remaining)
    }

    var effectiveFontSizePt: CGFloat {
        fontSizePt * (isRest || isWork ? 0.8 : 1)
    }

    var body: some View {
        Canvas { context, size in
            // Construct the font with the configured variable-font axes.
            let font = NotificationFont.make(name: fontName, size: effectiveFontSizePt, variations: fontVariations)
            if alarmMessage != nil && !isRest && !isWork {
                // Shape user text with font fallback for non-ASCII characters.
                let line = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
                ]))
                let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
                context.withCGContext { graphics in
                    graphics.translateBy(x: (size.width - width) / 2,
                                         y: (size.height + CTFontGetAscent(font) - CTFontGetDescent(font)) / 2)
                    graphics.scaleBy(x: 1, y: -1)
                    graphics.setStrokeColor(CGColor(gray: 0, alpha: 0.85))
                    graphics.setLineWidth(2)
                    graphics.setLineJoin(.round)
                    graphics.setTextDrawingMode(.stroke)
                    graphics.textPosition = .zero
                    CTLineDraw(line, graphics)
                    graphics.setTextDrawingMode(.fill)
                    graphics.setFillColor(CGColor.white)
                    graphics.textPosition = .zero
                    CTLineDraw(line, graphics)
                }
                return
            }
            // Draw ASCII digits and phase text directly to avoid cached font weights.
            let characters = Array(label.utf16)
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
        .accessibilityLabel(isRest || isWork || alarmMessage != nil ? label : "\(label) minutes remaining")
    }
}
