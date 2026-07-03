// Renders the LIDO app icon (concept W5) natively at 2048², then
// downsamples to 1024: crisp extra-expanded type floating on tiled pool
// water with a hard afternoon sun shadow — the same shadow the toys cast.
// Run:  swift lido_icon.swift <output-dir>
import AppKit
import CoreText

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

let pool = rgb(0.169, 0.451, 0.788)          // #2B73C9
let groutDark = rgb(0.055, 0.243, 0.494, 0.34)
let groutLight = rgb(1, 1, 1, 0.26)
let deepBlob = rgb(0.078, 0.271, 0.561)      // #14458F
let type = rgb(0.957, 0.969, 0.984)          // #F4F7FB
let sunShadow = rgb(0.039, 0.173, 0.361, 0.28)

let ctx = makeContext(S)
// Flip to top-left origin so the mockup's coordinates read straight across.
ctx.translateBy(x: 0, y: CGFloat(S))
ctx.scaleBy(x: scale, y: -scale)

// 1 · Water.
ctx.setFillColor(pool)
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
        ctx.setStrokeColor(groutDark); ctx.setLineWidth(21)
    } else {
        ctx.setStrokeColor(groutLight); ctx.setLineWidth(19)
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
blob(cx: 290, cy: 250, rx: 440, ry: 290, color: deepBlob, alpha: 0.5)
blob(cx: 770, cy: 810, rx: 400, ry: 260, color: rgb(1, 1, 1), alpha: 0.14)

// 4 · The wordmark, twice: sun shadow first, then the vinyl-white type.
// Black weight is non-negotiable; expanded width is a bonus. Requesting
// traits can silently reset the face to regular, so verify by name and
// fall back to plain black rather than ship a thin wordmark.
var font = NSFont.systemFont(ofSize: 295, weight: .black)
let widthDescriptor = font.fontDescriptor.addingAttributes([
    .traits: [
        NSFontDescriptor.TraitKey.weight: NSFont.Weight.black.rawValue,
        NSFontDescriptor.TraitKey.width: 0.4,
    ],
])
if let wide = NSFont(descriptor: widthDescriptor, size: 295),
   wide.fontName.lowercased().contains("black") {
    font = wide
}

func drawWord(color: CGColor, dx: CGFloat, dy: CGFloat) {
    let attributed = NSAttributedString(string: "LIDO", attributes: [
        .font: font,
        .kern: 295 * 0.02,
        .foregroundColor: NSColor(cgColor: color)!,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    // The text matrix is NOT graphics state: the previous pass's position
    // survives restoreGState and would poison this measurement.
    ctx.textMatrix = .identity
    let bounds = CTLineGetImageBounds(line, ctx)
    // Stretch the glyphs to the mockup's forced width — the wide O lives here.
    let targetWidth: CGFloat = 900
    let stretch = targetWidth / bounds.width
    ctx.saveGState()
    ctx.translateBy(x: 512 - targetWidth / 2 + dx, y: 618 + dy)
    // Text draws in an upward-y frame; flip locally around the baseline.
    ctx.scaleBy(x: stretch, y: -1)
    ctx.textPosition = CGPoint(x: -bounds.minX, y: 0)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}
drawWord(color: sunShadow, dx: 12, dy: 16)
drawWord(color: type, dx: 0, dy: 0)

// 5 · Downsample and write.
func write(_ image: CGImage, side: Int, to path: String) {
    let out = makeContext(side)
    out.interpolationQuality = .high
    out.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
    let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: path))
}
let full = ctx.makeImage()!
let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
write(full, side: 1024, to: "\(dir)/lido-1024.png")
write(full, side: 180, to: "\(dir)/lido-180.png")
write(full, side: 120, to: "\(dir)/lido-120.png")
print("done — font \(font.fontName)")
