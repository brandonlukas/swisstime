import SwiftUI
import UIKit

extension Color {
    /// Warm cream ground behind every screen.
    static let paper = Color(red: 0.949, green: 0.937, blue: 0.906)
    /// Slightly brighter warm white for matte cards.
    static let paperCardFill = Color(red: 0.984, green: 0.973, blue: 0.949)
    /// Warm indigo-charcoal — the app's "black" for text, buttons, rules.
    static let ink = Color(red: 0.16, green: 0.19, blue: 0.23)
    /// Muted brick for destructive actions.
    static let brick = Color(red: 0.70, green: 0.30, blue: 0.24)

    /// Pond scene colors.
    static let pondWater = Color(red: 0.227, green: 0.333, blue: 0.439)
    static let pondWaterDeep = Color(red: 0.165, green: 0.251, blue: 0.345)
    static let reedGreen = Color(red: 0.42, green: 0.47, blue: 0.31)
    static let cattail = Color(red: 0.42, green: 0.29, blue: 0.19)
    static let beakOchre = Color(red: 0.85, green: 0.60, blue: 0.24)

    /// Warm fill for plain sheet rows.
    static let card = Color(red: 0.93, green: 0.915, blue: 0.88)
    static let fieldBorder = Color.ink.opacity(0.22)
    static let hairline = Color.ink.opacity(0.10)
}

/// What swims in for a finished workout of this color.
enum CreatureKind {
    case drake, hen, duckling, goose, koi, shadowFish
}

struct PaletteColor {
    let name: String
    let fill: Color
    /// Legible ink on top of `fill` — the light fills need black.
    let onFill: Color
    let creature: CreatureKind
}

/// Muted natural swatches, each tied to a pond creature. Indices are stable —
/// pre-pond files decode and simply adopt the quieter colors. Every fill must
/// survive full-screen in the player with legible text on matte cards over it.
enum Palette {
    static let all: [PaletteColor] = [
        PaletteColor(name: "Reed",
                     fill: Color(red: 0.47, green: 0.51, blue: 0.33), onFill: .white,
                     creature: .drake),
        PaletteColor(name: "Pond",
                     fill: Color(red: 0.227, green: 0.333, blue: 0.439), onFill: .white,
                     creature: .shadowFish),
        PaletteColor(name: "Ochre",
                     fill: Color(red: 0.78, green: 0.59, blue: 0.28), onFill: .black,
                     creature: .duckling),
        PaletteColor(name: "Clay",
                     fill: Color(red: 0.66, green: 0.39, blue: 0.26), onFill: .white,
                     creature: .koi),
        PaletteColor(name: "Mist",
                     fill: Color(red: 0.55, green: 0.63, blue: 0.68), onFill: .black,
                     creature: .goose),
        PaletteColor(name: "Cattail",
                     fill: Color(red: 0.48, green: 0.36, blue: 0.26), onFill: .white,
                     creature: .hen),
    ]

    static func color(_ index: Int?) -> PaletteColor {
        all[(index ?? 0) % all.count]
    }

    static func creature(for index: Int?) -> CreatureKind {
        color(index).creature
    }
}

extension Workout {
    var palette: PaletteColor {
        Palette.color(colorIndex)
    }
}

extension Font {
    /// SF Pro — body, controls, and timer numerals.
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    /// New York — titles, month labels, headlines. The storybook voice.
    static func serifApp(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// The soft rule under page titles.
struct InkRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.ink.opacity(0.3))
            .frame(height: 1)
    }
}

// MARK: - Paper surfaces

/// Ambient backdrop: warm cream paper with a barely-there pool of light,
/// textured with static grain.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Color.paper
            RadialGradient(
                colors: [Color.white.opacity(0.35), .clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0, endRadius: 460
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

/// The player's pond water: the workout's swatch with slow drifting
/// cloud-shadows. Rendered full-size at fixed geometry on a slow clock;
/// PlayerView reveals it up to the waterline with a soft-edged moving mask,
/// so the expensive blurs stay off the per-frame path.
struct WaterFill: View, Equatable {
    let color: Color
    let time: TimeInterval

    var body: some View {
        GeometryReader { geo in
            ZStack {
                color
                Ellipse()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: geo.size.width * 1.1,
                           height: max(80, geo.size.height * 0.5))
                    .blur(radius: 36)
                    .offset(x: sin(time / 19) * 46,
                            y: geo.size.height * 0.28 + cos(time / 23) * 30)
                Ellipse()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: geo.size.width * 0.8,
                           height: max(60, geo.size.height * 0.4))
                    .blur(radius: 32)
                    .offset(x: cos(time / 17) * 52,
                            y: -geo.size.height * 0.12 + sin(time / 13) * 24)
            }
            // Flatten the big blurs into one Metal pass; with fixed geometry
            // and a slow clock the texture re-renders only a few times a second.
            .drawingGroup()
        }
        .clipped()
    }
}

extension View {
    /// A matte paper card: warm white, faint edge, soft feathered shadow.
    /// Slightly translucent variants let the player's rising water read through.
    func paperCard(_ radius: CGFloat = 18, opacity: Double = 1) -> some View {
        self
            .background(Color.paperCardFill.opacity(opacity),
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.ink.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.ink.opacity(0.08), radius: 10, y: 4)
    }

    /// Solid ink button surface, matching the paper cards' curvature.
    func inkButton(_ fill: Color, radius: CGFloat = 14) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.ink.opacity(0.10), radius: 6, y: 2)
    }
}

/// One-shot latches for command-line UI verification hooks, so a debug launch
/// argument fires once instead of on every reappearance of the view.
enum DebugLaunch {
    static var didAutoPlay = false
    static var didAutoOpen = false
    static var didAutoEdit = false
    static var didAutoOpenPond = false
    static var didAutoAddItem = false
    static var didAutoEditWorkout = false
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Format {
    /// "15:00", "1:00", "0:05"
    static func mmss(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.down))
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
