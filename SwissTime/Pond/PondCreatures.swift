import SwiftUI

/// Top-down creature drawings: simple layered shapes, deadpan and flat,
/// in the spirit of a picture book. All code-drawn — no assets.
enum PondCreatureArt {
    struct BirdStyle {
        let body: Color
        let shade: Color
        let wing: Color
        let beak: Color
        let darkHead: Bool
        let speckled: Bool
        let size: CGFloat
    }

    static let gooseDark = Color(red: 0.24, green: 0.27, blue: 0.25)

    static func birdStyle(for kind: CreatureKind) -> BirdStyle? {
        switch kind {
        case .drake:
            return BirdStyle(body: .white,
                             shade: Color(red: 0.94, green: 0.93, blue: 0.89),
                             wing: Color(red: 0.90, green: 0.88, blue: 0.83),
                             beak: .beakOchre, darkHead: false, speckled: false, size: 1.0)
        case .hen:
            return BirdStyle(body: Color(red: 0.85, green: 0.76, blue: 0.60),
                             shade: Color(red: 0.79, green: 0.69, blue: 0.52),
                             wing: Color(red: 0.73, green: 0.63, blue: 0.46),
                             beak: .beakOchre, darkHead: false, speckled: true, size: 0.95)
        case .duckling:
            return BirdStyle(body: Color(red: 0.89, green: 0.75, blue: 0.39),
                             shade: Color(red: 0.83, green: 0.69, blue: 0.32),
                             wing: Color(red: 0.78, green: 0.63, blue: 0.28),
                             beak: .beakOchre, darkHead: false, speckled: false, size: 0.58)
        case .goose:
            return BirdStyle(body: Color(red: 0.78, green: 0.79, blue: 0.76),
                             shade: Color(red: 0.71, green: 0.72, blue: 0.69),
                             wing: Color(red: 0.64, green: 0.66, blue: 0.62),
                             beak: gooseDark, darkHead: true, speckled: false, size: 1.3)
        case .koi, .shadowFish:
            return nil
        }
    }

    /// Draws a paddling bird facing along `heading`. Local space: +x forward,
    /// body roughly 36 pt nose-to-tail at scale 1.
    static func drawBird(in context: GraphicsContext, style: BirdStyle, at point: CGPoint,
                         heading: Angle, wiggle: Double, wakeOpacity: Double, scale: CGFloat) {
        var c = context
        c.translateBy(x: point.x, y: point.y)
        c.rotate(by: heading)
        let s = scale * style.size
        c.scaleBy(x: s, y: s)

        // Wake trails behind, fading in with speed. Kept faint and short so
        // it reads as water, not wires.
        if wakeOpacity > 0.02 {
            var wake = Path()
            wake.move(to: CGPoint(x: -12, y: 0))
            wake.addQuadCurve(to: CGPoint(x: -23, y: -5.5),
                              control: CGPoint(x: -17, y: -1.5))
            wake.move(to: CGPoint(x: -12, y: 0))
            wake.addQuadCurve(to: CGPoint(x: -23, y: 5.5),
                              control: CGPoint(x: -17, y: 1.5))
            c.stroke(wake, with: .color(.white.opacity(min(wakeOpacity, 0.18))),
                     style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }

        c.rotate(by: .degrees(sin(wiggle) * 2.5))

        // Soft water shadow beneath the body.
        c.fill(Path(ellipseIn: CGRect(x: -13, y: -7, width: 27, height: 16.5)),
               with: .color(.black.opacity(0.10)))

        // Tail wedge, then a compact body split light/shade along the spine.
        var tail = Path()
        tail.move(to: CGPoint(x: -9, y: -3.6))
        tail.addLine(to: CGPoint(x: -16, y: 0))
        tail.addLine(to: CGPoint(x: -9, y: 3.6))
        tail.closeSubpath()
        c.fill(tail, with: .color(style.shade))

        let body = Path(ellipseIn: CGRect(x: -13, y: -8, width: 23, height: 16))
        c.fill(body, with: .color(style.body))
        var lower = c
        lower.clip(to: body)
        lower.fill(Path(CGRect(x: -13, y: 0, width: 23, height: 8)),
                   with: .color(style.shade))

        // Folded wings.
        c.fill(Path(ellipseIn: CGRect(x: -8.5, y: -7.2, width: 12, height: 5))
               , with: .color(style.wing))
        c.fill(Path(ellipseIn: CGRect(x: -8.5, y: 2.2, width: 12, height: 5)),
               with: .color(style.wing))

        if style.speckled {
            for spot in [CGPoint(x: -7, y: -2.5), CGPoint(x: -2, y: 3.5), CGPoint(x: 2, y: -3)] {
                c.fill(Path(ellipseIn: CGRect(x: spot.x, y: spot.y, width: 1.8, height: 1.8)),
                       with: .color(style.wing.opacity(0.9)))
            }
        }

        if style.darkHead {
            // Goose: dark neck reaching forward, dark head, white chin patch.
            var neck = Path()
            neck.move(to: CGPoint(x: 6, y: 0))
            neck.addLine(to: CGPoint(x: 14, y: 0))
            c.stroke(neck, with: .color(gooseDark),
                     style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
            c.fill(Path(ellipseIn: CGRect(x: 10.5, y: -4, width: 8, height: 8)),
                   with: .color(gooseDark))
            c.fill(Path(ellipseIn: CGRect(x: 12.2, y: -3.6, width: 4.2, height: 2.2)),
                   with: .color(.white.opacity(0.92)))
            var beak = Path()
            beak.move(to: CGPoint(x: 17.5, y: -1.5))
            beak.addLine(to: CGPoint(x: 21, y: 0))
            beak.addLine(to: CGPoint(x: 17.5, y: 1.5))
            beak.closeSubpath()
            c.fill(beak, with: .color(gooseDark))
        } else {
            // A clearly separated head: a shade ring first, then the head disc
            // sitting proud of the body, then a bigger beak.
            c.fill(Path(ellipseIn: CGRect(x: 7, y: -5.2, width: 10.4, height: 10.4)),
                   with: .color(style.shade))
            c.fill(Path(ellipseIn: CGRect(x: 8, y: -4.2, width: 8.4, height: 8.4)),
                   with: .color(style.body))
            var beak = Path()
            beak.move(to: CGPoint(x: 15.6, y: -2.4))
            beak.addLine(to: CGPoint(x: 20.5, y: 0))
            beak.addLine(to: CGPoint(x: 15.6, y: 2.4))
            beak.closeSubpath()
            c.fill(beak, with: .color(style.beak))
        }
    }

    /// Draws a fish facing along `heading`; caller sets opacity for depth.
    static func drawFish(in context: GraphicsContext, kind: CreatureKind, at point: CGPoint,
                         heading: Angle, tailWiggle: Double, opacity: Double, scale: CGFloat) {
        var c = context
        c.opacity = opacity
        c.translateBy(x: point.x, y: point.y)
        c.rotate(by: heading)
        c.scaleBy(x: scale, y: scale)

        let bodyColor = kind == .koi
            ? Color(red: 0.69, green: 0.41, blue: 0.30)
            : Color(red: 0.13, green: 0.19, blue: 0.25)

        // Tail swings around the body's rear joint.
        var tail = c
        tail.translateBy(x: -9, y: 0)
        tail.rotate(by: .degrees(sin(tailWiggle) * 14))
        var fin = Path()
        fin.move(to: CGPoint(x: 0, y: 0))
        fin.addLine(to: CGPoint(x: -8.5, y: -4.5))
        fin.addLine(to: CGPoint(x: -8.5, y: 4.5))
        fin.closeSubpath()
        tail.fill(fin, with: .color(bodyColor))

        c.fill(Path(ellipseIn: CGRect(x: -11, y: -4.5, width: 24, height: 9)),
               with: .color(bodyColor))
        // Side fins.
        c.fill(Path(ellipseIn: CGRect(x: -1, y: -6.5, width: 5, height: 3)),
               with: .color(bodyColor))
        c.fill(Path(ellipseIn: CGRect(x: -1, y: 3.5, width: 5, height: 3)),
               with: .color(bodyColor))
        if kind == .koi {
            c.fill(Path(ellipseIn: CGRect(x: 0, y: -2.5, width: 8, height: 5)),
                   with: .color(Color(red: 0.88, green: 0.79, blue: 0.66).opacity(0.85)))
        }
    }
}
