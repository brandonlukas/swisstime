import SwiftUI
import UIKit

// Color(light:dark:) and the workout Palette live in Shared/Palette.swift —
// the widget draws with the same swatches.

// paper, ink, tileDry, tileGrout, and gold live in Shared/Palette.swift —
// the widget renders with them, and the home screen must never drift.

extension Color {
    /// Matte cards: brighter cool white / elevated navy.
    static let paperCardFill = Color(light: Color(red: 0.969, green: 0.978, blue: 0.992),
                                     dark: Color(red: 0.118, green: 0.145, blue: 0.259))
    /// Legible on an ink fill in either mode.
    static let onInk = Color(light: .white,
                             dark: Color(red: 0.063, green: 0.082, blue: 0.157))
    /// Shadows are cast, not lit: never let ink-turned-pale glow under a card.
    static let shade = Color(light: Color(red: 0.075, green: 0.13, blue: 0.28),
                             dark: .black)
    /// The ambient light pooled on the page behind content.
    static let pageLight = Color(light: Color.white.opacity(0.38),
                                 dark: Color.white.opacity(0.05))
    /// Lifeguard red, destructive actions only. One shade deeper in the
    /// light than it once was — 4.8:1, legible at any size.
    static let signalRed = Color(light: Color(red: 0.75, green: 0.20, blue: 0.19),
                                 dark: Color(red: 0.93, green: 0.43, blue: 0.41))
    /// The poster accent for index numbers and tags: an accessible indigo
    /// by day (4.6:1 on paper — the airy original read at only 2.5:1),
    /// still the airy periwinkle after dark, where it clears 8:1.
    static let periwinkle = Color(light: Color(red: 0.333, green: 0.376, blue: 0.769),
                                  dark: Color(red: 0.64, green: 0.69, blue: 0.98))

    /// Pool scene colors. At night the water dims only a little — a lit
    /// pool after dark glows against its deck; that glow IS the dark mode.
    static let poolWater = Color(light: Color(red: 0.17, green: 0.45, blue: 0.79),
                                 dark: Color(red: 0.10, green: 0.37, blue: 0.72))
    static let poolWaterDeep = Color(light: Color(red: 0.08, green: 0.27, blue: 0.57),
                                     dark: Color(red: 0.04, green: 0.20, blue: 0.45))

    /// Fixed dark for toy eyes, bills, and moldings — vinyl doesn't adapt.
    static let toyInk = Color(red: 0.075, green: 0.13, blue: 0.28)

    /// Toy vinyl.
    static let duckYellow = Color(red: 1.0, green: 0.80, blue: 0.20)
    static let duckShade = Color(red: 0.93, green: 0.68, blue: 0.12)
    static let duckBeak = Color(red: 0.96, green: 0.48, blue: 0.16)
    static let ballRed = Color(red: 0.90, green: 0.30, blue: 0.26)
    static let ballBlue = Color(red: 0.16, green: 0.42, blue: 0.78)
    static let ballYellow = Color(red: 0.98, green: 0.77, blue: 0.22)
    static let orcaDark = Color(red: 0.10, green: 0.13, blue: 0.20)
    static let flamingoPink = Color(red: 0.96, green: 0.56, blue: 0.63)
    static let flamingoDeep = Color(red: 0.87, green: 0.42, blue: 0.52)

    /// The gilded colorway — the rare pull. (`gold` itself is shared.)
    static let goldDeep = Color(red: 0.72, green: 0.55, blue: 0.22)
    static let pearl = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let pearlShade = Color(red: 0.87, green: 0.84, blue: 0.76)

    /// Cool fill for plain sheet rows.
    static let card = Color(light: Color(red: 0.878, green: 0.902, blue: 0.933),
                            dark: Color(red: 0.145, green: 0.176, blue: 0.298))
    static let fieldBorder = Color.inkOpacity(0.22, highContrast: 0.50)
    static let hairline = Color.inkOpacity(0.10, highContrast: 0.25)
    /// Captions and supporting text — replaces SwiftUI's .secondary so the
    /// opacity is ours to guarantee: 66% ink clears 4.5:1 on light paper
    /// (60% fell just short at 4.05).
    static let inkSecondary = Color.inkOpacity(0.66, highContrast: 0.78)

}

extension Workout {
    var palette: PaletteColor {
        Palette.color(colorIndex)
    }
}

/// Dynamic Type: all app text is set through these modifiers, whose
/// @ScaledMetric tracks the user's text size. Body text rides the .body
/// curve (up to ~3× at the top accessibility size); display faces — poster
/// titles, timer numerals — ride .largeTitle's gentler curve (~1.6×), so a
/// clock face grows meaningfully without swallowing its screen.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var scale: CGFloat
    let size: CGFloat
    let weight: Font.Weight
    let expanded: Bool

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle,
         expanded: Bool = false) {
        // Scale a 100 pt reference, not 1 pt: the metrics round to whole
        // points, and at 1 pt that rounding flattens every size step
        // within ±20% of the default back to no-op.
        _scale = ScaledMetric(wrappedValue: 100, relativeTo: style)
        self.size = size
        self.weight = weight
        self.expanded = expanded
    }

    func body(content: Content) -> some View {
        let font: Font = .system(size: size * scale / 100, weight: weight)
        content.font(expanded ? font.width(.expanded) : font)
    }
}

/// Poster type: expanded, heavy, uppercase, tracked out — kerning scales
/// with the glyphs so the tracking holds at every size.
private struct DisplayType: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 100
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .kerning(size * scale / 100 * 0.05)
            .font(.system(size: size * scale / 100, weight: weight).width(.expanded))
            .textCase(.uppercase)
    }
}

/// Small tracked tag — index numbers, month labels, section overlines.
private struct OverlineType: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 100
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content
            .kerning(1.5 * scale / 100)
            .font(.system(size: size * scale / 100, weight: weight))
            .monospacedDigit()
            .textCase(.uppercase)
    }
}

extension View {
    /// SF Pro on the .body curve — text, controls, captions.
    func appFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: .body))
    }

    /// Big readouts (timer numerals) on the damped .largeTitle curve.
    func readoutFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: .largeTitle))
    }

    /// Poster type: expanded, heavy, uppercase, tracked out.
    func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> some View {
        modifier(DisplayType(size: size, weight: weight))
    }

    /// Small tracked tag — index numbers, month labels.
    func overline(_ size: CGFloat = 12, _ weight: Font.Weight = .semibold) -> some View {
        modifier(OverlineType(size: size, weight: weight))
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

// MARK: - Deck surfaces

/// Ambient backdrop: cool poolside light on a pale ground, textured with
/// static grain so it reads as a photograph, not a fill.
struct PaperBackground: View {
    var body: some View {
        ZStack {
            Color.paper
            RadialGradient(
                colors: [Color.pageLight, .clear],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0, endRadius: 460
            )
        }
        .overlay(GrainOverlay())
        .ignoresSafeArea()
    }
}

/// Static tiled noise — kills gradient banding and adds the film-photo grain.
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

/// One seamlessly tiling cell of wavy tile grout: three tiles per side, the
/// wobble's period matched to the image so the refraction never shows a seam.
/// Alpha-only white — tint it through `TileGridImage`.
enum TileGrid {
    static let tile: CGFloat = 44
    private static let cells = 3

    static let image: UIImage = {
        let side = tile * CGFloat(cells)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.4)
            let phases: [CGFloat] = [0, 2.1, 4.4]
            let step: CGFloat = 4
            // Verticals wave in y, horizontals in x; line 3 repeats line 0's
            // phase so the pattern closes across the tile edge.
            for line in 0...cells {
                let x = CGFloat(line) * tile
                let phase = phases[line % cells]
                var y: CGFloat = 0
                context.move(to: CGPoint(x: x + 1.6 * sin(phase), y: 0))
                while y < side {
                    y += step
                    context.addLine(to: CGPoint(
                        x: x + 1.6 * sin(2 * .pi * y / side + phase), y: y))
                }
            }
            for line in 0...cells {
                let y = CGFloat(line) * tile
                let phase = phases[line % cells] + 1.0
                var x: CGFloat = 0
                context.move(to: CGPoint(x: 0, y: y + 1.6 * sin(phase)))
                while x < side {
                    x += step
                    context.addLine(to: CGPoint(
                        x: x, y: y + 1.6 * sin(2 * .pi * x / side + phase)))
                }
            }
            context.strokePath()
        }
        return image.withRenderingMode(.alwaysTemplate)
    }()
}

/// The tiling grout grid, tinted. Layer a light copy and a nudged dark copy
/// for embossed tile joints on any water color.
struct TileGridImage: View {
    let tint: Color
    let opacity: Double

    var body: some View {
        Image(uiImage: TileGrid.image)
            .resizable(resizingMode: .tile)
            .foregroundStyle(tint)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

/// The player's pool water: the workout's swatch over a sunken tile grid,
/// with slow drifting caustic light. Rendered full-size at fixed geometry on
/// a slow clock; PlayerView reveals it up to the waterline with a soft-edged
/// moving mask, so the expensive blurs stay off the per-frame path.
struct WaterFill: View, Equatable {
    let color: Color
    let time: TimeInterval

    var body: some View {
        GeometryReader { geo in
            ZStack {
                color
                // The pool floor: embossed grout under the water color.
                TileGridImage(tint: .black, opacity: 0.10)
                    .offset(x: 1.5, y: 1.5)
                TileGridImage(tint: .white, opacity: 0.13)
                Ellipse()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: geo.size.width * 1.1,
                           height: max(80, geo.size.height * 0.5))
                    .blur(radius: 36)
                    .offset(x: sin(time / 19) * 46,
                            y: geo.size.height * 0.28 + cos(time / 23) * 30)
                Ellipse()
                    .fill(Color.white.opacity(0.09))
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

/// Drives a level (waterline, progress bar) with two regimes: while the
/// target creeps with ordinary passage of time it is tracked EXACTLY —
/// linear and truthful — but a discontinuity (new step, skip, finish)
/// engages a spring so the level moves like something with mass instead
/// of snapping. A plain reference — advanced once per timeline frame,
/// its mutations must not invalidate views.
final class LevelSpring {
    private var value: Double = 0
    private var velocity: Double = 0
    private var lastTime: Date?
    private var springing = false

    func advance(toward target: Double, at now: Date) -> Double {
        // First frame adopts the target outright — the player opens with
        // the level already where it belongs, no entrance animation.
        guard let last = lastTime else {
            lastTime = now
            value = target
            return value
        }
        // Clamped dt keeps the integration stable across dropped frames
        // and prevents a lurch when the timeline resumes after a pause.
        let dt = min(0.1, max(0, now.timeIntervalSince(last)))
        lastTime = now
        // Continuous motion moves well under this between frames; a gap
        // this large in one frame means the target jumped.
        if abs(target - value) > 0.02 { springing = true }
        guard springing else {
            value = target
            return value
        }
        // Slightly underdamped — the water settles with a small swell.
        // Fixed substeps keep the trajectory true when frames drop: one
        // big Euler step through a hitch would leap straight to the target
        // and read as a snap instead of a fill.
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            remaining -= h
            velocity += (-90 * (value - target) - 14 * velocity) * h
            value += velocity * h
        }
        if abs(value - target) < 0.0005, abs(velocity) < 0.005 {
            value = target
            velocity = 0
            springing = false
        }
        return value
    }
}

extension View {
    /// A matte card: cool white, faint edge, soft feathered shadow.
    /// Slightly translucent variants let the player's rising water read through.
    func paperCard(_ radius: CGFloat = 18, opacity: Double = 1) -> some View {
        self
            .background(Color.paperCardFill.opacity(opacity),
                        in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.ink.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: Color.shade.opacity(0.08), radius: 10, y: 4)
    }

    /// Solid ink button surface, matching the cards' curvature.
    func inkButton(_ fill: Color, radius: CGFloat = 14) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.shade.opacity(0.10), radius: 6, y: 2)
    }

    /// The text field focus stroke: ink while focused, a quiet hairline
    /// otherwise. Shared by every bordered field in the app.
    func fieldBorder(focused: Bool, radius: CGFloat = 10) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(focused ? Color.ink : Color.fieldBorder, lineWidth: 1)
        )
    }
}

/// Primary-action feedback: the button visibly sinks the moment the touch
/// lands, so the beat before a presentation or state change never reads as
/// a dead tap.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Mirrors the system's Low Power Mode so the ambient water can step down
/// with it — slower pool clocks, a coarser texture beat — without the app
/// growing a settings switch. The setting is the situation.
@MainActor
final class PowerState: ObservableObject {
    static let shared = PowerState()

    @Published private(set) var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private init() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
    }
}

/// One-shot latches for command-line UI verification hooks, so a debug launch
/// argument fires once instead of on every reappearance of the view.
enum DebugLaunch {
    static var didAutoPlay = false
    static var didAutoOpen = false
    static var didAutoEdit = false
    static var didAutoOpenPond = false
    static var didAutoOpenSettings = false
    static var didAutoAddItem = false
    static var didAutoEditWorkout = false
    static var didAutoMarkDone = false
    static var didAutoStartSets = false
    static var didAutoAdvance = false
    static var didAutoAdopt = false
    static var didAutoPickIcon = false
    static var didAutoStartUntimed = false
    static var didAutoFinishUntimed = false
    static var didAutoDismissCeremony = false
    static var didPondFlip = false
    static var didAutoImport = false
    static var didAutoImportLink = false
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

    /// "3 exercises · 15 min"
    static func summary(count: Int, duration: TimeInterval) -> String {
        let minutes = Int((duration / 60).rounded(.up))
        return "\(count) exercise\(count == 1 ? "" : "s") · \(minutes) min"
    }

    /// "4 exercises · 13 sets"
    static func setsSummary(count: Int, sets: Int) -> String {
        "\(count) exercise\(count == 1 ? "" : "s") · \(sets) set\(sets == 1 ? "" : "s")"
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
