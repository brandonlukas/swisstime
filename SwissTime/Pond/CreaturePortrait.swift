import SwiftUI

/// A small pond cross-section introducing one creature in profile: birds
/// float on the waterline, fish hang below it. Same flat picture-book
/// language as the top-down pond art, but posed like a character portrait.
/// Motion is a pure function of time — a slow bob, a breath, a blink.
struct CreaturePortrait: View {
    let kind: CreatureKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            // A frozen mid-bob pose with eyes open (no blink lands at t = 1).
            portrait(at: 1.0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                portrait(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func portrait(at t: TimeInterval) -> some View {
        Canvas { context, size in
            CreatureProfileArt.draw(kind: kind, in: context, size: size, time: t)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.fieldBorder, lineWidth: 1)
        )
    }
}

extension CreatureKind {
    /// The color picker's one-line promise of who this color invites.
    var pickerLine: String {
        switch self {
        case .drake: return "A drake glides in when you finish this."
        case .hen: return "A hen dabbles in when you finish this."
        case .duckling: return "A duckling paddles in when you finish this."
        case .goose: return "A goose sails in when you finish this."
        case .koi: return "A koi settles in when you finish this."
        case .shadowFish: return "A shadow fish slips in below the surface."
        }
    }
}

/// Side-profile drawings, all facing right. Local space: origin at the
/// waterline under the creature's center; +y down into the water. Designed
/// against a 76 × 52 tile with the waterline at 42% — birds must stay under
/// 19 pt of air, fish within 24 pt of water.
enum CreatureProfileArt {
    /// Desynchronizes bob, blink, and ripple between kinds so two portraits
    /// seen in a row don't move in lockstep.
    private static func phase(_ kind: CreatureKind) -> Double {
        switch kind {
        case .drake: return 0
        case .hen: return 1.3
        case .duckling: return 2.2
        case .goose: return 3.1
        case .koi: return 0.7
        case .shadowFish: return 2.6
        }
    }

    static func draw(kind: CreatureKind, in context: GraphicsContext,
                     size: CGSize, time t: Double) {
        let waterline = size.height * 0.42
        let waterRect = CGRect(x: 0, y: waterline,
                               width: size.width, height: size.height - waterline)

        // Water darkening with depth; the air above stays paper.
        context.fill(Path(waterRect), with: .linearGradient(
            Gradient(colors: [.pondWater, .pondWaterDeep]),
            startPoint: CGPoint(x: 0, y: waterline),
            endPoint: CGPoint(x: 0, y: size.height)))

        // One drifting light patch so the water breathes even under a bird.
        let drift = sin(t / 9 + phase(kind)) * 6
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.58 + drift - 13,
                                   y: waterline + 5, width: 26, height: 9)),
            with: .color(.white.opacity(0.06)))

        var scene = context
        scene.translateBy(x: size.width * 0.5, y: waterline)
        let s = min(size.width / 76, size.height / 52)
        scene.scaleBy(x: s, y: s)

        switch kind {
        case .koi, .shadowFish:
            drawFish(kind: kind, in: scene, t: t)
        case .duckling:
            drawRipple(in: scene, t: t, seed: phase(kind))
            drawDuckling(in: scene, t: t)
        case .goose:
            drawRipple(in: scene, t: t, seed: phase(kind))
            drawGoose(in: scene, t: t)
        case .drake, .hen:
            drawRipple(in: scene, t: t, seed: phase(kind))
            drawDabbler(kind: kind, in: scene, t: t)
        }

        // Birds' bellies sit in the water — re-cover the band translucently
        // so the submerged part reads dimmed, then rule the waterline on top.
        if kind != .koi && kind != .shadowFish {
            context.fill(Path(waterRect), with: .color(.pondWater.opacity(0.55)))
        }
        var line = Path()
        line.move(to: CGPoint(x: 0, y: waterline))
        line.addLine(to: CGPoint(x: size.width, y: waterline))
        context.stroke(line, with: .color(.white.opacity(0.28)), lineWidth: 1)

        drawGrain(in: context, over: waterRect)
    }

    // MARK: - Shared idle motion

    /// Applies the float: a slow bob plus a barely-there breath scaled about
    /// the body's center. Returns the transformed context to draw the bird in.
    private static func floating(_ context: GraphicsContext, t: Double,
                                 seed: Double) -> GraphicsContext {
        var c = context
        // +2.2 sinks the hull properly — a duck floats low, not perched.
        c.translateBy(x: 0, y: 2.2 + sin(t * 1.15 + seed) * 0.9)
        let breath = 1 + 0.018 * sin(t * 2.1 + seed)
        c.translateBy(x: 0, y: -5)
        c.scaleBy(x: 1, y: breath)
        c.translateBy(x: 0, y: 5)
        return c
    }

    /// A dot eye that closes to a slit for a beat every few seconds.
    private static func drawEye(in context: GraphicsContext, at point: CGPoint,
                                color: Color, t: Double, seed: Double,
                                diameter: CGFloat = 2.3) {
        let cycle = (t + seed * 2).truncatingRemainder(dividingBy: 4.4)
        let height: CGFloat = cycle < 0.14 ? diameter * 0.3 : diameter
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - height / 2,
                                   width: diameter, height: height)),
            with: .color(color))
    }

    /// A flattened ring spreading from the floating bird now and then.
    private static func drawRipple(in context: GraphicsContext, t: Double, seed: Double) {
        let cycle = (t + seed).truncatingRemainder(dividingBy: 4.6)
        guard cycle < 2.4 else { return }
        let k = cycle / 2.4
        let width = 30 + 26 * k
        context.stroke(
            Path(ellipseIn: CGRect(x: -width / 2 + 2, y: -2.5, width: width, height: 5)),
            with: .color(.white.opacity(0.20 * (1 - k))),
            lineWidth: 1)
    }

    // MARK: - Birds

    /// Drake and hen: the standard duck, light head held over the chest.
    private static func drawDabbler(kind: CreatureKind, in context: GraphicsContext,
                                    t: Double) {
        guard let style = PondCreatureArt.birdStyle(for: kind) else { return }
        let seed = phase(kind)
        var c = floating(context, t: t, seed: seed)

        var tail = Path()
        tail.move(to: CGPoint(x: -10, y: -6))
        tail.addLine(to: CGPoint(x: -17, y: -11))
        tail.addLine(to: CGPoint(x: -8.5, y: -2.5))
        tail.closeSubpath()
        c.fill(tail, with: .color(style.shade))

        let body = Path(ellipseIn: CGRect(x: -14, y: -11, width: 27, height: 13))
        c.fill(body, with: .color(style.body))
        var belly = c
        belly.clip(to: body)
        belly.fill(Path(CGRect(x: -14, y: -3, width: 27, height: 5)),
                   with: .color(style.shade))

        // The drake's top-down wing tone vanishes against its white body in
        // profile — deepen it just enough to read as a folded wing.
        let wing = kind == .drake
            ? Color(red: 0.85, green: 0.83, blue: 0.77) : style.wing
        c.fill(Path(ellipseIn: CGRect(x: -9, y: -9, width: 14, height: 8)),
               with: .color(wing))
        if style.speckled {
            for spot in [CGPoint(x: -4, y: -6), CGPoint(x: 1, y: -4.2), CGPoint(x: -8, y: -4.5)] {
                c.fill(Path(ellipseIn: CGRect(x: spot.x, y: spot.y, width: 1.8, height: 1.8)),
                       with: .color(style.wing.opacity(0.9)))
            }
        }

        var neck = Path()
        neck.move(to: CGPoint(x: 7, y: -5))
        neck.addLine(to: CGPoint(x: 10, y: -14))
        c.stroke(neck, with: .color(style.body),
                 style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 5.1, y: -19.9, width: 9.8, height: 9.8)),
               with: .color(style.shade))
        c.fill(Path(ellipseIn: CGRect(x: 5.7, y: -19.3, width: 8.6, height: 8.6)),
               with: .color(style.body))

        var beak = Path()
        beak.move(to: CGPoint(x: 14, y: -16.6))
        beak.addLine(to: CGPoint(x: 19.3, y: -14.9))
        beak.addLine(to: CGPoint(x: 14, y: -13.2))
        beak.closeSubpath()
        c.fill(beak, with: .color(style.beak))

        drawEye(in: c, at: CGPoint(x: 11.3, y: -16), color: .ink, t: t, seed: seed)
    }

    /// Baby proportions: round body, oversized head, stub of a tail.
    private static func drawDuckling(in context: GraphicsContext, t: Double) {
        guard let style = PondCreatureArt.birdStyle(for: .duckling) else { return }
        let seed = phase(.duckling)
        var c = floating(context, t: t, seed: seed)
        c.scaleBy(x: 0.85, y: 0.85)

        var tail = Path()
        tail.move(to: CGPoint(x: -8, y: -5))
        tail.addLine(to: CGPoint(x: -13, y: -8.5))
        tail.addLine(to: CGPoint(x: -7, y: -2))
        tail.closeSubpath()
        c.fill(tail, with: .color(style.shade))

        let body = Path(ellipseIn: CGRect(x: -11, y: -9, width: 21, height: 10.5))
        c.fill(body, with: .color(style.body))
        var belly = c
        belly.clip(to: body)
        belly.fill(Path(CGRect(x: -11, y: -2.5, width: 21, height: 4)),
                   with: .color(style.shade))
        c.fill(Path(ellipseIn: CGRect(x: -7, y: -7.5, width: 10, height: 6)),
               with: .color(style.wing))

        c.fill(Path(ellipseIn: CGRect(x: 2.4, y: -16.1, width: 9.2, height: 9.2)),
               with: .color(style.body))
        var beak = Path()
        beak.move(to: CGPoint(x: 11, y: -12.7))
        beak.addLine(to: CGPoint(x: 14.6, y: -11.4))
        beak.addLine(to: CGPoint(x: 11, y: -10.1))
        beak.closeSubpath()
        c.fill(beak, with: .color(style.beak))

        drawEye(in: c, at: CGPoint(x: 8.3, y: -12.5), color: .ink, t: t, seed: seed)
    }

    /// Canada goose: long dark neck, white chinstrap, dark bill.
    private static func drawGoose(in context: GraphicsContext, t: Double) {
        guard let style = PondCreatureArt.birdStyle(for: .goose) else { return }
        let seed = phase(.goose)
        var c = floating(context, t: t, seed: seed)
        // Rides a touch higher than the ducks or the pale body drowns.
        c.translateBy(x: 0, y: -1.2)
        let dark = PondCreatureArt.gooseDark

        // Tail in wing-tone: darker than body-shade for contrast against
        // the paper, but not the neck's near-black antenna.
        var tail = Path()
        tail.move(to: CGPoint(x: -10.5, y: -8))
        tail.addLine(to: CGPoint(x: -17.5, y: -11))
        tail.addLine(to: CGPoint(x: -8, y: -2.5))
        tail.closeSubpath()
        c.fill(tail, with: .color(style.wing))

        let body = Path(ellipseIn: CGRect(x: -15, y: -11, width: 29, height: 13))
        c.fill(body, with: .color(style.body))
        var belly = c
        belly.clip(to: body)
        belly.fill(Path(CGRect(x: -15, y: -3, width: 29, height: 5)),
                   with: .color(style.shade))
        c.fill(Path(ellipseIn: CGRect(x: -10, y: -9, width: 15, height: 8)),
               with: .color(style.wing))

        var neck = Path()
        neck.move(to: CGPoint(x: 7, y: -5))
        neck.addLine(to: CGPoint(x: 10.5, y: -15.5))
        c.stroke(neck, with: .color(dark),
                 style: StrokeStyle(lineWidth: 4.6, lineCap: .round))
        let head = Path(ellipseIn: CGRect(x: 6.5, y: -20.5, width: 8, height: 8))
        c.fill(head, with: .color(dark))
        // Chinstrap clipped to the head: a white crescent hugging the jaw,
        // clearly apart from the (smaller) eye so they don't read as a pair
        // of eyes at this size.
        var cheek = c
        cheek.clip(to: head)
        cheek.fill(Path(ellipseIn: CGRect(x: 10.2, y: -15.4, width: 4.6, height: 3.4)),
                   with: .color(.white.opacity(0.92)))

        var beak = Path()
        beak.move(to: CGPoint(x: 14.2, y: -18.1))
        beak.addLine(to: CGPoint(x: 19.2, y: -16.4))
        beak.addLine(to: CGPoint(x: 14.2, y: -14.7))
        beak.closeSubpath()
        c.fill(beak, with: .color(dark))

        drawEye(in: c, at: CGPoint(x: 11.8, y: -18.2),
                color: .white.opacity(0.85), t: t, seed: seed, diameter: 1.8)
    }

    // MARK: - Fish

    private static func drawFish(kind: CreatureKind, in context: GraphicsContext,
                                 t: Double) {
        let seed = phase(kind)
        let bodyColor = kind == .koi
            ? Color(red: 0.69, green: 0.41, blue: 0.30)
            : Color(red: 0.13, green: 0.19, blue: 0.25)

        var c = context
        c.opacity = kind == .koi ? 0.95 : 0.88
        c.translateBy(x: 0, y: 13 + sin(t * 0.85 + seed) * 1.3)
        c.rotate(by: .degrees(sin(t * 0.6 + seed) * 2.5))

        // Tail swings around the body's rear joint.
        var tail = c
        tail.translateBy(x: -11, y: 0)
        tail.rotate(by: .degrees(sin(t * 2.7 + seed) * 13))
        var fin = Path()
        fin.move(to: CGPoint(x: 0, y: 0))
        fin.addLine(to: CGPoint(x: -9, y: -5.5))
        fin.addLine(to: CGPoint(x: -9, y: 5.5))
        fin.closeSubpath()
        tail.fill(fin, with: .color(bodyColor))

        var dorsal = Path()
        dorsal.move(to: CGPoint(x: -5, y: -5.3))
        dorsal.addLine(to: CGPoint(x: 0, y: -9.3))
        dorsal.addLine(to: CGPoint(x: 4, y: -5.3))
        dorsal.closeSubpath()
        c.fill(dorsal, with: .color(bodyColor))

        let body = Path(ellipseIn: CGRect(x: -13, y: -6, width: 25, height: 12))
        c.fill(body, with: .color(bodyColor))
        var belly = c
        belly.clip(to: body)
        belly.fill(Path(CGRect(x: -13, y: 2, width: 25, height: 4)),
                   with: .color(.white.opacity(kind == .koi ? 0.30 : 0.10)))

        if kind == .koi {
            c.fill(Path(ellipseIn: CGRect(x: -1, y: -5.5, width: 8, height: 6)),
                   with: .color(Color(red: 0.88, green: 0.79, blue: 0.66).opacity(0.85)))
            c.fill(Path(ellipseIn: CGRect(x: -8.5, y: -2, width: 4.5, height: 4)),
                   with: .color(Color(red: 0.88, green: 0.79, blue: 0.66).opacity(0.6)))
        }

        // Pectoral fin sculling below the midline.
        var pectoral = c
        pectoral.translateBy(x: 3, y: 1.5)
        pectoral.rotate(by: .degrees(24 + sin(t * 2.7 + seed + 1) * 8))
        pectoral.fill(Path(ellipseIn: CGRect(x: -1, y: -1.5, width: 6.5, height: 3.2)),
                      with: .color(bodyColor))

        drawEye(in: c, at: CGPoint(x: 8.5, y: -1.8),
                color: kind == .koi ? .ink : .white.opacity(0.75), t: t, seed: seed)

        // A bubble wobbles up from the mouth toward the surface now and then.
        let cycle = (t + seed).truncatingRemainder(dividingBy: 5.5)
        if cycle < 1.6 {
            let k = cycle / 1.6
            c.stroke(
                Path(ellipseIn: CGRect(x: 12.5 + sin(k * 7) * 1.2 - 1,
                                       y: -3 - k * 14 - 1,
                                       width: 2 + k * 1.4, height: 2 + k * 1.4)),
                with: .color(.white.opacity(0.5 * (1 - k))),
                lineWidth: 0.8)
        }
    }

    /// The printed-page texture, over the water only — matching the pond.
    private static func drawGrain(in context: GraphicsContext, over rect: CGRect) {
        var c = context
        c.clip(to: Path(rect))
        c.blendMode = .overlay
        c.opacity = 0.12
        c.draw(Image(uiImage: Grain.image),
               in: CGRect(x: rect.minX, y: rect.minY, width: 128, height: 128))
    }
}
