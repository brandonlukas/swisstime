// Renders the Lido app icon (concept 01, "The Pool") natively at 2048²,
// then downsamples to 1024: the hero card as a mark — tiled water, one
// rubber duck, hard afternoon sun shadow. Geometry ports PoolToyArt's
// top-down duck at icon scale.
//
// Three renders share the drawing, only the palette changes:
//   lido-1024.png         the day pool (Any appearance)
//   lido-1024-dark.png    night swim — moonlit navy water, same duck
//   lido-1024-tinted.png  grayscale for the system tint: luminance is the
//                         message, so the water goes near-black and the
//                         duck near-white
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

struct Palette {
    let pool: CGColor
    let groutDark: CGColor
    let groutLight: CGColor
    let deepBlob: CGColor        // caustic shade, upper left
    let glowBlob: CGColor        // caustic light, lower right (alpha in color)
    let ripple: CGColor
    let duckBody: CGColor
    let duckShade: CGColor
    let duckBeak: CGColor
    let ink: CGColor
    let castShadow: CGColor      // the duck's sun (or moon) shadow
    let catchLight: CGColor
}

let day = Palette(
    pool: rgb(0.169, 0.451, 0.788),          // #2B73C9
    groutDark: rgb(0.055, 0.243, 0.494, 0.34),
    groutLight: rgb(1, 1, 1, 0.26),
    deepBlob: rgb(0.078, 0.271, 0.561, 0.5), // #14458F
    glowBlob: rgb(1, 1, 1, 0.14),
    ripple: rgb(1, 1, 1, 0.15),
    duckBody: rgb(1.0, 0.796, 0.20),         // #FFCB33
    duckShade: rgb(0.89, 0.659, 0.11),       // #E3A81C
    duckBeak: rgb(0.941, 0.455, 0.165),      // #F0742A
    ink: rgb(0.075, 0.13, 0.28),
    castShadow: rgb(0.031, 0.129, 0.29, 0.28),
    catchLight: rgb(1, 1, 1, 0.55))

// Night swim: the pool after close, moonlit. The duck keeps its vinyl
// yellow — the one warm thing on the dark water is the whole idea.
let night = Palette(
    pool: rgb(0.051, 0.141, 0.318),          // #0D2451
    groutDark: rgb(0.016, 0.075, 0.196, 0.45),
    groutLight: rgb(0.62, 0.78, 1.0, 0.14),
    deepBlob: rgb(0.016, 0.063, 0.176, 0.55),
    glowBlob: rgb(0.85, 0.92, 1.0, 0.10),
    ripple: rgb(1, 1, 1, 0.10),
    duckBody: rgb(1.0, 0.796, 0.20),
    duckShade: rgb(0.85, 0.62, 0.10),
    duckBeak: rgb(0.90, 0.42, 0.15),
    ink: rgb(0.05, 0.09, 0.20),
    castShadow: rgb(0.0, 0.031, 0.11, 0.5),
    catchLight: rgb(1, 1, 1, 0.65))

// Tinted: the system maps luminance onto its tint gradient, so this is the
// composition restated in grayscale — dark water, bright duck.
let tinted = Palette(
    pool: gray(0.17),
    groutDark: gray(0.05, 0.5),
    groutLight: gray(1.0, 0.14),
    deepBlob: gray(0.06, 0.5),
    glowBlob: gray(1.0, 0.10),
    ripple: gray(1.0, 0.12),
    duckBody: gray(0.92),
    duckShade: gray(0.60),
    duckBeak: gray(0.52),
    ink: gray(0.04),
    castShadow: gray(0.0, 0.38),
    catchLight: gray(1.0, 0.7))

func render(_ p: Palette) -> CGImage {
    let ctx = makeContext(S)
    // Flip to top-left origin so the mockup's coordinates read straight across.
    ctx.translateBy(x: 0, y: CGFloat(S))
    ctx.scaleBy(x: scale, y: -scale)

    // 1 · Water.
    ctx.setFillColor(p.pool)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

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

    // 3 · Caustic light: soft radial blobs, gradient-faded so no blur needed.
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
    blob(cx: 290, cy: 250, rx: 440, ry: 290, color: p.deepBlob)
    blob(cx: 770, cy: 810, rx: 400, ry: 260, color: p.glowBlob)

    // 4 · A quiet ripple ring around the duck.
    ctx.setStrokeColor(p.ripple)
    ctx.setLineWidth(9)
    ctx.strokeEllipse(in: CGRect(x: 565 - 320, y: 470 - 320, width: 640, height: 640))

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

    return ctx.makeImage()!
}

// 6 · Downsample and write.
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
