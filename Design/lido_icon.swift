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

// Night Swim, water straight from the naming artifact's concept 05 —
// #20264C, the #3B82D9→#2B66BC pool-light glow, #060B22 shadow — but the
// day icon's own vinyl-yellow duck and ripple ring, no sparkles: the same
// duck, the pool after close.
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
    duckBody: rgb(1.0, 0.796, 0.20),         // #FFCB33
    duckShade: rgb(0.89, 0.659, 0.11),       // #E3A81C
    duckBeak: rgb(0.941, 0.455, 0.165),      // #F0742A
    ink: rgb(0.075, 0.13, 0.28),             // #13213F
    castShadow: rgb(0.024, 0.043, 0.133, 0.4),            // #060B22
    catchLight: rgb(1, 1, 1, 0.55),
    ring: true,
    glints: false, glintColor: rgb(1, 1, 1))

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

/// Steps 1–3 of the pool mark: the water, its grout, and the day caustics
/// or night glow. Shared by the duck icon and the Pool Type wordmark icon.
func drawWater(_ ctx: CGContext, _ p: Palette) {
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
}

func render(_ p: Palette) -> CGImage {
    let ctx = makeContext(S)
    // Flip to top-left origin so the mockup's coordinates read straight across.
    ctx.translateBy(x: 0, y: CGFloat(S))
    ctx.scaleBy(x: scale, y: -scale)

    drawWater(ctx, p)

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

// =========================================================== Pool Type ===
// The wordmark alternate (naming-artifact concept W5b): LIDO in the app's
// own poster caps — SF expanded heavy, the Text.display voice — printed
// flat on the same water as the duck icon. No duck, no ring, no shadow:
// the letters read as painted on the pool floor.

func renderPoolType(_ p: Palette, textColor: CGColor) -> CGImage {
    let ctx = makeContext(S)
    ctx.translateBy(x: 0, y: CGFloat(S))
    ctx.scaleBy(x: scale, y: -scale)

    drawWater(ctx, p)

    // The artifact's metrics: ~880 wide on the 1024 canvas, baseline 622.
    let size: CGFloat = 330
    let font = NSFont.systemFont(ofSize: size, weight: .heavy, width: .expanded)
    let text = NSAttributedString(string: "LIDO", attributes: [
        .font: font,
        .foregroundColor: NSColor(cgColor: textColor)!,
        .kern: size * 0.05,   // Text.display's tracking
    ])
    let line = CTLineCreateWithAttributedString(text)
    // The trailing kern pads the typographic width; trim it so the
    // wordmark centers on what's visible.
    let visual = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) - size * 0.05
    let squeeze = min(1, 880 / visual)
    ctx.saveGState()
    ctx.translateBy(x: 512 - visual * squeeze / 2, y: 622)
    // Our space is y-down; CoreText draws y-up.
    ctx.scaleBy(x: squeeze, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    return ctx.makeImage()!
}

// ============================================================ Deep End ===
// The alternate icon (naming-artifact concept 03): the pool corner with its
// ladder — deck tiles, one rounded corner of wavy-grouted water, coping,
// and the three-pass ladder (cast shadow, drowned rails, dry top). The most
// liminal and architectural of the marks; user-selectable in Settings.

struct DeepPalette {
    let deck: CGColor
    let deckLine: CGColor
    let pool: CGColor
    /// Day caustics inside the water (deep shade + light), or nil.
    let blobs: (deep: CGColor, light: CGColor)?
    /// Night pool light inside the water, or nil.
    let glow: Glow?
    let groutDark: CGColor
    let groutLight: CGColor
    let coping: CGColor
    let ladderShadow: CGColor
    let ladderWet: CGColor       // the drowned rails, refracted pale
    let ladderDry: CGColor       // above the waterline
}

let deepDay = DeepPalette(
    deck: rgb(0.761, 0.843, 0.914),          // #C2D7E9
    deckLine: rgb(0.624, 0.733, 0.839, 0.85),// #9FBBD6
    pool: rgb(0.169, 0.451, 0.788),          // #2B73C9
    blobs: (deep: rgb(0.078, 0.271, 0.561, 0.55),   // #14458F
            light: rgb(1, 1, 1, 0.12)),
    glow: nil,
    groutDark: rgb(0.055, 0.243, 0.494, 0.30),      // #0E3E7E
    groutLight: rgb(1, 1, 1, 0.16),
    coping: rgb(1, 1, 1, 0.55),
    ladderShadow: rgb(0.039, 0.173, 0.361, 0.18),   // #0A2C5C
    ladderWet: rgb(0.863, 0.914, 0.961, 0.55),      // #DCE9F5
    ladderDry: rgb(0.937, 0.961, 0.984))            // #EFF5FB

// The deck after close: near-black slate, the water lit from within by the
// same pool light as the night swim mark.
let deepNight = DeepPalette(
    deck: rgb(0.075, 0.086, 0.157),          // #131628
    deckLine: rgb(1, 1, 1, 0.07),
    pool: rgb(0.125, 0.149, 0.298),          // #20264C
    blobs: nil,
    glow: Glow(cx: 680, cy: 760, r: 600,
               colors: [rgb(0.231, 0.510, 0.851, 0.95),   // #3B82D9
                        rgb(0.169, 0.400, 0.737, 0.45),   // #2B66BC
                        rgb(0.169, 0.400, 0.737, 0.0)],
               locations: [0, 0.55, 1]),
    groutDark: rgb(0.024, 0.043, 0.133, 0.30),      // #060B22
    groutLight: rgb(1, 1, 1, 0.08),
    coping: rgb(1, 1, 1, 0.40),
    ladderShadow: rgb(0.024, 0.043, 0.133, 0.40),   // #060B22
    ladderWet: rgb(0.863, 0.914, 0.961, 0.35),
    ladderDry: rgb(0.937, 0.961, 0.984))

// Tinted: flat and extreme, like the duck's — the dry ladder and coping
// carry the tint, the field stays near-black.
let deepTinted = DeepPalette(
    deck: gray(0.04),
    deckLine: gray(1.0, 0.10),
    pool: gray(0.11),
    blobs: nil,
    glow: nil,
    groutDark: gray(0.0, 0.30),
    groutLight: gray(1.0, 0.10),
    coping: gray(1.0, 0.55),
    ladderShadow: gray(0.0, 0.5),
    ladderWet: gray(1.0, 0.40),
    ladderDry: gray(1.0))

func renderDeepEnd(_ p: DeepPalette) -> CGImage {
    let ctx = makeContext(S)
    ctx.translateBy(x: 0, y: CGFloat(S))
    ctx.scaleBy(x: scale, y: -scale)

    // 1 · The deck: straight tile lines, a finer 6×6 grid.
    ctx.setFillColor(p.deck)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    ctx.setStrokeColor(p.deckLine)
    ctx.setLineWidth(8)
    ctx.beginPath()
    for line in [172.0, 342, 512, 682, 852] {
        ctx.move(to: CGPoint(x: line, y: 0)); ctx.addLine(to: CGPoint(x: line, y: 1024))
        ctx.move(to: CGPoint(x: 0, y: line)); ctx.addLine(to: CGPoint(x: 1024, y: line))
    }
    ctx.strokePath()

    // 2 · The water: one rounded corner, running off the right and bottom.
    let poolRect = CGRect(x: 240, y: 330, width: 1000, height: 900)
    let poolPath = CGPath(roundedRect: poolRect, cornerWidth: 110,
                          cornerHeight: 110, transform: nil)
    ctx.saveGState()
    ctx.addPath(poolPath)
    ctx.clip()
    ctx.setFillColor(p.pool)
    ctx.fill(poolRect)
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

    // Wavy grout under the water, offset so it never lines up with the
    // deck's grid — the artifact's translate(70 40), sine period 340.
    func wavyLine(vertical: Bool, at position: CGFloat, flip: CGFloat) -> CGPath {
        let path = CGMutablePath()
        var along: CGFloat = 0
        let wob = { (t: CGFloat) in 6 * flip * sin(2 * .pi * t / 340) }
        if vertical {
            path.move(to: CGPoint(x: position + wob(0), y: 0))
            while along < 1300 { along += 8
                path.addLine(to: CGPoint(x: position + wob(along), y: along)) }
        } else {
            path.move(to: CGPoint(x: 0, y: position + wob(0)))
            while along < 1300 { along += 8
                path.addLine(to: CGPoint(x: along, y: position + wob(along))) }
        }
        return path
    }
    ctx.setLineCap(.round)
    for pass in 0..<2 {
        ctx.saveGState()
        if pass == 0 {
            ctx.translateBy(x: 77, y: 47)
            ctx.setStrokeColor(p.groutDark); ctx.setLineWidth(11)
        } else {
            ctx.translateBy(x: 70, y: 40)
            ctx.setStrokeColor(p.groutLight); ctx.setLineWidth(9)
        }
        var flip: CGFloat = 1
        for line in [172.0, 342, 512, 682, 852] {
            ctx.addPath(wavyLine(vertical: true, at: line, flip: flip))
            ctx.addPath(wavyLine(vertical: false, at: line, flip: -flip))
            flip = -flip
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

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
        blob(cx: 850, cy: 900, rx: 520, ry: 340, color: blobs.deep)
        blob(cx: 420, cy: 480, rx: 300, ry: 180, color: blobs.light)
    }
    ctx.restoreGState()

    // 3 · The coping: a pale lip just proud of the waterline.
    ctx.setStrokeColor(p.coping)
    ctx.setLineWidth(10)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 228, y: 318, width: 1024, height: 924),
                       cornerWidth: 118, cornerHeight: 118, transform: nil))
    ctx.strokePath()

    // 4 · The ladder, three passes: cast shadow on the water, the drowned
    // rails refracted pale, and the dry top with its one rung.
    func rails(_ segments: [(CGPoint, CGPoint)], color: CGColor, width: CGFloat) {
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.beginPath()
        for (a, b) in segments { ctx.move(to: a); ctx.addLine(to: b) }
        ctx.strokePath()
    }
    ctx.saveGState()
    ctx.translateBy(x: 12, y: 14)
    rails([(CGPoint(x: 520, y: 208), CGPoint(x: 520, y: 560)),
           (CGPoint(x: 614, y: 208), CGPoint(x: 614, y: 560))],
          color: p.ladderShadow, width: 26)
    ctx.restoreGState()
    rails([(CGPoint(x: 520, y: 330), CGPoint(x: 520, y: 560)),
           (CGPoint(x: 614, y: 330), CGPoint(x: 614, y: 560))],
          color: p.ladderWet, width: 24)
    rails([(CGPoint(x: 520, y: 208), CGPoint(x: 520, y: 336)),
           (CGPoint(x: 614, y: 208), CGPoint(x: 614, y: 336)),
           (CGPoint(x: 520, y: 250), CGPoint(x: 614, y: 250))],
          color: p.ladderDry, width: 24)

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
let deepFull = renderDeepEnd(deepDay)
write(deepFull, side: 1024, to: "\(dir)/lido-deep-1024.png")
write(renderDeepEnd(deepNight), side: 1024, to: "\(dir)/lido-deep-1024-dark.png")
write(renderDeepEnd(deepTinted), side: 1024, to: "\(dir)/lido-deep-1024-tinted.png")
let typeFull = renderPoolType(day, textColor: rgb(0.957, 0.969, 0.984))   // #F4F7FB
write(typeFull, side: 1024, to: "\(dir)/lido-type-1024.png")
write(renderPoolType(night, textColor: rgb(0.957, 0.969, 0.984)),
      side: 1024, to: "\(dir)/lido-type-1024-dark.png")
write(renderPoolType(tinted, textColor: gray(1.0)),
      side: 1024, to: "\(dir)/lido-type-1024-tinted.png")
// Small day renders for the Settings icon-picker tiles.
write(full, side: 256, to: "\(dir)/lido-preview-pool.png")
write(deepFull, side: 256, to: "\(dir)/lido-preview-deep.png")
write(typeFull, side: 256, to: "\(dir)/lido-preview-type.png")
print("done")
