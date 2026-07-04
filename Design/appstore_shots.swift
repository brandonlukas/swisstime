// App Store screenshot compositor: real sim captures floated on tiled
// pool water with poster-caps headlines — the LIMINAL look as marketing
// frames. Every frame carries genuine UI (guideline 2.3.3); only the
// water around it is staged.
// Run:  swift appstore_shots.swift <captures-dir> <output-dir>
// Expects <captures-dir>/{pool,player,sets,list,night}.png at 1206×2622.
import AppKit
import CoreText

let W = 1320, H = 2868                       // 6.9" portrait, exact pixels
let margin: CGFloat = 96

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    CGContext(data: nil, width: w, height: h,
              bitsPerComponent: 8, bytesPerRow: w * 4,
              space: CGColorSpace(name: CGColorSpace.sRGB)!,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [r, g, b, a])!
}

// Day pool (the icon's water) and the night swim variant.
let dayPool = rgb(0.169, 0.451, 0.788)
let dayGroutDark = rgb(0.055, 0.243, 0.494, 0.34)
let dayGroutLight = rgb(1, 1, 1, 0.26)
let dayBlob = rgb(0.078, 0.271, 0.561)
let nightPool = rgb(0.075, 0.20, 0.42)
let nightGroutDark = rgb(0.02, 0.09, 0.22, 0.40)
let nightGroutLight = rgb(0.65, 0.82, 1, 0.14)
let nightBlob = rgb(0.03, 0.10, 0.24)
let vinylWhite = rgb(0.957, 0.969, 0.984)
let sunShadow = rgb(0.039, 0.173, 0.361, 0.30)
let periwinklePale = rgb(0.72, 0.77, 0.98)
let bezel = rgb(0.043, 0.059, 0.118)

// The wordmark's face, with its two known traps handled: request the
// expanded width but verify the name still says black (traits can
// silently reset the face), and never trust textMatrix across passes.
func posterFont(size: CGFloat) -> NSFont {
    var font = NSFont.systemFont(ofSize: size, weight: .black)
    let descriptor = font.fontDescriptor.addingAttributes([
        .traits: [
            NSFontDescriptor.TraitKey.weight: NSFont.Weight.black.rawValue,
            NSFontDescriptor.TraitKey.width: 0.4,
        ],
    ])
    if let wide = NSFont(descriptor: descriptor, size: size),
       wide.fontName.lowercased().contains("black") {
        font = wide
    }
    return font
}

// Water, grout, and caustics — shared by the poster and every UI frame.
func drawWater(_ ctx: CGContext, night: Bool) {
    ctx.setFillColor(night ? nightPool : dayPool)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    func groutPath(vertical: Bool, at position: CGFloat, flip: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let limit = CGFloat(vertical ? H : W)
        let wob = { (t: CGFloat) in 9 * flip * sin(2 * .pi * t / 682) }
        var along: CGFloat = 0
        if vertical { path.move(to: CGPoint(x: position + wob(0), y: 0)) }
        else { path.move(to: CGPoint(x: 0, y: position + wob(0))) }
        while along < limit {
            along += 8
            if vertical { path.addLine(to: CGPoint(x: position + wob(along), y: along)) }
            else { path.addLine(to: CGPoint(x: along, y: position + wob(along))) }
        }
        return path
    }
    ctx.setLineCap(.round)
    let verticals: [CGFloat] = [440, 880]
    let horizontals: [CGFloat] = stride(from: 440, to: CGFloat(H), by: 440).map { $0 }
    for pass in 0..<2 {
        ctx.saveGState()
        if pass == 0 {
            ctx.translateBy(x: 10, y: 10)
            ctx.setStrokeColor(night ? nightGroutDark : dayGroutDark)
            ctx.setLineWidth(21)
        } else {
            ctx.setStrokeColor(night ? nightGroutLight : dayGroutLight)
            ctx.setLineWidth(19)
        }
        var flip: CGFloat = 1
        for v in verticals { ctx.addPath(groutPath(vertical: true, at: v, flip: flip)); flip = -flip }
        for h in horizontals { ctx.addPath(groutPath(vertical: false, at: h, flip: flip)); flip = -flip }
        ctx.strokePath()
        ctx.restoreGState()
    }

    func blob(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat,
              color: CGColor, alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: cx, y: cy)
        ctx.scaleBy(x: rx, y: ry)
        let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [color.copy(alpha: alpha)!,
                                       color.copy(alpha: 0)!] as CFArray,
                              locations: [0, 1])!
        ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 0,
                               endCenter: .zero, endRadius: 1, options: [])
        ctx.restoreGState()
    }
    blob(cx: 330, cy: 420, rx: 560, ry: 380,
         color: night ? nightBlob : dayBlob, alpha: 0.45)
    blob(cx: 1050, cy: 2450, rx: 520, ry: 360, color: rgb(1, 1, 1),
         alpha: night ? 0.05 : 0.12)
}

/// One line of type at a baseline; returns drawn width. `stretchTo`
/// forces glyph width (the wordmark's wide O); otherwise text only
/// shrinks to fit maxWidth. Centered when x is nil.
@discardableResult
func drawText(_ ctx: CGContext, _ text: String, font: NSFont, color: CGColor,
              kern: CGFloat, x: CGFloat?, baseline: CGFloat,
              maxWidth: CGFloat, stretchTo: CGFloat? = nil) -> CGFloat {
    let attributed = NSAttributedString(string: text, attributes: [
        .font: font, .kern: kern, .foregroundColor: NSColor(cgColor: color)!,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.textMatrix = .identity   // not graphics state; reset per pass
    let bounds = CTLineGetImageBounds(line, ctx)
    let scaleX: CGFloat
    let scaleY: CGFloat
    if let target = stretchTo {
        scaleX = target / bounds.width; scaleY = 1
    } else {
        let fit = min(1, maxWidth / bounds.width)
        scaleX = fit; scaleY = fit
    }
    let drawnWidth = bounds.width * scaleX
    let originX = x ?? (CGFloat(W) - drawnWidth) / 2
    ctx.saveGState()
    ctx.translateBy(x: originX, y: baseline)
    ctx.scaleBy(x: scaleX, y: -scaleY)
    ctx.textPosition = CGPoint(x: -bounds.minX, y: 0)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    return drawnWidth
}

struct Frame {
    let capture: String          // basename in <captures-dir>
    let index: String            // "01"
    let lines: [String]          // headline, poster caps
    let night: Bool
}

let frames: [Frame] = [
    Frame(capture: "pool", index: "01",
          lines: ["FINISH A WORKOUT.", "FLOAT A TOY."], night: false),
    Frame(capture: "player", index: "02",
          lines: ["THE WATER DRAINS", "WITH THE CLOCK."], night: false),
    Frame(capture: "sets", index: "03",
          lines: ["A REST CLOCK", "FOR THE BENCH."], night: false),
    Frame(capture: "list", index: "04",
          lines: ["YOUR WORKOUTS,", "YOUR COLORS."], night: false),
    Frame(capture: "night", index: "05",
          lines: ["NIGHT SWIM."], night: true),
]

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("usage: appstore_shots.swift <captures> <out>") }
let capturesDir = args[1], outDir = args[2]

func loadCapture(_ name: String) -> CGImage {
    let url = URL(fileURLWithPath: "\(capturesDir)/\(name).png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("missing capture \(name).png") }
    return image
}

func render(_ frame: Frame) {
    let ctx = makeContext(W, H)
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: 1, y: -1)     // top-left origin; images/text flip locally

    drawWater(ctx, night: frame.night)

    // Header: the headline with its sun shadow.
    let headlineFont = posterFont(size: 128)
    var baseline: CGFloat = 270
    for text in frame.lines {
        drawText(ctx, text, font: headlineFont, color: sunShadow, kern: 128 * 0.02,
                 x: margin + 8, baseline: baseline + 10, maxWidth: 1128)
        drawText(ctx, text, font: headlineFont, color: vinylWhite, kern: 128 * 0.02,
                 x: margin, baseline: baseline, maxWidth: 1128)
        baseline += 164
    }

    // 5 · The capture, floated on the water: hard sun shadow, dark bezel,
    // rounded clip — the WHOLE device inside the frame, sized to fill
    // everything below the headline.
    let capture = loadCapture(frame.capture)
    let aspect = CGFloat(capture.height) / CGFloat(capture.width)
    let shotY: CGFloat = frame.lines.count > 1 ? 520 : 380
    var shotHeight = CGFloat(H) - margin - shotY
    var shotWidth = shotHeight / aspect
    if shotWidth > 1128 { shotWidth = 1128; shotHeight = shotWidth * aspect }
    let shotX = (CGFloat(W) - shotWidth) / 2
    let shotRect = CGRect(x: shotX, y: shotY, width: shotWidth, height: shotHeight)
    let radius: CGFloat = 96

    // Sun shadow: offset, hard-edged — the same light the toys sit in.
    ctx.setFillColor(sunShadow)
    ctx.addPath(CGPath(roundedRect: shotRect.offsetBy(dx: 34, dy: 42),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()

    // Bezel ring behind the screen.
    ctx.setFillColor(bezel)
    ctx.addPath(CGPath(roundedRect: shotRect.insetBy(dx: -14, dy: -14),
                       cornerWidth: radius + 14, cornerHeight: radius + 14,
                       transform: nil))
    ctx.fillPath()

    // The screen itself, clipped round; images draw y-up, flip locally.
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: shotRect, cornerWidth: radius,
                       cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.translateBy(x: shotRect.minX, y: shotRect.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.draw(capture, in: CGRect(x: 0, y: 0, width: shotWidth, height: shotHeight))
    ctx.restoreGState()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outDir)/lido-shot-\(frame.index).png"))
}

// Shot 00 — the poster: the icon's world at store size. No UI by design;
// the four frames after it carry the real app (2.3.3's spirit: the SET
// shows the app in use). Duck geometry is lido_icon.swift's, scaled.
func renderPoster() {
    let ctx = makeContext(W, H)
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: 1, y: -1)
    drawWater(ctx, night: false)

    // Wordmark: forced-width stretch (the wide O), sun shadow first.
    let wordFont = posterFont(size: 300)
    drawText(ctx, "LIDO", font: wordFont, color: sunShadow, kern: 300 * 0.02,
             x: (CGFloat(W) - 1060) / 2 + 14, baseline: 618, maxWidth: 1128,
             stretchTo: 1060)
    drawText(ctx, "LIDO", font: wordFont, color: vinylWhite, kern: 300 * 0.02,
             x: (CGFloat(W) - 1060) / 2, baseline: 600, maxWidth: 1128,
             stretchTo: 1060)
    drawText(ctx, "A WORKOUT TIMER WITH A POOL.",
             font: NSFont.monospacedSystemFont(ofSize: 42, weight: .semibold),
             color: rgb(1, 1, 1, 0.82), kern: 9, x: nil, baseline: 760,
             maxWidth: 1128)

    // The duck, ported from lido_icon.swift: local space +x forward,
    // drawn at 1.9x with its ripple and hard sun shadow.
    let k: CGFloat = 1.9
    let duckCenter = CGPoint(x: 660, y: 1780)

    ctx.setStrokeColor(rgb(1, 1, 1, 0.15))
    ctx.setLineWidth(9 * k)
    let rippleR = 320 * k
    ctx.strokeEllipse(in: CGRect(x: duckCenter.x - rippleR, y: duckCenter.y - rippleR,
                                 width: rippleR * 2, height: rippleR * 2))

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
        ctx.translateBy(x: duckCenter.x + dx, y: duckCenter.y + dy)
        ctx.scaleBy(x: k, y: k)
        ctx.rotate(by: -20 * .pi / 180)
        body()
        ctx.restoreGState()
    }
    let duckBody = rgb(1.0, 0.796, 0.20)
    let duckShade = rgb(0.89, 0.659, 0.11)
    let duckBeak = rgb(0.941, 0.455, 0.165)
    let toyInk = rgb(0.075, 0.13, 0.28)

    placeDuck(dx: 76, dy: 129) {
        duckSilhouette(into: ctx)
        ctx.setFillColor(sunShadow)
        ctx.fillPath()
    }
    placeDuck(dx: 0, dy: 0) {
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -126, y: -50))
        tail.addLine(to: CGPoint(x: -217, y: 0))
        tail.addLine(to: CGPoint(x: -126, y: 50))
        tail.closeSubpath()
        ctx.addPath(tail)
        ctx.setFillColor(duckShade)
        ctx.fillPath()
        ctx.setFillColor(duckBody)
        ctx.fillEllipse(in: CGRect(x: -182, y: -112, width: 322, height: 224))
        ctx.setFillColor(duckShade.copy(alpha: 0.55)!)
        ctx.fillEllipse(in: CGRect(x: -119, y: -101, width: 168, height: 70))
        ctx.fillEllipse(in: CGRect(x: -119, y: 31, width: 168, height: 70))
        ctx.setFillColor(duckBody)
        ctx.fillEllipse(in: CGRect(x: 91, y: -77, width: 154, height: 154))
        let beak = CGMutablePath()
        beak.move(to: CGPoint(x: 224, y: -36))
        beak.addLine(to: CGPoint(x: 301, y: 0))
        beak.addLine(to: CGPoint(x: 224, y: 36))
        beak.closeSubpath()
        ctx.addPath(beak)
        ctx.setFillColor(duckBeak)
        ctx.fillPath()
        ctx.setFillColor(toyInk)
        ctx.fillEllipse(in: CGRect(x: 157, y: -63, width: 30, height: 30))
        ctx.fillEllipse(in: CGRect(x: 157, y: 33, width: 30, height: 30))
        ctx.setFillColor(rgb(1, 1, 1, 0.55))
        ctx.fillEllipse(in: CGRect(x: 102, y: -54, width: 52, height: 32))
    }

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: "\(outDir)/lido-shot-00.png"))
}

renderPoster()
for frame in frames { render(frame) }
print("done — \(frames.count) frames at \(W)×\(H), font \(posterFont(size: 116).fontName)")
