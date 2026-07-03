import SwiftUI

/// Top-down pool-toy drawings: flat vinyl shapes with a hard afternoon sun
/// shadow, deadpan like a catalog photo. All code-drawn — no assets.
enum PoolToyArt {
    /// Toys that point where they drift; the rest just spin slowly.
    static func isDirectional(_ kind: ToyKind) -> Bool {
        switch kind {
        case .duck, .orca, .flamingo, .lilo: return true
        case .beachBall, .ring: return false
        }
    }

    /// Draws a floating toy. `rotation` is the drift heading for directional
    /// toys, a slow spin for the symmetric ones. Local space: +x forward,
    /// roughly 36 pt across at scale 1. `shiny` swaps the vinyl for the
    /// gilded pearl-and-gold colorway — the rare pull.
    static func draw(_ kind: ToyKind, in context: GraphicsContext, at point: CGPoint,
                     rotation: Angle, wiggle: Double, scale: CGFloat,
                     shiny: Bool = false) {
        // The sun shadow keeps its world-space direction no matter which way
        // the toy points: offset first, rotate after.
        var shadow = context
        shadow.translateBy(x: point.x + 5 * scale, y: point.y + 7 * scale)
        shadow.rotate(by: rotation)
        shadow.scaleBy(x: scale, y: scale)
        shadow.fill(silhouette(kind), with: .color(.black.opacity(0.13)))

        var c = context
        c.translateBy(x: point.x, y: point.y)
        c.rotate(by: rotation)
        c.scaleBy(x: scale, y: scale)
        if isDirectional(kind) {
            c.rotate(by: .degrees(sin(wiggle) * 2.0))
        }

        switch kind {
        case .duck: drawDuck(in: c, shiny: shiny)
        case .beachBall: drawBeachBall(in: c, shiny: shiny)
        case .ring: drawRing(in: c, shiny: shiny)
        case .orca: drawOrca(in: c, shiny: shiny)
        case .flamingo: drawFlamingo(in: c, shiny: shiny)
        case .lilo: drawLilo(in: c, shiny: shiny)
        }
    }

    /// A brief four-point twinkle by the toy — how a gilded toy tells, and
    /// how a fresh arrival waves. Fires once per `period`; a pure function
    /// of time.
    static func drawGlint(in context: GraphicsContext, at point: CGPoint,
                          time: Double, phase: Double, scale: CGFloat,
                          period: Double = 6.5,
                          offset: CGPoint = CGPoint(x: 9, y: -11)) {
        let cycle = (time * 0.85 + phase).truncatingRemainder(dividingBy: period)
        guard cycle < 1.1 else { return }
        let pulse = sin(.pi * cycle / 1.1)
        var c = context
        c.opacity = 0.9 * pulse
        c.translateBy(x: point.x + offset.x * scale, y: point.y + offset.y * scale)
        c.scaleBy(x: scale * (0.5 + 0.5 * pulse), y: scale * (0.5 + 0.5 * pulse))
        var star = Path()
        star.move(to: CGPoint(x: -4.5, y: 0))
        star.addLine(to: CGPoint(x: 4.5, y: 0))
        star.move(to: CGPoint(x: 0, y: -4.5))
        star.addLine(to: CGPoint(x: 0, y: 4.5))
        c.stroke(star, with: .color(.white),
                 style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        var cross = Path()
        cross.move(to: CGPoint(x: -1.7, y: -1.7))
        cross.addLine(to: CGPoint(x: 1.7, y: 1.7))
        cross.move(to: CGPoint(x: -1.7, y: 1.7))
        cross.addLine(to: CGPoint(x: 1.7, y: -1.7))
        c.stroke(cross, with: .color(.white.opacity(0.8)),
                 style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    /// Rough outline for the sun shadow — overlapping subpaths are fine,
    /// they flatten into one fill.
    private static func silhouette(_ kind: ToyKind) -> Path {
        var path = Path()
        switch kind {
        case .duck:
            path.addEllipse(in: CGRect(x: -13, y: -8, width: 23, height: 16))
            path.addEllipse(in: CGRect(x: 6.5, y: -5.5, width: 11, height: 11))
        case .beachBall:
            path.addEllipse(in: CGRect(x: -13, y: -13, width: 26, height: 26))
        case .ring:
            path.addEllipse(in: CGRect(x: -13.5, y: -13.5, width: 27, height: 27))
        case .orca:
            path.addEllipse(in: CGRect(x: -14, y: -8, width: 28, height: 16))
            path.addEllipse(in: CGRect(x: -19, y: -6, width: 9, height: 12))
        case .flamingo:
            path.addEllipse(in: CGRect(x: -14, y: -12, width: 24, height: 24))
            path.addEllipse(in: CGRect(x: 10.5, y: -4.2, width: 10.5, height: 8.4))
        case .lilo:
            path.addRoundedRect(in: CGRect(x: -17, y: -10, width: 34, height: 20),
                                cornerSize: CGSize(width: 5, height: 5))
        }
        return path
    }

    // MARK: - Toys

    private static func drawDuck(in c: GraphicsContext, shiny: Bool) {
        let body = shiny ? Color.pearl : .duckYellow
        let shade = shiny ? Color.pearlShade : .duckShade
        let beakColor = shiny ? Color.gold : .duckBeak

        // Tail wedge, then the hull split light/shade along the spine.
        var tail = Path()
        tail.move(to: CGPoint(x: -9, y: -3.6))
        tail.addLine(to: CGPoint(x: -15.5, y: 0))
        tail.addLine(to: CGPoint(x: -9, y: 3.6))
        tail.closeSubpath()
        c.fill(tail, with: .color(shade))

        let hull = Path(ellipseIn: CGRect(x: -13, y: -8, width: 23, height: 16))
        c.fill(hull, with: .color(body))
        var lower = c
        lower.clip(to: hull)
        lower.fill(Path(CGRect(x: -13, y: 0, width: 23, height: 8)),
                   with: .color(shade))

        // Molded wing bumps.
        c.fill(Path(ellipseIn: CGRect(x: -8.5, y: -7.2, width: 12, height: 5)),
               with: .color(shade.opacity(0.55)))
        c.fill(Path(ellipseIn: CGRect(x: -8.5, y: 2.2, width: 12, height: 5)),
               with: .color(shade.opacity(0.55)))

        // Head proud of the body, beak reaching forward.
        c.fill(Path(ellipseIn: CGRect(x: 6.5, y: -5.5, width: 11, height: 11)),
               with: .color(body))
        var beak = Path()
        beak.move(to: CGPoint(x: 16, y: -2.6))
        beak.addLine(to: CGPoint(x: 21.5, y: 0))
        beak.addLine(to: CGPoint(x: 16, y: 2.6))
        beak.closeSubpath()
        c.fill(beak, with: .color(beakColor))

        // Painted eyes on both sides of the head.
        for y in [-3.4, 3.4] {
            c.fill(Path(ellipseIn: CGRect(x: 11.2, y: y - 1.1, width: 2.2, height: 2.2)),
                   with: .color(.toyInk))
        }
        // Vinyl catch-light.
        c.fill(Path(ellipseIn: CGRect(x: 8.2, y: -3.8, width: 3.4, height: 2.2)),
               with: .color(.white.opacity(0.55)))
    }

    private static func drawBeachBall(in c: GraphicsContext, shiny: Bool) {
        let radius: CGFloat = 13
        let panels: [Color] = shiny
            ? [.pearl, .gold, .pearl, .goldDeep, .pearl, .gold]
            : [.white, .ballRed, .white, .ballBlue, .white, .ballYellow]
        for (index, color) in panels.enumerated() {
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addArc(center: .zero, radius: radius,
                         startAngle: .degrees(Double(index) * 60),
                         endAngle: .degrees(Double(index + 1) * 60),
                         clockwise: false)
            wedge.closeSubpath()
            c.fill(wedge, with: .color(color))
        }
        // Molded cap where the panels meet, and a vinyl catch-light.
        c.fill(Path(ellipseIn: CGRect(x: -3.2, y: -3.2, width: 6.4, height: 6.4)),
               with: .color(shiny ? .gold : .white))
        c.fill(Path(ellipseIn: CGRect(x: -8, y: -9.5, width: 6, height: 3.6)),
               with: .color(.white.opacity(0.5)))
    }

    private static func drawRing(in c: GraphicsContext, shiny: Bool) {
        var ring = Path()
        ring.addEllipse(in: CGRect(x: -13.5, y: -13.5, width: 27, height: 27))
        ring.addEllipse(in: CGRect(x: -7, y: -7, width: 14, height: 14))
        c.fill(ring, with: .color(shiny ? .pearl : .white), style: FillStyle(eoFill: true))

        // Four rescue quadrants — red, or gold on the gilded one.
        var striped = c
        striped.clip(to: ring, style: FillStyle(eoFill: true))
        for start in stride(from: 22.5, to: 360, by: 90.0) {
            var wedge = Path()
            wedge.move(to: .zero)
            wedge.addArc(center: .zero, radius: 15,
                         startAngle: .degrees(start), endAngle: .degrees(start + 45),
                         clockwise: false)
            wedge.closeSubpath()
            striped.fill(wedge, with: .color(shiny ? .gold : .ballRed))
        }
        // Inner rim shading so the tube reads round.
        c.stroke(Path(ellipseIn: CGRect(x: -7, y: -7, width: 14, height: 14)),
                 with: .color(.toyInk.opacity(0.12)), lineWidth: 1.2)
        c.fill(Path(ellipseIn: CGRect(x: -9, y: -11.5, width: 7, height: 3.6)),
               with: .color(.white.opacity(0.7)))
    }

    private static func drawOrca(in c: GraphicsContext, shiny: Bool) {
        let hide = shiny ? Color.pearl : .orcaDark
        let patch = shiny ? Color.gold : .white.opacity(0.92)
        // Tail flukes swept back from the rear joint.
        var flukes = Path()
        flukes.move(to: CGPoint(x: -12, y: 0))
        flukes.addQuadCurve(to: CGPoint(x: -19.5, y: -5.5),
                            control: CGPoint(x: -14, y: -1.5))
        flukes.addQuadCurve(to: CGPoint(x: -14.5, y: 0),
                            control: CGPoint(x: -16.5, y: -1))
        flukes.addQuadCurve(to: CGPoint(x: -19.5, y: 5.5),
                            control: CGPoint(x: -16.5, y: 1))
        flukes.addQuadCurve(to: CGPoint(x: -12, y: 0),
                            control: CGPoint(x: -14, y: 1.5))
        c.fill(flukes, with: .color(hide))

        let body = Path(ellipseIn: CGRect(x: -14, y: -8, width: 28, height: 16))
        c.fill(body, with: .color(hide))

        // Pectoral fins.
        c.fill(Path(ellipseIn: CGRect(x: -3, y: -10.5, width: 8, height: 5)),
               with: .color(hide))
        c.fill(Path(ellipseIn: CGRect(x: -3, y: 5.5, width: 8, height: 5)),
               with: .color(hide))

        // Eye patches by the head, saddle patch behind the fin.
        c.fill(Path(ellipseIn: CGRect(x: 5.5, y: -6.2, width: 5.4, height: 3.2)),
               with: .color(patch))
        c.fill(Path(ellipseIn: CGRect(x: 5.5, y: 3.0, width: 5.4, height: 3.2)),
               with: .color(patch))
        c.fill(Path(ellipseIn: CGRect(x: -8, y: -2.2, width: 5, height: 4.4)),
               with: .color(shiny ? .gold.opacity(0.55) : .white.opacity(0.35)))

        // The dorsal fin from above: a slim ridge along the spine.
        c.fill(Path(roundedRect: CGRect(x: -4, y: -1.4, width: 9, height: 2.8),
                    cornerRadius: 1.4),
               with: .color(shiny ? .goldDeep.opacity(0.8) : .black.opacity(0.5)))
        c.fill(Path(ellipseIn: CGRect(x: 2, y: -7.4, width: 6, height: 3)),
               with: .color(.white.opacity(0.4)))
    }

    private static func drawFlamingo(in c: GraphicsContext, shiny: Bool) {
        let vinyl = shiny ? Color.pearl : .flamingoPink
        let deep = shiny ? Color.goldDeep : .flamingoDeep

        // The inflatable ring you sit in.
        var ring = Path()
        ring.addEllipse(in: CGRect(x: -14, y: -12, width: 24, height: 24))
        ring.addEllipse(in: CGRect(x: -8, y: -6, width: 12, height: 12))
        c.fill(ring, with: .color(vinyl), style: FillStyle(eoFill: true))
        c.stroke(Path(ellipseIn: CGRect(x: -8, y: -6, width: 12, height: 12)),
                 with: .color(deep.opacity(0.6)), lineWidth: 1.2)

        // Folded tail feathers at the rear.
        var tail = Path()
        tail.move(to: CGPoint(x: -12, y: -4))
        tail.addLine(to: CGPoint(x: -19, y: -7.5))
        tail.addLine(to: CGPoint(x: -12.5, y: 0))
        tail.closeSubpath()
        c.fill(tail, with: .color(deep))

        // Neck arcing forward over the rim to a head that clearly outsizes it.
        var neck = Path()
        neck.move(to: CGPoint(x: 5, y: -5.5))
        neck.addQuadCurve(to: CGPoint(x: 14, y: 0),
                          control: CGPoint(x: 12.5, y: -6))
        c.stroke(neck, with: .color(vinyl),
                 style: StrokeStyle(lineWidth: 5, lineCap: .round))
        c.fill(Path(ellipseIn: CGRect(x: 10.5, y: -4.2, width: 10.5, height: 8.4)),
               with: .color(vinyl))
        // Stubby bill, black-tipped — wide enough to not read as a spike.
        var beak = Path()
        beak.move(to: CGPoint(x: 20.2, y: -2.4))
        beak.addQuadCurve(to: CGPoint(x: 25, y: 0),
                          control: CGPoint(x: 24.6, y: -2))
        beak.addQuadCurve(to: CGPoint(x: 20.2, y: 2.4),
                          control: CGPoint(x: 24.6, y: 2))
        beak.closeSubpath()
        c.fill(beak, with: .color(shiny ? .gold : .white.opacity(0.9)))
        c.fill(Path(ellipseIn: CGRect(x: 22.6, y: -1.6, width: 3.2, height: 3.2)),
               with: .color(.toyInk))
        // Painted eyes on both sides of the head, like the duck's.
        for y in [-2.4, 2.4] {
            c.fill(Path(ellipseIn: CGRect(x: 14.6, y: y - 0.9, width: 1.8, height: 1.8)),
                   with: .color(.toyInk))
        }
        c.fill(Path(ellipseIn: CGRect(x: -6, y: -10.5, width: 6.5, height: 3.4)),
               with: .color(.white.opacity(0.45)))
    }

    private static func drawLilo(in c: GraphicsContext, shiny: Bool) {
        let seamColor = shiny ? Color.gold.opacity(0.8) : .poolWater.opacity(0.5)
        let base = Path(roundedRect: CGRect(x: -17, y: -10, width: 34, height: 20),
                        cornerRadius: 5)
        c.fill(base, with: .color(shiny ? .pearl
                                        : Color(red: 0.93, green: 0.96, blue: 0.98)))

        var inner = c
        inner.clip(to: base)
        // Lengthwise air tubes: pool-blue seams — gold on the gilded one.
        for y in stride(from: -5.0, through: 5.0, by: 5.0) {
            var seam = Path()
            seam.move(to: CGPoint(x: -17, y: y))
            seam.addLine(to: CGPoint(x: 12, y: y))
            inner.stroke(seam, with: .color(seamColor), lineWidth: 1.3)
        }
        // The pillow block at the head end.
        inner.fill(Path(CGRect(x: 12, y: -10, width: 5.5, height: 20)),
                   with: .color(shiny ? .gold.opacity(0.5) : .poolWater.opacity(0.35)))
        c.stroke(base, with: .color(shiny ? .gold.opacity(0.7) : .poolWater.opacity(0.45)),
                 lineWidth: 1.2)
        c.fill(Path(ellipseIn: CGRect(x: -12, y: -8, width: 8, height: 3.4)),
               with: .color(.white.opacity(0.8)))
    }
}
