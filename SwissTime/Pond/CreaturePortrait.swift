import SwiftUI

/// A small pool cross-section introducing one toy in profile at the
/// waterline. Same flat vinyl language as the top-down pool art, but posed
/// like a catalog shot. Motion is a pure function of time — a slow bob,
/// a breath, a blink where there's an eye to blink.
struct ToyPortrait: View {
    let kind: ToyKind
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
            ToyProfileArt.draw(kind: kind, in: context, size: size, time: t)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.fieldBorder, lineWidth: 1)
        )
    }
}

extension ToyKind {
    /// "rubber duck" — for the ceremony lines.
    var displayName: String {
        switch self {
        case .duck: return "rubber duck"
        case .beachBall: return "beach ball"
        case .ring: return "swim ring"
        case .orca: return "orca floatie"
        case .flamingo: return "flamingo floatie"
        case .lilo: return "lilo"
        }
    }

    /// The color picker's one-line promise of what this color floats in.
    var pickerLine: String {
        switch self {
        case .duck: return "A rubber duck bobs in when you finish this."
        case .beachBall: return "A beach ball rolls in when you finish this."
        case .ring: return "A swim ring drifts in when you finish this."
        case .orca: return "An orca floatie cruises in when you finish this."
        case .flamingo: return "A flamingo floatie sails in when you finish this."
        case .lilo: return "A lilo glides in when you finish this."
        }
    }
}

/// Side-profile drawings, all facing right. Local space: origin at the
/// waterline under the toy's center; +y down into the water. Designed
/// against a 76 × 52 tile with the waterline at 42% — everything must stay
/// under 19 pt of air and within 24 pt of water.
enum ToyProfileArt {
    /// Desynchronizes bob, blink, and ripple between kinds so two portraits
    /// seen in a row don't move in lockstep.
    private static func phase(_ kind: ToyKind) -> Double {
        switch kind {
        case .duck: return 0
        case .beachBall: return 1.3
        case .ring: return 2.2
        case .orca: return 3.1
        case .flamingo: return 0.7
        case .lilo: return 2.6
        }
    }

    static func draw(kind: ToyKind, in context: GraphicsContext,
                     size: CGSize, time t: Double) {
        let waterline = size.height * 0.42
        let waterRect = CGRect(x: 0, y: waterline,
                               width: size.width, height: size.height - waterline)

        // Water darkening with depth; the air above stays deck-pale.
        context.fill(Path(waterRect), with: .linearGradient(
            Gradient(colors: [.poolWater, .poolWaterDeep]),
            startPoint: CGPoint(x: 0, y: waterline),
            endPoint: CGPoint(x: 0, y: size.height)))

        // The tile grid, refracted small, so even the swatch reads pool.
        var grid = Path()
        var x: CGFloat = -6
        while x < size.width {
            x += 13
            grid.move(to: CGPoint(x: x + 1.2 * sin(t * 0.5 + x / 9), y: waterline + 3))
            grid.addLine(to: CGPoint(x: x + 1.2 * sin(t * 0.5 + x / 9 + 1.6),
                                     y: size.height))
        }
        var y = waterline + 12
        while y < size.height {
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y + 1.2 * sin(t * 0.4 + y / 7)))
            y += 13
        }
        context.stroke(grid, with: .color(.white.opacity(0.10)), lineWidth: 1)

        // One drifting light patch so the water breathes even under a toy.
        let drift = sin(t / 9 + phase(kind)) * 6
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.58 + drift - 13,
                                   y: waterline + 5, width: 26, height: 9)),
            with: .color(.white.opacity(0.08)))

        var scene = context
        scene.translateBy(x: size.width * 0.5, y: waterline)
        let s = min(size.width / 76, size.height / 52)
        scene.scaleBy(x: s, y: s)

        drawRipple(in: scene, t: t, seed: phase(kind))
        switch kind {
        case .duck: drawDuck(in: scene, t: t)
        case .beachBall: drawBeachBall(in: scene, t: t)
        case .ring: drawRing(in: scene, t: t)
        case .orca: drawOrca(in: scene, t: t)
        case .flamingo: drawFlamingo(in: scene, t: t)
        case .lilo: drawLilo(in: scene, t: t)
        }

        // Re-cover the water band translucently so whatever sits below the
        // line reads submerged, then rule the waterline on top.
        context.fill(Path(waterRect), with: .color(.poolWater.opacity(0.45)))
        var line = Path()
        line.move(to: CGPoint(x: 0, y: waterline))
        line.addLine(to: CGPoint(x: size.width, y: waterline))
        context.stroke(line, with: .color(.white.opacity(0.30)), lineWidth: 1)

        drawGrain(in: context, over: waterRect)
    }

    // MARK: - Shared idle motion

    /// Applies the float: a slow bob plus a barely-there breath scaled about
    /// the body's center. Returns the transformed context to draw the toy in.
    private static func floating(_ context: GraphicsContext, t: Double,
                                 seed: Double) -> GraphicsContext {
        var c = context
        // +1.6 settles the hull in — vinyl rides high, but not perched.
        c.translateBy(x: 0, y: 1.6 + sin(t * 1.15 + seed) * 0.9)
        let breath = 1 + 0.015 * sin(t * 2.1 + seed)
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

    /// A flattened ring spreading from the floating toy now and then.
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

    // MARK: - Toys

    /// The classic bathtub profile: hull low in the water, head up.
    private static func drawDuck(in context: GraphicsContext, t: Double) {
        let seed = phase(.duck)
        var c = floating(context, t: t, seed: seed)

        // Tail kicked up at the rear.
        var tail = Path()
        tail.move(to: CGPoint(x: -10, y: -6))
        tail.addQuadCurve(to: CGPoint(x: -16, y: -12),
                          control: CGPoint(x: -15, y: -6.5))
        tail.addQuadCurve(to: CGPoint(x: -8.5, y: -2.5),
                          control: CGPoint(x: -12, y: -8))
        tail.closeSubpath()
        c.fill(tail, with: .color(.duckShade))

        let body = Path(ellipseIn: CGRect(x: -14, y: -10, width: 27, height: 12))
        c.fill(body, with: .color(.duckYellow))
        var belly = c
        belly.clip(to: body)
        belly.fill(Path(CGRect(x: -14, y: -2, width: 27, height: 4)),
                   with: .color(.duckShade))

        // Molded wing.
        c.fill(Path(ellipseIn: CGRect(x: -8, y: -8, width: 13, height: 7)),
               with: .color(.duckShade.opacity(0.6)))

        // Head over the chest, beak reaching forward.
        c.fill(Path(ellipseIn: CGRect(x: 3.5, y: -18.6, width: 11.6, height: 11.6)),
               with: .color(.duckYellow))
        var beak = Path()
        beak.move(to: CGPoint(x: 14.4, y: -14.8))
        beak.addLine(to: CGPoint(x: 19.6, y: -13.4))
        beak.addLine(to: CGPoint(x: 14.4, y: -11.6))
        beak.closeSubpath()
        c.fill(beak, with: .color(.duckBeak))
        // Vinyl catch-light on the crown.
        c.fill(Path(ellipseIn: CGRect(x: 5.4, y: -17, width: 4.2, height: 2.6)),
               with: .color(.white.opacity(0.55)))

        drawEye(in: c, at: CGPoint(x: 11, y: -14.4), color: .toyInk, t: t, seed: seed)
    }

    private static func drawBeachBall(in context: GraphicsContext, t: Double) {
        let seed = phase(.beachBall)
        var c = floating(context, t: t, seed: seed)
        // Nearly all above the line — a ball barely dents the water.
        c.translateBy(x: 0, y: -1.5)
        c.rotate(by: .degrees(sin(t * 0.5 + seed) * 5))

        let ball = Path(ellipseIn: CGRect(x: -11, y: -17, width: 22, height: 22))
        var panels = c
        panels.clip(to: ball)
        let colors: [Color] = [.ballRed, .white, .ballBlue, .white, .ballYellow]
        // Vertical panels, foreshortened toward the edges like longitude lines.
        let cuts: [CGFloat] = [-11, -7.5, -2.5, 2.5, 7.5, 11]
        for (index, color) in colors.enumerated() {
            panels.fill(Path(CGRect(x: cuts[index], y: -17,
                                    width: cuts[index + 1] - cuts[index], height: 22)),
                        with: .color(color))
        }
        c.stroke(ball, with: .color(.toyInk.opacity(0.10)), lineWidth: 1)
        c.fill(Path(ellipseIn: CGRect(x: -6.5, y: -15.5, width: 6.5, height: 3.6)),
               with: .color(.white.opacity(0.6)))
    }

    private static func drawRing(in context: GraphicsContext, t: Double) {
        let seed = phase(.ring)
        var c = floating(context, t: t, seed: seed)

        // A ring lying flat, seen edge-on: a squashed annulus.
        let outer = Path(ellipseIn: CGRect(x: -14, y: -8, width: 28, height: 10.5))
        c.fill(outer, with: .color(.white))
        // The far rim shows through the hole.
        c.fill(Path(ellipseIn: CGRect(x: -6.5, y: -7.2, width: 13, height: 3.6)),
               with: .color(.poolWater.opacity(0.75)))
        // Rescue-red segments wrap the near tube.
        var stripes = c
        stripes.clip(to: outer)
        stripes.fill(Path(CGRect(x: -14, y: -8, width: 7, height: 12)),
                     with: .color(.ballRed))
        stripes.fill(Path(CGRect(x: 7, y: -8, width: 7, height: 12)),
                     with: .color(.ballRed))
        c.stroke(outer, with: .color(.toyInk.opacity(0.10)), lineWidth: 1)
        c.fill(Path(ellipseIn: CGRect(x: -8, y: -7.6, width: 6, height: 2.4)),
               with: .color(.white.opacity(0.8)))
    }

    private static func drawOrca(in context: GraphicsContext, t: Double) {
        let seed = phase(.orca)
        var c = floating(context, t: t, seed: seed)

        // Dorsal fin first, swept back off the spine.
        var fin = Path()
        fin.move(to: CGPoint(x: -1, y: -10))
        fin.addQuadCurve(to: CGPoint(x: 3.5, y: -18.5),
                         control: CGPoint(x: 0.5, y: -16))
        fin.addQuadCurve(to: CGPoint(x: 6, y: -9.5),
                         control: CGPoint(x: 5.5, y: -14))
        fin.closeSubpath()
        c.fill(fin, with: .color(.orcaDark))

        // Tail flukes up at the rear.
        var flukes = Path()
        flukes.move(to: CGPoint(x: -12, y: -6))
        flukes.addQuadCurve(to: CGPoint(x: -18.5, y: -11),
                            control: CGPoint(x: -17, y: -6))
        flukes.addQuadCurve(to: CGPoint(x: -10.5, y: -2.5),
                            control: CGPoint(x: -14.5, y: -7))
        flukes.closeSubpath()
        c.fill(flukes, with: .color(.orcaDark))

        let body = Path(ellipseIn: CGRect(x: -14, y: -10.5, width: 29, height: 13))
        c.fill(body, with: .color(.orcaDark))
        // White chin along the waterline.
        var chin = c
        chin.clip(to: body)
        chin.fill(Path(CGRect(x: -3, y: -3.5, width: 18, height: 6)),
                  with: .color(.white.opacity(0.9)))
        // Eye patch.
        c.fill(Path(ellipseIn: CGRect(x: 6.5, y: -8.6, width: 5.2, height: 2.9)),
               with: .color(.white.opacity(0.92)))
        // Seam where the two vinyl halves meet.
        c.fill(Path(ellipseIn: CGRect(x: -8, y: -9.4, width: 6, height: 2.6)),
               with: .color(.white.opacity(0.35)))

        drawEye(in: c, at: CGPoint(x: 10.6, y: -5.6),
                color: .white.opacity(0.85), t: t, seed: seed, diameter: 1.8)
    }

    private static func drawFlamingo(in context: GraphicsContext, t: Double) {
        let seed = phase(.flamingo)
        var c = floating(context, t: t, seed: seed)

        // The ring, edge-on.
        let ring = Path(ellipseIn: CGRect(x: -13, y: -7, width: 26, height: 9.5))
        c.fill(ring, with: .color(.flamingoPink))
        c.fill(Path(ellipseIn: CGRect(x: -6, y: -6.4, width: 12, height: 3.2)),
               with: .color(.flamingoDeep.opacity(0.7)))
        // Tail feathers at the rear.
        var tail = Path()
        tail.move(to: CGPoint(x: -11, y: -5))
        tail.addQuadCurve(to: CGPoint(x: -17, y: -10.5),
                          control: CGPoint(x: -16, y: -5.5))
        tail.addQuadCurve(to: CGPoint(x: -9.5, y: -2),
                          control: CGPoint(x: -13, y: -7))
        tail.closeSubpath()
        c.fill(tail, with: .color(.flamingoDeep))

        // The S-neck rising off the front rim to the head.
        var neck = Path()
        neck.move(to: CGPoint(x: 8, y: -4))
        neck.addCurve(to: CGPoint(x: 7.5, y: -14.5),
                      control1: CGPoint(x: 13.5, y: -6.5),
                      control2: CGPoint(x: 13, y: -13))
        c.stroke(neck, with: .color(.flamingoPink),
                 style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 3.6, y: -17.9, width: 8.4, height: 6.6)),
               with: .color(.flamingoPink))
        // Bill curving down, black-tipped.
        var beak = Path()
        beak.move(to: CGPoint(x: 11.4, y: -16.2))
        beak.addQuadCurve(to: CGPoint(x: 15.4, y: -12.6),
                          control: CGPoint(x: 15.4, y: -16))
        beak.addQuadCurve(to: CGPoint(x: 11.4, y: -13.6),
                          control: CGPoint(x: 13.4, y: -13.6))
        beak.closeSubpath()
        c.fill(beak, with: .color(.toyInk))
        c.fill(Path(ellipseIn: CGRect(x: -5, y: -6.2, width: 6, height: 2.4)),
               with: .color(.white.opacity(0.5)))

        drawEye(in: c, at: CGPoint(x: 8.4, y: -15.2), color: .toyInk, t: t, seed: seed,
                diameter: 1.9)
    }

    private static func drawLilo(in context: GraphicsContext, t: Double) {
        let seed = phase(.lilo)
        var c = floating(context, t: t, seed: seed)
        // Long and flat — it barely draws water.
        c.translateBy(x: 0, y: -0.5)
        c.rotate(by: .degrees(sin(t * 0.8 + seed) * 1.5))

        // Scalloped air tubes along the length.
        let pale = Color(red: 0.93, green: 0.96, blue: 0.98)
        for index in 0..<5 {
            let x = -16.5 + CGFloat(index) * 6.6
            c.fill(Path(ellipseIn: CGRect(x: x, y: -5.4, width: 7.4, height: 5.8)),
                   with: .color(pale))
        }
        // The raised pillow at the head end.
        c.fill(Path(ellipseIn: CGRect(x: 12, y: -8.2, width: 9.5, height: 7)),
               with: .color(pale))
        c.fill(Path(ellipseIn: CGRect(x: 13.6, y: -7.4, width: 4.6, height: 2.2)),
               with: .color(.poolWater.opacity(0.30)))
        // Hull line seating it on the water.
        var hull = Path()
        hull.move(to: CGPoint(x: -16.5, y: -0.4))
        hull.addLine(to: CGPoint(x: 21, y: -0.4))
        c.stroke(hull, with: .color(.poolWater.opacity(0.5)), lineWidth: 1.2)
    }

    /// The filmic texture, over the water only — matching the pool.
    private static func drawGrain(in context: GraphicsContext, over rect: CGRect) {
        var c = context
        c.clip(to: Path(rect))
        c.blendMode = .overlay
        c.opacity = 0.10
        c.draw(Image(uiImage: Grain.image),
               in: CGRect(x: rect.minX, y: rect.minY, width: 128, height: 128))
    }
}
