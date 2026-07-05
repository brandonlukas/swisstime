// Renders the Lido app icon (concept 01, "The Pool") natively at 2048²,
// then downsamples to 1024: the hero card as a mark — tiled water, one
// rubber duck, hard afternoon sun shadow. Geometry ports PoolToyArt's
// top-down duck at icon scale.
//
// Three renders share the drawing, only the palette changes:
//   lido-1024.png         the day pool (Any appearance)
//   lido-1024-dark.png    Night Swim (naming-artifact concept 05): the
//                         gilded duck under a pool light — radial glow on
//                         near-black navy, sparkle glints — but with the
//                         day icon's duck placement, ripple ring, and grout
//   lido-1024-tinted.png  the night composition in grayscale: the system
//                         maps luminance onto the user's tint, so contrast
//                         is pushed hard — near-black field, white duck
// Run:  swift lido_icon.swift <output-dir>
import AppKit

let S = 2048
let scale = CGFloat(S) / 1024.0   // design coordinates are the 1024 mockup's

func makeContext(_ side: Int) -> CGContext {
    CGContext(data: nil, width: side, height: side,
              bitsPerComponent: 8, bytesPerRow: side * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [r, g, b, a])!
}

func gray(_ w: CGFloat, _ a: CGFloat = 1) -> CGColor { rgb(w, w, w, a) }

/// The night pool light: a radial gradient disc, alpha baked into the stops.
struct Glow {
    let cx: CGFloat, cy: CGFloat, r: CGFloat
    let colors: [CGColor]
    let locations: [CGFloat]
}

struct Palette {
    let pool: CGColor
    /// Day caustics — two soft blobs (shade upper-left, light lower-right).
    let blobs: (deep: CGColor, glow: CGColor)?
    /// Night pool light; drawn instead of the blobs.
    let glow: Glow?
    let groutDark: CGColor
    let groutLight: CGColor
    let ripple: CGColor
    let duckBody: CGColor
    let duckShade: CGColor
    let duckBeak: CGColor
    let ink: CGColor
    let castShadow: CGColor      // the duck's sun (or moon) shadow
    let catchLight: CGColor
    /// The quiet ripple ring around the duck.
    let ring: Bool
    /// Night sparkles (the artifact's #glint crosses).
    let glints: Bool
    let glintColor: CGColor
}

let day = Palette(
    pool: rgb(0.169, 0.451, 0.788),          // #2B73C9
    blobs: (deep: rgb(0.078, 0.271, 0.561, 0.5),   // #14458F
            glow: rgb(1, 1, 1, 0.14)),
    glow: nil,
    groutDark: rgb(0.055, 0.243, 0.494, 0.34),
    groutLight: rgb(1, 1, 1, 0.26),
    ripple: rgb(1, 1, 1, 0.15),
    duckBody: rgb(1.0, 0.796, 0.20),         // #FFCB33
    duckShade: rgb(0.89, 0.659, 0.11),       // #E3A81C
    duckBeak: rgb(0.941, 0.455, 0.165),      // #F0742A
    ink: rgb(0.075, 0.13, 0.28),
    castShadow: rgb(0.031, 0.129, 0.29, 0.28),
    catchLight: rgb(1, 1, 1, 0.55),
    ring: true,
    glints: false, glintColor: rgb(1, 1, 1))

// Night Swim, colors straight from the naming artifact's concept 05:
// #20264C water, the #3B82D9→#2B66BC pool-light glow, the gilded duck
// (#F5EFDF / #D9CDAF / #D9A94E), #060B22 shadow.
let night = Palette(
    pool: rgb(0.125, 0.149, 0.298),          // #20264C
    blobs: nil,
    glow: Glow(cx: 512, cy: 700, r: 620,
               colors: [rgb(0.231, 0.510, 0.851, 0.95),   // #3B82D9
                        rgb(0.169, 0.400, 0.737, 0.45),   // #2B66BC
                        rgb(0.169, 0.400, 0.737, 0.0)],
               locations: [0, 0.55, 1]),
    groutDark: rgb(0.024, 0.043, 0.133, 0.30),            // #060B22
    groutLight: rgb(1, 1, 1, 0.08),
    ripple: rgb(1, 1, 1, 0.12),
    duckBody: rgb(0.961, 0.937, 0.875),      // #F5EFDF
    duckShade: rgb(0.851, 0.804, 0.686),     // #D9CDAF
    duckBeak: rgb(0.851, 0.663, 0.306),      // #D9A94E
    ink: rgb(0.075, 0.13, 0.28),             // #13213F
    castShadow: rgb(0.024, 0.043, 0.133, 0.4),            // #060B22
    catchLight: rgb(1, 1, 1, 0.55),
    ring: false,                              // concept 05 has no ring
    glints: true, glintColor: rgb(1, 1, 1))

// Tinted: the composition at maximum luminance contrast — flat near-black
// field, pure white duck, no glow or sparkles. The system maps luminance
// onto the tint color, so the duck carries the whole tint and the field
// stays dark whatever color the user picks.
let tinted = Palette(
    pool: gray(0.04),
    blobs: nil,
    glow: nil,
    groutDark: gray(0.0, 0.30),
    groutLight: gray(1.0, 0.11),
    ripple: gray(1.0, 0.13),
    duckBody: gray(1.0),
    duckShade: gray(0.62),
    duckBeak: gray(0.50),
    ink: gray(0.0),
    castShadow: gray(0.0, 0.5),
    catchLight: gray(1.0, 0.7),
    ring: true,
    glints: false, glintColor: gray(1.0))

func render(_ p: Palette) -> CGImage {
    let ctx = makeContext(S)
    // Flip to top-left origin so the mockup's coordinates read straight across.
    ctx.translateBy(x: 0, y: CGFloat(S))
    ctx.scaleBy(x: scale, y: -scale)

    // 1 · Water — flat day blue, or the night field with its pool light.
    ctx.setFillColor(p.pool)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    if let glow = p.glow {
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: glow.colors as CFArray,
                              locations: glow.locations)!
        ctx.drawRadialGradient(grad,
                               startCenter: CGPoint(x: glow.cx, y: glow.cy),
                               startRadius: 0,
                               endCenter: CGPoint(x: glow.cx, y: glow.cy),
                               endRadius: glow.r, options: [])
    }

    // 2 · Grout: 3×3 cells, each line a long sine — period 682, amplitude 9.
    // The dark pass sits offset below-right, embossing the joints.
    func groutPath(vertical: Bool, at position: CGFloat, flip: CGFloat) -> CGPath {
        let path = CGMutablePath()
        var along: CGFloat = 0
        let wob = { (t: CGFloat) in 9 * flip * sin(2 * .pi * t / 682) }
        if vertical {
            path.move(to: CGPoint(x: position + wob(0), y: 0))
            while along < 1024 { along += 8
                path.addLine(to: CGPoint(x: position + wob(along), y: along)) }
        } else {
            path.move(to: CGPoint(x: 0, y: position + wob(0)))
            while along < 1024 { along += 8
                path.addLine(to: CGPoint(x: along, y: position + wob(along))) }
        }
        return path
    }
    ctx.setLineCap(.round)
    for pass in 0..<2 {
        ctx.saveGState()
        if pass == 0 {
            ctx.translateBy(x: 10, y: 10)
            ctx.setStrokeColor(p.groutDark); ctx.setLineWidth(21)
        } else {
            ctx.setStrokeColor(p.groutLight); ctx.setLineWidth(19)
        }
        var flip: CGFloat = 1
        for line in [341.0, 683.0] {
            ctx.addPath(groutPath(vertical: true, at: line, flip: flip))
            ctx.addPath(groutPath(vertical: false, at: line, flip: -flip))
            flip = -flip
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 3 · Day caustics: soft radial blobs, gradient-faded so no blur needed.
    if let blobs = p.blobs {
        func blob(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat, color: CGColor) {
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.scaleBy(x: rx, y: ry)
            let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  colors: [color, color.copy(alpha: 0)!] as CFArray,
                                  locations: [0, 1])!
            ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 0,
                                   endCenter: .zero, endRadius: 1, options: [])
            ctx.restoreGState()
        }
        blob(cx: 290, cy: 250, rx: 440, ry: 290, color: blobs.deep)
        blob(cx: 770, cy: 810, rx: 400, ry: 260, color: blobs.glow)
    }

    // 4 · A quiet ripple ring around the duck.
    if p.ring {
        ctx.setStrokeColor(p.ripple)
        ctx.setLineWidth(9)
        ctx.strokeEllipse(in: CGRect(x: 565 - 320, y: 470 - 320, width: 640, height: 640))
    }

    // 5 · The duck, twice: cast-shadow silhouette first, then the vinyl.
    // Local space: +x forward, ~518 units nose to tail (PoolToyArt × 14).
    func duckSilhouette(into c: CGContext) {
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -126, y: -50))
        tail.addLine(to: CGPoint(x: -217, y: 0))
        tail.addLine(to: CGPoint(x: -126, y: 50))
        tail.closeSubpath()
        c.addPath(tail)
        c.addEllipse(in: CGRect(x: -182, y: -112, width: 322, height: 224))
        c.addEllipse(in: CGRect(x: 91, y: -77, width: 154, height: 154))
        let beak = CGMutablePath()
        beak.move(to: CGPoint(x: 224, y: -36))
        beak.addLine(to: CGPoint(x: 301, y: 0))
        beak.addLine(to: CGPoint(x: 224, y: 36))
        beak.closeSubpath()
        c.addPath(beak)
    }

    func placeDuck(dx: CGFloat, dy: CGFloat, body: () -> Void) {
        ctx.saveGState()
        ctx.translateBy(x: 560 + dx, y: 460 + dy)
        ctx.rotate(by: -20 * .pi / 180)
        body()
        ctx.restoreGState()
    }

    placeDuck(dx: 40, dy: 68) {
        duckSilhouette(into: ctx)
        ctx.setFillColor(p.castShadow)
        ctx.fillPath()
    }

    placeDuck(dx: 0, dy: 0) {
        // Tail wedge, hull, molded wing bumps.
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -126, y: -50))
        tail.addLine(to: CGPoint(x: -217, y: 0))
        tail.addLine(to: CGPoint(x: -126, y: 50))
        tail.closeSubpath()
        ctx.addPath(tail)
        ctx.setFillColor(p.duckShade)
        ctx.fillPath()

        ctx.setFillColor(p.duckBody)
        ctx.fillEllipse(in: CGRect(x: -182, y: -112, width: 322, height: 224))

        ctx.setFillColor(p.duckShade.copy(alpha: 0.55)!)
        ctx.fillEllipse(in: CGRect(x: -119, y: -101, width: 168, height: 70))
        ctx.fillEllipse(in: CGRect(x: -119, y: 31, width: 168, height: 70))

        // Head proud of the body, beak reaching forward.
        ctx.setFillColor(p.duckBody)
        ctx.fillEllipse(in: CGRect(x: 91, y: -77, width: 154, height: 154))
        let beak = CGMutablePath()
        beak.move(to: CGPoint(x: 224, y: -36))
        beak.addLine(to: CGPoint(x: 301, y: 0))
        beak.addLine(to: CGPoint(x: 224, y: 36))
        beak.closeSubpath()
        ctx.addPath(beak)
        ctx.setFillColor(p.duckBeak)
        ctx.fillPath()

        // Painted eyes on both sides, and a vinyl catch-light on the crown.
        ctx.setFillColor(p.ink)
        ctx.fillEllipse(in: CGRect(x: 157, y: -63, width: 30, height: 30))
        ctx.fillEllipse(in: CGRect(x: 157, y: 33, width: 30, height: 30))
        ctx.setFillColor(p.catchLight)
        ctx.fillEllipse(in: CGRect(x: 102, y: -54, width: 52, height: 32))
    }

    // 6 · Night sparkles — the artifact's #glint crosses, at concept 05's
    // own positions (no ring to clear here).
    if p.glints {
        func glint(cx: CGFloat, cy: CGFloat, s: CGFloat, alpha: CGFloat) {
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.scaleBy(x: s, y: s)
            ctx.setStrokeColor(p.glintColor.copy(alpha: alpha)!)
            ctx.setLineCap(.round)
            ctx.setLineWidth(17)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: -62, y: 0)); ctx.addLine(to: CGPoint(x: 62, y: 0))
            ctx.move(to: CGPoint(x: 0, y: -62)); ctx.addLine(to: CGPoint(x: 0, y: 62))
            ctx.strokePath()
            ctx.setLineWidth(11)
            ctx.setStrokeColor(p.glintColor.copy(alpha: alpha * 0.8)!)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: -24, y: -24)); ctx.addLine(to: CGPoint(x: 24, y: 24))
            ctx.move(to: CGPoint(x: -24, y: 24)); ctx.addLine(to: CGPoint(x: 24, y: -24))
            ctx.strokePath()
            ctx.restoreGState()
        }
        glint(cx: 788, cy: 268, s: 1.0, alpha: 0.95)
        glint(cx: 250, cy: 748, s: 0.55, alpha: 0.6)
    }

    return ctx.makeImage()!
}

// 7 · Downsample and write.
func write(_ image: CGImage, side: Int, to path: String) {
    let out = makeContext(side)
    out.interpolationQuality = .high
    out.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}
let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let full = render(day)
write(full, side: 1024, to: "\(dir)/lido-1024.png")
write(full, side: 180, to: "\(dir)/lido-180.png")
write(full, side: 120, to: "\(dir)/lido-120.png")
write(render(night), side: 1024, to: "\(dir)/lido-1024-dark.png")
write(render(tinted), side: 1024, to: "\(dir)/lido-1024-tinted.png")
print("done")
