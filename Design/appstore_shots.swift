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

    // 1 · Water, edge to edge.
    ctx.setFillColor(frame.night ? nightPool : dayPool)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    // 2 · Grout: the icon's long-sine joints at deck scale (~440px cells).
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
            ctx.setStrokeColor(frame.night ? nightGroutDark : dayGroutDark)
            ctx.setLineWidth(21)
        } else {
            ctx.setStrokeColor(frame.night ? nightGroutLight : dayGroutLight)
            ctx.setLineWidth(19)
        }
        var flip: CGFloat = 1
        for v in verticals { ctx.addPath(groutPath(vertical: true, at: v, flip: flip)); flip = -flip }
        for h in horizontals { ctx.addPath(groutPath(vertical: false, at: h, flip: flip)); flip = -flip }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 3 · Caustic depth, one blob high and one low.
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
         color: frame.night ? nightBlob : dayBlob, alpha: 0.45)
    blob(cx: 1050, cy: 2450, rx: 520, ry: 360, color: rgb(1, 1, 1),
         alpha: frame.night ? 0.05 : 0.12)

    // 4 · Header: index overline, then the headline with its sun shadow.
    func drawLine(_ text: String, font: NSFont, color: CGColor, kern: CGFloat,
                  x: CGFloat, baseline: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font, .kern: kern, .foregroundColor: NSColor(cgColor: color)!,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        ctx.textMatrix = .identity   // not graphics state; reset per pass
        let bounds = CTLineGetImageBounds(line, ctx)
        let fit = min(1, maxWidth / bounds.width)
        ctx.saveGState()
        ctx.translateBy(x: x, y: baseline)
        ctx.scaleBy(x: fit, y: -fit)
        ctx.textPosition = CGPoint(x: -bounds.minX, y: 0)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
        return bounds.width * fit
    }
    let indexFont = NSFont.monospacedSystemFont(ofSize: 44, weight: .semibold)
    _ = drawLine("\(frame.index) — LIDO", font: indexFont, color: periwinklePale,
                 kern: 10, x: margin, baseline: 200, maxWidth: 1128)
    let headlineFont = posterFont(size: 116)
    var baseline: CGFloat = 356
    for text in frame.lines {
        _ = drawLine(text, font: headlineFont, color: sunShadow, kern: 116 * 0.02,
                     x: margin + 8, baseline: baseline + 10, maxWidth: 1128)
        _ = drawLine(text, font: headlineFont, color: vinylWhite, kern: 116 * 0.02,
                     x: margin, baseline: baseline, maxWidth: 1128)
        baseline += 148
    }

    // 5 · The capture, floated on the water: hard sun shadow, dark bezel,
    // rounded clip, bottom edge bleeding off the frame (store idiom).
    let capture = loadCapture(frame.capture)
    let shotWidth: CGFloat = 1080
    let shotHeight = shotWidth * CGFloat(capture.height) / CGFloat(capture.width)
    let shotX = (CGFloat(W) - shotWidth) / 2
    let shotY: CGFloat = frame.lines.count > 1 ? 700 : 560
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

for frame in frames { render(frame) }
print("done — \(frames.count) frames at \(W)×\(H), font \(posterFont(size: 116).fontName)")
