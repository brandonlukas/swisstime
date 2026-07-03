import SwiftUI
import CoreMotion

/// Feeds device gravity to the water. The surface stays level in the world,
/// so its screen-space slope is g.x/g.y — tilt the phone and the water
/// holds its horizon. Polled per frame, never published: motion must not
/// invalidate views.
final class WaterMotion {
    private let manager = CMMotionManager()
    private(set) var slope: Double = 0

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let gravity = motion?.gravity else { return }
            // Upright portrait is (0, -1, 0). Right edge down → g.x > 0 →
            // negative slope → the water climbs the right side, like a
            // carried glass. Clamping g.y keeps a face-up phone (g.y ≈ 0,
            // no usable direction) stable, and the slope clamp keeps an
            // extreme tilt from wedging the whole screen.
            let raw = gravity.x / min(gravity.y, -0.35)
            self?.slope = max(-0.55, min(0.55, raw))
        }
    }

    func stop() {
        guard manager.isDeviceMotionActive else { return }
        manager.stopDeviceMotionUpdates()
    }
}

/// One answer to "how hard should the water work right now", shared by the
/// player and the Sets tab so the two screens can never disagree about what
/// calm means. Reduce Motion flattens the surface entirely; Low Power Mode
/// halves the clock, slows the texture beat, and rests the tilt sensor.
struct WaterPolicy {
    let fps: Double
    let textureBeat: Double
    let rippleAmp: CGFloat
    let tiltEnabled: Bool
    let calm: Bool

    init(lowPower: Bool, reduceMotion: Bool) {
        fps = lowPower ? 15 : 30
        textureBeat = lowPower ? 1 : 4
        rippleAmp = reduceMotion ? 0 : 1.6
        tiltEnabled = !reduceMotion && !lowPower
        calm = reduceMotion
    }
}

/// The waterline's temperament, advanced once per timeline frame (a plain
/// reference like LevelSpring — its mutations must not invalidate views).
/// The slope chases gravity through an underdamped spring, so a tilt
/// sloshes past level before settling; chop is splash energy — kicked up
/// by step jumps and fast sloshing, decaying smoothly to a resting ripple.
final class WaterSurfaceModel {
    private var slope = 0.0
    private var slopeVelocity = 0.0
    private var chop = 0.0
    private var lastTarget: Double?
    private var lastTime: Date?

    struct Surface {
        var slope: CGFloat
        var chop: CGFloat
    }

    func advance(targetFraction: Double, gravitySlope: Double, at now: Date,
                 calm: Bool = false) -> Surface {
        guard let last = lastTime else {
            lastTime = now
            slope = gravitySlope
            lastTarget = targetFraction
            return Surface(slope: slope, chop: 0)
        }
        let dt = min(0.1, max(0, now.timeIntervalSince(last)))
        lastTime = now

        // A target jump (new step, skip, finish, Lap) throws the water —
        // the same discontinuity test LevelSpring uses for its spring.
        // Under Reduce Motion (`calm`) nothing may excite chop: the flat
        // line is a promise, not a default.
        if calm {
            chop = 0
        } else if let lastTarget, abs(targetFraction - lastTarget) > 0.02 {
            chop = min(1.4, chop + abs(targetFraction - lastTarget) * 2.5 + 0.35)
        }
        lastTarget = targetFraction

        // Fixed substeps, matching LevelSpring: stable through hitches.
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120.0)
            remaining -= h
            slopeVelocity += (-26 * (slope - gravitySlope) - 5.2 * slopeVelocity) * h
            slope += slopeVelocity * h
        }
        // Sloshing hard kicks up chop of its own.
        if !calm {
            chop = min(1.4, chop + abs(slopeVelocity) * dt * 1.4)
            chop *= exp(-dt * 1.5)
        }
        return Surface(slope: slope, chop: chop)
    }
}

/// The water body as a shape: everything below a surface polyline built
/// from the level, the tilt slope, and two counter-travelling chop waves.
/// Filled, it's the reveal mask for a water fill; with `crest` it becomes
/// just the surface line, for stroking a highlight along the waterline.
struct WaterSurfaceShape: Shape {
    var level: CGFloat        // px of water, measured up from the rect's bottom
    var slope: CGFloat
    var chop: CGFloat
    var time: Double
    /// The resting ripple, so the line feels alive even in still water.
    /// Pass 0 under Reduce Motion (with slope and chop zeroed, the line
    /// is flat and only the level moves — the old behavior).
    var rippleAmp: CGFloat = 1.6
    var crest = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard level > 0.5 else { return path }
        let amp = rippleAmp + 9 * chop

        func surfaceY(_ x: CGFloat) -> CGFloat {
            let wave = sin(x / 34 + time * 2.6) * 0.62
                + sin(x / 12.5 - time * 4.1 + 1.7) * 0.38
            return rect.maxY - level + (x - rect.midX) * slope + wave * amp
        }

        path.move(to: CGPoint(x: rect.minX, y: surfaceY(rect.minX)))
        var x = rect.minX
        while x < rect.maxX {
            x = min(x + 9, rect.maxX)
            path.addLine(to: CGPoint(x: x, y: surfaceY(x)))
        }
        if !crest {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// The visible waterline: a bright crest with a soft submerged band under
/// it — drawn over the masked water so the surface reads as a surface.
struct WaterSurfaceCrest: View {
    let level: CGFloat
    let surface: WaterSurfaceModel.Surface
    let time: Double
    var rippleAmp: CGFloat = 1.6

    var body: some View {
        ZStack {
            WaterSurfaceShape(level: level - 3.5, slope: surface.slope,
                              chop: surface.chop, time: time,
                              rippleAmp: rippleAmp, crest: true)
                .stroke(Color.white.opacity(0.14), lineWidth: 5)
            WaterSurfaceShape(level: level, slope: surface.slope,
                              chop: surface.chop, time: time,
                              rippleAmp: rippleAmp, crest: true)
                .stroke(Color.white.opacity(0.5), lineWidth: 1.4)
        }
        .allowsHitTesting(false)
    }
}
