import AppKit
import SwiftUI
import Testing
import Vision
@testable import Countdown

@MainActor
func render<V: View>(_ hosting: NSHostingView<V>, side: Double = 188) throws -> NSBitmapImageRep {
    hosting.wantsLayer = true
    hosting.layer?.backgroundColor = NSColor.clear.cgColor
    hosting.frame = NSRect(x: 0, y: 0, width: side, height: side)
    hosting.layoutSubtreeIfNeeded()
    let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
    bitmap.bitmapData?.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    return bitmap
}

@MainActor
func recognizedText(_ bitmap: NSBitmapImageRep) throws -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try VNImageRequestHandler(cgImage: #require(bitmap.cgImage)).perform([request])
    return request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
}

@MainActor
func sample(_ bitmap: NSBitmapImageRep, angle: Double, radius: Double = 0.35) throws -> NSColor {
    let radians = angle * .pi / 180
    let x = Int(Double(bitmap.pixelsWide) * (0.5 + radius * sin(radians)))
    let y = Int(Double(bitmap.pixelsHigh) * (0.5 - radius * cos(radians)))
    return try #require(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
}

