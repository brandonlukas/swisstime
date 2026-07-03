// LIDO icon, poster variant: periwinkle extra-expanded type on the app's
// pale deck — the LIMINAL homage with everything else removed. Flat by
// intent; the poster look is print, not water.
import AppKit
import CoreText

let S = 2048
let scale = CGFloat(S) / 1024.0

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

let deck = rgb(0.914, 0.929, 0.953)        // the app's paper #E9EDF4
let periwinkle = rgb(0.42, 0.47, 0.85)     // deep enough to carry on pale ground

let ctx = makeContext(S)
ctx.translateBy(x: 0, y: CGFloat(S))
ctx.scaleBy(x: scale, y: -scale)

ctx.setFillColor(deck)
ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
// A whisper of poolside light, top-center — the app's ambient backdrop.
let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                      colors: [rgb(1, 1, 1, 0.35), rgb(1, 1, 1, 0)] as CFArray,
                      locations: [0, 1])!
ctx.saveGState()
ctx.translateBy(x: 512, y: 320)
ctx.scaleBy(x: 620, y: 480)
ctx.drawRadialGradient(glow, startCenter: .zero, startRadius: 0,
                       endCenter: .zero, endRadius: 1, options: [])
ctx.restoreGState()

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
let attributed = NSAttributedString(string: "LIDO", attributes: [
    .font: font,
    .kern: 295 * 0.02,
    .foregroundColor: NSColor(cgColor: periwinkle)!,
])
let line = CTLineCreateWithAttributedString(attributed)
let bounds = CTLineGetImageBounds(line, ctx)
let targetWidth: CGFloat = 900
let stretch = targetWidth / bounds.width
ctx.saveGState()
ctx.translateBy(x: 512 - targetWidth / 2, y: 618)
ctx.scaleBy(x: stretch, y: -1)
ctx.textPosition = CGPoint(x: -bounds.minX, y: 0)
CTLineDraw(line, ctx)
ctx.restoreGState()

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
write(full, side: 1024, to: "\(dir)/lido-poster-1024.png")
write(full, side: 120, to: "\(dir)/lido-poster-120.png")
print("done — stretch \(stretch), font \(font.fontName)")
