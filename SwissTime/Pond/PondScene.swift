import SwiftUI

/// Pure pond renderer. All layout is precomputed from seeds in `init`, and
/// motion is a pure function of time — so the live pond, the low-fps hero
/// strip, and frozen postcards share one code path with no simulation state.
struct PondScene {
    enum Detail { case hero, full }

    /// A creature wandering the water. Position is a sum of two slow
    /// sinusoids per axis; amplitudes are clamped to the anchor's distance
    /// from the water's edge, so edge avoidance is structural.
    struct Swimmer {
        let kind: CreatureKind
        let anchor: CGPoint            // unit coords in the water rect
        let ampX1, ampX2, ampY1, ampY2: CGFloat
        let wX1, wX2, wY1, wY2: Double // rad/s
        let pX1, pX2, pY1, pY2: Double
        let wigglePhase: Double
        let ripplePeriod: Double
        let surfacePeriod: Double      // fish only
        let surfacePhase: Double

        var isFish: Bool { kind == .koi || kind == .shadowFish }

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

    struct Reed {
        let base: CGPoint      // unit coords in the water rect (y 0 top edge, 1 bottom)
        let height: CGFloat    // points
        let lean: CGFloat      // sideways drift of the tip, points
        let width: CGFloat
        let hasCattail: Bool
        let swayPhase: Double
        let shade: CGFloat     // 0 dark – 1 light
    }

    struct Patch {
        let center: CGPoint    // unit coords in the water rect
        let radius: CGFloat    // fraction of water width
        let aspect: CGFloat
        let driftPhase: Double
        let light: Bool
    }

    let swimmers: [Swimmer]
    let reeds: [Reed]
    let patches: [Patch]

    init(monthKey: MonthKey, entries: [PondEntry]) {
        var monthRng = SeededRandom(seed: monthKey.seed)

        var patches: [Patch] = []
        for index in 0..<6 {
            patches.append(Patch(
                center: CGPoint(x: CGFloat.random(in: 0.08...0.92, using: &monthRng),
                                y: CGFloat.random(in: 0.12...0.88, using: &monthRng)),
                radius: CGFloat.random(in: 0.16...0.30, using: &monthRng),
                aspect: CGFloat.random(in: 0.45...0.85, using: &monthRng),
                driftPhase: Double.random(in: 0...(2 * .pi), using: &monthRng),
                light: index >= 4))
        }
        self.patches = patches

        // Reed clusters hug the banks: a few up top, more along the bottom,
        // one or two at the sides — like grass at the pond's edge.
        var reeds: [Reed] = []
        func cluster(x: CGFloat, y: CGFloat, count: Int, rng: inout SeededRandom) {
            for _ in 0..<count {
                reeds.append(Reed(
                    base: CGPoint(x: x + CGFloat.random(in: -0.035...0.035, using: &rng),
                                  y: y + CGFloat.random(in: -0.015...0.015, using: &rng)),
                    height: CGFloat.random(in: 26...58, using: &rng),
                    lean: CGFloat.random(in: -10...10, using: &rng),
                    width: CGFloat.random(in: 1.2...2.2, using: &rng),
                    hasCattail: Double.random(in: 0...1, using: &rng) < 0.38,
                    swayPhase: Double.random(in: 0...(2 * .pi), using: &rng),
                    shade: CGFloat.random(in: 0...1, using: &rng)))
            }
        }
        let topClusters = Int.random(in: 2...3, using: &monthRng)
        for _ in 0..<topClusters {
            cluster(x: CGFloat.random(in: 0.06...0.94, using: &monthRng), y: 0.01,
                    count: Int.random(in: 3...6, using: &monthRng), rng: &monthRng)
        }
        let bottomClusters = Int.random(in: 3...5, using: &monthRng)
        for _ in 0..<bottomClusters {
            cluster(x: CGFloat.random(in: 0.04...0.96, using: &monthRng), y: 1.0,
                    count: Int.random(in: 4...8, using: &monthRng), rng: &monthRng)
        }
        for x: CGFloat in [0.015, 0.985] where Bool.random(using: &monthRng) {
            cluster(x: x, y: CGFloat.random(in: 0.5...0.95, using: &monthRng),
                    count: Int.random(in: 3...5, using: &monthRng), rng: &monthRng)
        }
        self.reeds = reeds

        // One swimmer per finished workout, seeded by the entry itself so a
        // creature keeps its spot and habits for the whole month.
        var placed: [CGPoint] = []
        self.swimmers = entries.map { entry in
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

            let kind = Palette.creature(for: entry.colorIndex)
            let tempo: Double
            switch kind {
            case .duckling: tempo = 1.7
            case .goose: tempo = 0.6
            case .koi: tempo = 0.8
            default: tempo = 1.0
            }
            let maxAx = max(0.02, min(anchor.x - 0.10, 0.90 - anchor.x))
            let maxAy = max(0.02, min(anchor.y - 0.12, 0.88 - anchor.y))
            return Swimmer(
                kind: kind,
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
                wigglePhase: Double.random(in: 0...(2 * .pi), using: &rng),
                ripplePeriod: Double.random(in: 8...15, using: &rng),
                surfacePeriod: Double.random(in: 20...40, using: &rng),
                surfacePhase: Double.random(in: 0...40, using: &rng))
        }
    }

    // MARK: - Drawing

    func draw(in context: GraphicsContext, size: CGSize, time: TimeInterval, detail: Detail) {
        let waterRect = CGRect(origin: .zero, size: size)
            .insetBy(dx: 14, dy: detail == .hero ? 12 : 18)
        guard waterRect.width > 40, waterRect.height > 40 else { return }
        let cornerRadius = min(waterRect.width, waterRect.height) * 0.16
        let waterPath = Path(roundedRect: waterRect, cornerRadius: cornerRadius, style: .continuous)
        let crowd: CGFloat = swimmers.count > 14 ? 0.8 : 1.0
        let creatureScale = (detail == .hero ? 0.85 : 1.0) * crowd

        // Water with a feathered, blurred edge.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: detail == .hero ? 4 : 6))
            layer.fill(waterPath, with: .color(.pondWater))
        }

        // Everything on the water clips to it.
        var water = context
        water.clip(to: waterPath)

        // Darker toward the rim, like depth falling away from the banks.
        water.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                Gradient(colors: [.clear, Color.pondWaterDeep.opacity(0.45)]),
                center: CGPoint(x: waterRect.midX, y: waterRect.midY),
                startRadius: min(waterRect.width, waterRect.height) * 0.25,
                endRadius: max(waterRect.width, waterRect.height) * 0.75))

        // Slow drifting cloud-shadows in the water.
        water.drawLayer { layer in
            layer.addFilter(.blur(radius: detail == .hero ? 9 : 14))
            for patch in patches {
                let drift = CGPoint(
                    x: sin(time / 47 + patch.driftPhase) * 10,
                    y: cos(time / 53 + patch.driftPhase) * 7)
                let w = patch.radius * waterRect.width
                let h = w * patch.aspect
                let rect = CGRect(
                    x: waterRect.minX + patch.center.x * waterRect.width - w / 2 + drift.x,
                    y: waterRect.minY + patch.center.y * waterRect.height - h / 2 + drift.y,
                    width: w, height: h)
                layer.fill(Path(ellipseIn: rect),
                           with: .color(patch.light
                                        ? Color.white.opacity(0.06)
                                        : Color.pondWaterDeep.opacity(0.5)))
            }
        }

        drawGrain(in: water, over: waterRect)

        func point(_ unit: CGPoint) -> CGPoint {
            CGPoint(x: waterRect.minX + unit.x * waterRect.width,
                    y: waterRect.minY + unit.y * waterRect.height)
        }

        // Fish glide under the surface; birds paddle on it.
        for swimmer in swimmers where swimmer.isFish {
            let pos = point(swimmer.unitPosition(at: time))
            let v = swimmer.unitVelocity(at: time)
            let heading = Angle(radians: atan2(v.dy * waterRect.height, v.dx * waterRect.width))
            let cycle = (time + swimmer.surfacePhase)
                .truncatingRemainder(dividingBy: swimmer.surfacePeriod)
            let surfacing = cycle < 3 ? sin(.pi * cycle / 3) : 0
            let opacity = 0.34 + 0.4 * surfacing
            PondCreatureArt.drawFish(
                in: water, kind: swimmer.kind, at: pos, heading: heading,
                tailWiggle: time * 3.2 + swimmer.wigglePhase,
                opacity: opacity, scale: creatureScale)
            if surfacing > 0.05 {
                drawRipple(in: water, at: pos, age: cycle / 3 * 2.2, maxRadius: 20)
                drawRipple(in: water, at: pos, age: cycle / 3 * 2.2 - 0.6, maxRadius: 16)
            }
        }

        for swimmer in swimmers where !swimmer.isFish {
            // A quiet ripple ring left behind now and then.
            let rippleAge = (time + swimmer.wigglePhase)
                .truncatingRemainder(dividingBy: swimmer.ripplePeriod)
            if rippleAge < 2.2 {
                let origin = point(swimmer.unitPosition(at: time - rippleAge))
                drawRipple(in: water, at: origin, age: rippleAge, maxRadius: 22)
            }

            let pos = point(swimmer.unitPosition(at: time))
            let v = swimmer.unitVelocity(at: time)
            let vx = v.dx * waterRect.width
            let vy = v.dy * waterRect.height
            let heading = Angle(radians: atan2(vy, vx))
            let speed = hypot(vx, vy)
            guard let style = PondCreatureArt.birdStyle(for: swimmer.kind) else { continue }
            PondCreatureArt.drawBird(
                in: water, style: style, at: pos, heading: heading,
                wiggle: time * 2.4 + swimmer.wigglePhase,
                wakeOpacity: min(0.28, Double(speed) / 7 * 0.28),
                scale: creatureScale)
        }

        // Reeds grow from the banks, over the water's edge. The hero strip
        // skips the top bank — tall blades would be cut by the card's clip.
        for reed in reeds where detail == .full || reed.base.y > 0.5 {
            drawReed(reed, in: context, waterRect: waterRect, time: time,
                     heightScale: detail == .hero ? 0.65 : 1.0)
        }
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

    private func drawReed(_ reed: Reed, in context: GraphicsContext,
                          waterRect: CGRect, time: TimeInterval, heightScale: CGFloat) {
        let base = CGPoint(x: waterRect.minX + reed.base.x * waterRect.width,
                           y: waterRect.minY + reed.base.y * waterRect.height)
        let sway = sin(time / 2.6 + reed.swayPhase) * 2.5
        let height = reed.height * heightScale
        let tip = CGPoint(x: base.x + reed.lean + sway, y: base.y - height)
        let control = CGPoint(x: base.x + reed.lean * 0.25, y: base.y - height * 0.55)

        var blade = Path()
        blade.move(to: base)
        blade.addQuadCurve(to: tip, control: control)
        let green = Color.reedGreen.opacity(0.55 + 0.4 * reed.shade)
        context.stroke(blade, with: .color(green),
                       style: StrokeStyle(lineWidth: reed.width, lineCap: .round))

        if reed.hasCattail {
            // The velvety brown head sits just below the tip, along the blade.
            let angle = atan2(tip.y - control.y, tip.x - control.x)
            var c = context
            c.translateBy(x: tip.x, y: tip.y)
            c.rotate(by: Angle(radians: angle + .pi / 2))
            c.fill(Path(roundedRect: CGRect(x: -1.8, y: -1, width: 3.6, height: 10),
                        cornerRadius: 1.8),
                   with: .color(.cattail))
        }
    }

    /// Extra grain over the water only — the texture that makes it read as
    /// a printed picture-book page.
    private func drawGrain(in context: GraphicsContext, over rect: CGRect) {
        var c = context
        c.blendMode = .overlay
        c.opacity = 0.12
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
