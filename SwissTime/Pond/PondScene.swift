import SwiftUI

/// Pure pool renderer: a top-down municipal pool — dry tile deck, water
/// inset with a chrome ladder, toys adrift under an afternoon sun. All
/// layout is precomputed from seeds in `init`, and motion is a pure
/// function of time — so the live pool, the low-fps hero strip, and frozen
/// postcards share one code path with no simulation state.
struct PondScene {
    enum Detail { case hero, full }

    /// A toy adrift on the water. Position is a sum of two slow sinusoids
    /// per axis; amplitudes are clamped to the anchor's distance from the
    /// water's edge, so edge avoidance is structural.
    struct Floater {
        let kind: ToyKind
        let shiny: Bool
        /// Earned since the pool was last viewed — sparkles until seen.
        let isNew: Bool
        let anchor: CGPoint            // unit coords in the water rect
        let ampX1, ampX2, ampY1, ampY2: CGFloat
        let wX1, wX2, wY1, wY2: Double // rad/s
        let pX1, pX2, pY1, pY2: Double
        let spinRate: Double           // rad/s, for the symmetric toys
        let spinPhase: Double
        let wigglePhase: Double
        let ripplePeriod: Double

        func unitPosition(at t: Double) -> CGPoint {
            CGPoint(
                x: anchor.x + ampX1 * sin(wX1 * t + pX1) + ampX2 * sin(wX2 * t + pX2),
                y: anchor.y + ampY1 * cos(wY1 * t + pY1) + ampY2 * sin(wY2 * t + pY2)
            )
        }

        /// Analytic derivative — smooth headings by construction.
        func unitVelocity(at t: Double) -> CGVector {
            CGVector(
                dx: ampX1 * wX1 * cos(wX1 * t + pX1) + ampX2 * wX2 * cos(wX2 * t + pX2),
                dy: -ampY1 * wY1 * sin(wY1 * t + pY1) + ampY2 * wY2 * cos(wY2 * t + pY2)
            )
        }
    }

    /// A patch of caustic light (or cloud shade) drifting in the water.
    struct Caustic {
        let center: CGPoint    // unit coords in the water rect
        let radius: CGFloat    // fraction of water width
        let aspect: CGFloat
        let driftPhase: Double
        let light: Bool
    }

    let floaters: [Floater]
    let caustics: [Caustic]
    /// Where the ladder hangs over the top edge, unit x in the water rect.
    let ladderX: CGFloat

    /// The dry-deck grout grid never moves (unlike the underwater one, which
    /// refracts with time) — a class box so this reference-semantics cache
    /// survives across the many `draw` calls a memoized, value-type scene
    /// receives over its lifetime, one per animation frame.
    private final class DryGridCache {
        var size: CGSize?
        var path: Path?
    }
    private let dryGridCache = DryGridCache()

    init(monthKey: MonthKey, entries: [PondEntry], newIDs: Set<UUID> = []) {
        var monthRng = SeededRandom(seed: monthKey.seed)

        var caustics: [Caustic] = []
        for index in 0..<6 {
            caustics.append(Caustic(
                center: CGPoint(x: CGFloat.random(in: 0.08...0.92, using: &monthRng),
                                y: CGFloat.random(in: 0.12...0.88, using: &monthRng)),
                radius: CGFloat.random(in: 0.16...0.30, using: &monthRng),
                aspect: CGFloat.random(in: 0.45...0.85, using: &monthRng),
                driftPhase: Double.random(in: 0...(2 * .pi), using: &monthRng),
                light: index >= 3))
        }
        self.caustics = caustics
        self.ladderX = CGFloat.random(in: 0.16...0.34, using: &monthRng)

        // One toy per finished workout, seeded by the entry itself so it
        // keeps its spot and habits for the whole month.
        var placed: [CGPoint] = []
        self.floaters = entries.map { entry in
            var rng = SeededRandom(entry.id)
            var anchor = CGPoint(x: 0.5, y: 0.5)
            for _ in 0..<24 {
                let candidate = CGPoint(x: CGFloat.random(in: 0.18...0.82, using: &rng),
                                        y: CGFloat.random(in: 0.22...0.78, using: &rng))
                anchor = candidate
                if placed.allSatisfy({ hypot($0.x - candidate.x, $0.y - candidate.y) > 0.16 }) {
                    break
                }
            }
            placed.append(anchor)

            let kind = Palette.toy(for: entry.colorIndex)
            // Vinyl drifts at the water's pace; only the duck has any hustle.
            let tempo: Double
            switch kind {
            case .duck: tempo = 1.2
            case .beachBall: tempo = 1.0
            case .orca: tempo = 0.9
            case .ring: tempo = 0.75
            case .flamingo: tempo = 0.65
            case .lilo: tempo = 0.5
            }
            let maxAx = max(0.02, min(anchor.x - 0.10, 0.90 - anchor.x))
            let maxAy = max(0.02, min(anchor.y - 0.12, 0.88 - anchor.y))
            return Floater(
                kind: kind,
                shiny: entry.isShiny,
                isNew: newIDs.contains(entry.id),
                anchor: anchor,
                ampX1: CGFloat.random(in: 0.45...0.7, using: &rng) * maxAx,
                ampX2: CGFloat.random(in: 0.12...0.28, using: &rng) * maxAx,
                ampY1: CGFloat.random(in: 0.45...0.7, using: &rng) * maxAy,
                ampY2: CGFloat.random(in: 0.12...0.28, using: &rng) * maxAy,
                wX1: Double.random(in: 0.05...0.11, using: &rng) * tempo,
                wX2: Double.random(in: 0.11...0.19, using: &rng) * tempo,
                wY1: Double.random(in: 0.05...0.11, using: &rng) * tempo,
                wY2: Double.random(in: 0.11...0.19, using: &rng) * tempo,
                pX1: Double.random(in: 0...(2 * .pi), using: &rng),
                pX2: Double.random(in: 0...(2 * .pi), using: &rng),
                pY1: Double.random(in: 0...(2 * .pi), using: &rng),
                pY2: Double.random(in: 0...(2 * .pi), using: &rng),
                spinRate: Double.random(in: 0.04...0.10, using: &rng)
                    * (Bool.random(using: &rng) ? 1 : -1),
                spinPhase: Double.random(in: 0...(2 * .pi), using: &rng),
                wigglePhase: Double.random(in: 0...(2 * .pi), using: &rng),
                ripplePeriod: Double.random(in: 8...15, using: &rng))
        }
    }

    // MARK: - Drawing

    func draw(in context: GraphicsContext, size: CGSize, time: TimeInterval, detail: Detail,
              night: Bool = false, glints: Bool = true) {
        let deckInset: CGFloat = detail == .hero ? 12 : 22
        let waterRect = CGRect(origin: .zero, size: size)
            .insetBy(dx: deckInset, dy: deckInset)
        guard waterRect.width > 40, waterRect.height > 40 else { return }
        let tile: CGFloat = detail == .hero ? 22 : 28
        let cornerRadius: CGFloat = detail == .hero ? 10 : 14
        let waterPath = Path(roundedRect: waterRect, cornerRadius: cornerRadius,
                             style: .continuous)
        let crowd: CGFloat = floaters.count > 14 ? 0.8 : 1.0
        let toyScale = (detail == .hero ? 0.85 : 1.0) * crowd

        // Dry deck: pale tile with straight grout, edge to edge. Static
        // while the view is on screen, so the sampled path is cached rather
        // than resampled at up to 24fps.
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.tileDry))
        let dryGrid: Path
        if let cached = dryGridCache.path, dryGridCache.size == size {
            dryGrid = cached
        } else {
            dryGrid = gridPath(over: CGRect(origin: .zero, size: size),
                               spacing: tile, time: nil)
            dryGridCache.size = size
            dryGridCache.path = dryGrid
        }
        context.stroke(dryGrid, with: .color(.tileGrout.opacity(0.75)), lineWidth: 1.2)

        // The pool cut into it, darker at the rim like depth falling away.
        context.fill(waterPath, with: .color(.poolWater))
        var water = context
        water.clip(to: waterPath)
        water.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [.clear, Color.poolWaterDeep.opacity(0.5)]),
                center: CGPoint(x: waterRect.midX, y: waterRect.midY),
                startRadius: min(waterRect.width, waterRect.height) * 0.25,
                endRadius: max(waterRect.width, waterRect.height) * 0.75))

        // The same grid continues underwater, refracting: grout lines wave
        // slowly, offset dark-under-light so the joints read submerged.
        // One sampled path, stroked twice through a nudged context — the
        // wobble sampling is the scene's hottest loop, no need to run it
        // twice for a 1.5pt emboss offset.
        let wetGrout = gridPath(over: waterRect.insetBy(dx: -tile, dy: -tile),
                                spacing: tile, time: time)
        water.stroke(wetGrout, with: .color(.poolWaterDeep.opacity(0.55)),
                     lineWidth: 1.6)
        var lifted = water
        lifted.translateBy(x: 1.5, y: 1.5)
        lifted.stroke(wetGrout, with: .color(.white.opacity(0.14)), lineWidth: 1.2)

        // At night the pool is lit from below: two underwater lamps glow
        // through the water, anchored to the pool, steady like fixtures.
        if night {
            for (ux, uy) in [(0.28, 0.30), (0.74, 0.72)] {
                let center = CGPoint(x: waterRect.minX + ux * waterRect.width,
                                     y: waterRect.minY + uy * waterRect.height)
                water.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.13), .clear]),
                        center: center, startRadius: 0,
                        endRadius: waterRect.width * 0.42))
            }
        }

        // Caustic light and cloud shade drifting through — the light reads
        // brighter after dark, the shade softer.
        water.drawLayer { layer in
            layer.addFilter(.blur(radius: detail == .hero ? 9 : 14))
            for caustic in caustics {
                let drift = CGPoint(
                    x: sin(time / 47 + caustic.driftPhase) * 10,
                    y: cos(time / 53 + caustic.driftPhase) * 7)
                let w = caustic.radius * waterRect.width
                let h = w * caustic.aspect
                let rect = CGRect(
                    x: waterRect.minX + caustic.center.x * waterRect.width - w / 2 + drift.x,
                    y: waterRect.minY + caustic.center.y * waterRect.height - h / 2 + drift.y,
                    width: w, height: h)
                layer.fill(Path(ellipseIn: rect),
                           with: .color(caustic.light
                                        ? Color.white.opacity(night ? 0.16 : 0.10)
                                        : Color.poolWaterDeep.opacity(night ? 0.32 : 0.45)))
            }
        }

        // The wet line where water meets tile.
        water.stroke(waterPath, with: .color(.poolWaterDeep.opacity(0.6)), lineWidth: 2)
        context.stroke(
            Path(roundedRect: waterRect.insetBy(dx: -1.5, dy: -1.5),
                 cornerRadius: cornerRadius + 1.5, style: .continuous),
            with: .color(.white.opacity(0.5)), lineWidth: 1)

        drawGrain(in: water, over: waterRect)

        func point(_ unit: CGPoint) -> CGPoint {
            CGPoint(x: waterRect.minX + unit.x * waterRect.width,
                    y: waterRect.minY + unit.y * waterRect.height)
        }

        // Resolve drift crossings: a few relaxation passes push overlapping
        // toys apart, so they bump and slide around each other instead of
        // stacking. The nudge depends only on this frame's positions, so
        // motion stays a pure function of time — no simulation state.
        var positions = floaters.map { point($0.unitPosition(at: time)) }
        let radii = floaters.map { Self.bumpRadius($0.kind) * toyScale }
        if !positions.isEmpty {
            let ladderScale: CGFloat = detail == .hero ? 0.8 : 1.0
            let ladderPoint = CGPoint(x: waterRect.minX + ladderX * waterRect.width,
                                      y: waterRect.minY + 14 * ladderScale)
            let ladderRadius = 16 * ladderScale
            for _ in 0..<3 {
                for i in positions.indices {
                    for j in positions.indices where j > i {
                        let dx = positions[j].x - positions[i].x
                        let dy = positions[j].y - positions[i].y
                        let dist = max(0.001, hypot(dx, dy))
                        let minDist = radii[i] + radii[j]
                        guard dist < minDist else { continue }
                        let push = (minDist - dist) / 2
                        positions[i].x -= dx / dist * push
                        positions[i].y -= dy / dist * push
                        positions[j].x += dx / dist * push
                        positions[j].y += dy / dist * push
                    }
                    // The ladder doesn't give way — toys shy off it whole.
                    let dx = positions[i].x - ladderPoint.x
                    let dy = positions[i].y - ladderPoint.y
                    let dist = max(0.001, hypot(dx, dy))
                    let minDist = radii[i] + ladderRadius
                    if dist < minDist {
                        positions[i].x += dx / dist * (minDist - dist)
                        positions[i].y += dy / dist * (minDist - dist)
                    }
                }
            }
            // Pushed toys still stay in the water — inset by each toy's own
            // reach, so a shoved lilo can't hang over the pool wall.
            for i in positions.indices {
                let inset = max(12, radii[i])
                positions[i].x = min(max(positions[i].x, waterRect.minX + inset),
                                     waterRect.maxX - inset)
                positions[i].y = min(max(positions[i].y, waterRect.minY + inset),
                                     waterRect.maxY - inset)
            }
        }

        for (index, floater) in floaters.enumerated() {
            // A quiet ripple ring now and then — anchored to where the toy
            // is actually drawn, or a bumped toy's rings bloom in open water.
            let rippleAge = (time + floater.wigglePhase)
                .truncatingRemainder(dividingBy: floater.ripplePeriod)
            if rippleAge < 2.2 {
                drawRipple(in: water, at: positions[index], age: rippleAge,
                           maxRadius: 22)
            }

            let rotation: Angle
            if PoolToyArt.isDirectional(floater.kind) {
                let v = floater.unitVelocity(at: time)
                rotation = Angle(radians: atan2(v.dy * waterRect.height,
                                                v.dx * waterRect.width))
            } else {
                rotation = Angle(radians: floater.spinRate * time + floater.spinPhase)
            }
            PoolToyArt.draw(floater.kind, in: water, at: positions[index],
                            rotation: rotation,
                            wiggle: time * 2.0 + floater.wigglePhase,
                            scale: toyScale, shiny: floater.shiny)
            // No glints on a frozen frame (Reduce Motion's still pose) — a
            // twinkle caught mid-pulse would stick to the toy for the month.
            if glints, floater.isNew {
                // The arrival wave: two twinkles on a quick cycle, until
                // the pool has been viewed.
                PoolToyArt.drawGlint(in: water, at: positions[index], time: time,
                                     phase: floater.wigglePhase, scale: toyScale,
                                     period: 2.6)
                PoolToyArt.drawGlint(in: water, at: positions[index], time: time,
                                     phase: floater.wigglePhase + 1.3,
                                     scale: toyScale, period: 2.6,
                                     offset: CGPoint(x: -11, y: 9))
            } else if glints, floater.shiny {
                PoolToyArt.drawGlint(in: water, at: positions[index], time: time,
                                     phase: floater.wigglePhase, scale: toyScale)
            }
        }

        drawLadder(in: context, water: water, waterRect: waterRect,
                   scale: detail == .hero ? 0.8 : 1.0)
    }

    /// How close another toy can drift before this one gives way, in points
    /// at scale 1 — roughly each drawing's reach plus a little water between.
    private static func bumpRadius(_ kind: ToyKind) -> CGFloat {
        switch kind {
        case .duck: return 17
        case .beachBall: return 15
        case .ring: return 16
        case .orca: return 19
        case .flamingo: return 17
        case .lilo: return 20
        }
    }

    /// A grout grid over `rect`. With a `time` the lines refract — a slow
    /// travelling wave, like looking through a metre of water.
    private func gridPath(over rect: CGRect, spacing: CGFloat,
                          time: TimeInterval?) -> Path {
        var path = Path()
        let step: CGFloat = 10
        var x = rect.minX
        while x <= rect.maxX {
            if let time {
                path.move(to: CGPoint(x: x + wobble(x, 0, time), y: rect.minY))
                var y = rect.minY
                while y < rect.maxY {
                    y += step
                    path.addLine(to: CGPoint(x: x + wobble(x, y, time), y: y))
                }
            } else {
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            x += spacing
        }
        var y = rect.minY
        while y <= rect.maxY {
            if let time {
                path.move(to: CGPoint(x: rect.minX, y: y + wobble(y, 0, time)))
                var x = rect.minX
                while x < rect.maxX {
                    x += step
                    path.addLine(to: CGPoint(x: x, y: y + wobble(y, x, time)))
                }
            } else {
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            y += spacing
        }
        return path
    }

    private func wobble(_ along: CGFloat, _ across: CGFloat, _ time: TimeInterval) -> CGFloat {
        1.8 * sin(across / 17 + along / 41 + time * 0.55)
    }

    /// Chrome ladder hanging over the top edge — rails bright on the deck,
    /// dimmed where they continue underwater.
    private func drawLadder(in context: GraphicsContext, water: GraphicsContext,
                            waterRect: CGRect, scale: CGFloat) {
        let x = waterRect.minX + ladderX * waterRect.width
        let gap = 14 * scale
        let above = 12 * scale
        let below = 30 * scale
        let chrome = Color(red: 0.93, green: 0.96, blue: 0.99)

        // The rails' sun shadow on the deck seats them in the scene.
        var shadow = Path()
        for railX in [x - gap / 2, x + gap / 2] {
            shadow.move(to: CGPoint(x: railX + 2.5, y: waterRect.minY - above + 3))
            shadow.addLine(to: CGPoint(x: railX + 2.5, y: waterRect.minY))
        }
        shadow.move(to: CGPoint(x: x - gap / 2 + 2.5, y: waterRect.minY - above + 3))
        shadow.addLine(to: CGPoint(x: x + gap / 2 + 2.5, y: waterRect.minY - above + 3))
        context.stroke(shadow, with: .color(.black.opacity(0.13)),
                       style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))

        for railX in [x - gap / 2, x + gap / 2] {
            var sunk = Path()
            sunk.move(to: CGPoint(x: railX, y: waterRect.minY))
            sunk.addLine(to: CGPoint(x: railX, y: waterRect.minY + below))
            water.stroke(sunk, with: .color(chrome.opacity(0.6)),
                         style: StrokeStyle(lineWidth: 3.4 * scale, lineCap: .round))

            var rail = Path()
            rail.move(to: CGPoint(x: railX, y: waterRect.minY - above))
            rail.addLine(to: CGPoint(x: railX, y: waterRect.minY + 1))
            context.stroke(rail, with: .color(chrome),
                           style: StrokeStyle(lineWidth: 3.4 * scale, lineCap: .round))
        }
        var rung = Path()
        rung.move(to: CGPoint(x: x - gap / 2, y: waterRect.minY - above))
        rung.addLine(to: CGPoint(x: x + gap / 2, y: waterRect.minY - above))
        context.stroke(rung, with: .color(chrome),
                       style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))
    }

    private func drawRipple(in context: GraphicsContext, at point: CGPoint,
                            age: Double, maxRadius: CGFloat) {
        guard age > 0, age < 2.2 else { return }
        let k = age / 2.2
        let radius = 4 + (maxRadius - 4) * k
        context.stroke(
            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius,
                                   width: radius * 2, height: radius * 2)),
            with: .color(.white.opacity(0.22 * (1 - k))),
            lineWidth: 1)
    }

    /// Extra grain over the water only — the slightly filmic surface that
    /// keeps the flat blue from reading as a vector fill.
    private func drawGrain(in context: GraphicsContext, over rect: CGRect) {
        var c = context
        c.blendMode = .overlay
        c.opacity = 0.10
        let image = Image(uiImage: Grain.image)
        let tile: CGFloat = 128
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                c.draw(image, in: CGRect(x: x, y: y, width: tile, height: tile))
                x += tile
            }
            y += tile
        }
    }
}
