import SwiftUI
import UIKit

extension Color {
    /// The single accent — the classic Swiss poster red.
    static let swissRed = Color(red: 0.89, green: 0.024, blue: 0.075)
    /// Flat light-gray fill, still used inside plain sheets.
    static let card = Color(white: 0.965)
    static let fieldBorder = Color(white: 0.85)
    static let hairline = Color.black.opacity(0.08)
}

extension Font {
    /// Helvetica — the Swiss typeface.
    static func swiss(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("HelveticaNeue", size: size).weight(weight)
    }
}

/// The black rule under page titles.
struct SwissRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.black)
            .frame(height: 1)
    }
}

// MARK: - Swiss glass

/// Ambient backdrop: a slowly drifting near-white mesh gradient with whispers
/// of red and cool gray in the corners, textured with static grain.
struct SwissGlassBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3, height: 3,
                points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, Float(0.5 + 0.10 * sin(t / 9))),
                    .init(Float(0.5 + 0.12 * sin(t / 11)), Float(0.5 + 0.10 * cos(t / 8))),
                    .init(1, Float(0.5 + 0.08 * cos(t / 7))),
                    .init(0, 1), .init(0.5, 1), .init(1, 1),
                ],
                colors: [
                    .white, Color(red: 0.99, green: 0.98, blue: 0.97), .white,
                    Color(red: 1.0, green: 0.93, blue: 0.92), .white,
                    Color(red: 0.93, green: 0.95, blue: 0.98),
                    Color(red: 0.96, green: 0.95, blue: 0.93),
                    Color(red: 1.0, green: 0.95, blue: 0.94), .white,
                ]
            )
        }
        .overlay(GrainOverlay())
        .ignoresSafeArea()
    }
}

/// Static tiled noise — kills gradient banding and reads as paper texture.
struct GrainOverlay: View {
    var body: some View {
        Image(uiImage: Grain.image)
            .resizable(resizingMode: .tile)
            .opacity(0.04)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

enum Grain {
    static let image: UIImage = {
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size)
        for index in pixels.indices {
            pixels[index] = UInt8.random(in: 0...255)
        }
        let cgImage = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(
                data: buffer.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }
            return context.makeImage()
        }
        return cgImage.map { UIImage(cgImage: $0) } ?? UIImage()
    }()
}

extension View {
    /// Sharp-cornered glass surface: square, frosted, with a faint light edge.
    func glassCard() -> some View {
        self
            .background(.regularMaterial)
            .overlay(Rectangle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Format {
    /// "15:00", "1:00", "0:05"
    static func mmss(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }

    /// "3 items · 15 min"
    static func summary(count: Int, duration: TimeInterval) -> String {
        let minutes = Int((duration / 60).rounded(.up))
        return "\(count) item\(count == 1 ? "" : "s") · \(minutes) min"
    }

    /// "With 16, Rest, and 20" / "With A, B, C, D, and more"
    static func withLine(_ names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        if names.count > 4 {
            return "With " + names.prefix(4).joined(separator: ", ") + ", and more"
        }
        if names.count == 1 { return "With \(names[0])" }
        if names.count == 2 { return "With \(names[0]) and \(names[1])" }
        return "With " + names.dropLast().joined(separator: ", ") + ", and \(names.last!)"
    }
}
