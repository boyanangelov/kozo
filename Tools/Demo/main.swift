import AppKit
import ImageIO
import UniformTypeIdentifiers

// Renders README demo images. Kozo's overlay window is excluded from screenshots, so this
// composites the real textures (TextureGenerator) over a mock app window with the same maths
// the app uses (veil α = intensity·0.10 + tint·0.15, grain α = intensity·0.55).
//
// Usage: scripts/make-demo.sh  →  docs/demo.png, docs/presets.png, docs/demo.gif

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs")
let W = 960, H = 600

func bitmap(_ w: Int, _ h: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}

func draw(into rep: NSBitmapImageRep, _ body: (CGContext) -> Void) {
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    // Flip so y grows downward, like a screen, and tell AppKit so text draws upright.
    cg.translateBy(x: 0, y: CGFloat(rep.pixelsHigh))
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    body(cg)
    NSGraphicsContext.restoreGraphicsState()
}

func text(_ s: String, _ r: NSRect, size: CGFloat, weight: NSFont.Weight = .regular,
          color: NSColor = .labelColor) {
    let style = NSMutableParagraphStyle(); style.lineSpacing = size * 0.35
    (s as NSString).draw(with: r, options: [.usesLineFragmentOrigin],
        attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight),
                     .foregroundColor: color, .paragraphStyle: style])
}

/// A mock reading app: desktop background, a window with a dark sidebar and an article.
func drawScene(_ ctx: CGContext) {
    // Desktop gradient.
    NSGradient(starting: NSColor(srgbRed: 0.33, green: 0.45, blue: 0.62, alpha: 1),
               ending: NSColor(srgbRed: 0.76, green: 0.55, blue: 0.48, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -60)

    let win = NSRect(x: 60, y: 50, width: 840, height: 500)
    NSColor.black.withAlphaComponent(0.25).setFill()
    NSBezierPath(roundedRect: win.offsetBy(dx: 0, dy: 8).insetBy(dx: -4, dy: -4), xRadius: 14, yRadius: 14).fill()
    let clip = NSBezierPath(roundedRect: win, xRadius: 12, yRadius: 12)
    NSGraphicsContext.saveGraphicsState(); clip.addClip()

    NSColor.white.setFill(); win.fill()
    // Sidebar.
    let side = NSRect(x: win.minX, y: win.minY, width: 210, height: win.height)
    NSColor(srgbRed: 0.13, green: 0.14, blue: 0.17, alpha: 1).setFill(); side.fill()
    for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        c.setFill(); NSBezierPath(ovalIn: NSRect(x: side.minX + 18 + CGFloat(i) * 20, y: side.minY + 16, width: 12, height: 12)).fill()
    }
    let items = ["Reading List", "Highlights", "Notes", "Archive", "Library"]
    for (i, s) in items.enumerated() {
        if i == 0 {
            NSColor.white.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: NSRect(x: side.minX + 10, y: side.minY + 54, width: 190, height: 30), xRadius: 6, yRadius: 6).fill()
        }
        text(s, NSRect(x: side.minX + 24, y: side.minY + 60 + CGFloat(i) * 36, width: 170, height: 22),
             size: 14, color: NSColor.white.withAlphaComponent(i == 0 ? 0.95 : 0.6))
    }

    // Article.
    let x = side.maxX + 44, w = win.maxX - x - 44
    text("On the Texture of Paper", NSRect(x: x, y: win.minY + 44, width: w, height: 40), size: 28, weight: .bold, color: .black)
    text("Long-form reading · 6 min", NSRect(x: x, y: win.minY + 88, width: w, height: 20), size: 13, color: .gray)
    // Hero image block.
    let hero = NSRect(x: x, y: win.minY + 120, width: w, height: 130)
    NSGradient(colors: [NSColor(srgbRed: 0.98, green: 0.80, blue: 0.45, alpha: 1),
                        NSColor(srgbRed: 0.93, green: 0.45, blue: 0.40, alpha: 1),
                        NSColor(srgbRed: 0.35, green: 0.30, blue: 0.60, alpha: 1)])!.draw(in: hero, angle: 0)
    text("Glossy screens reflect, glare and push contrast to the limit. Paper does the opposite: its "
         + "surface scatters light, lifts the blacks and softens highlights, which is why an evening "
         + "with a book feels calmer than an evening with a display. Kozo adds a fine, even grain "
         + "across your whole screen to bring a little of that matte quality back.",
         NSRect(x: x, y: hero.maxY + 22, width: w, height: 140), size: 15, color: NSColor(white: 0.12, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
}

func drawOverlay(_ ctx: CGContext, _ rect: NSRect, preset: TexturePreset, intensity: CGFloat, tint: CGFloat) {
    TextureGenerator.veilColor(for: preset).withAlphaComponent(intensity * 0.10 + tint * 0.15).setFill()
    rect.fill(using: .sourceOver)
    let tex = TextureGenerator.image(for: preset, scale: 1)
    let cg = tex.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    ctx.saveGState(); ctx.clip(to: rect); ctx.setAlpha(intensity * 0.55); ctx.interpolationQuality = .none
    var y: CGFloat = 0
    while y < CGFloat(H) { var x: CGFloat = 0
        while x < CGFloat(W) { ctx.draw(cg, in: CGRect(x: x, y: y, width: 512, height: 512)); x += 512 }
        y += 512 }
    ctx.restoreGState()
}

func label(_ s: String, at p: NSPoint) {
    let f = NSFont.systemFont(ofSize: 13, weight: .semibold)
    let size = (s as NSString).size(withAttributes: [.font: f])
    let r = NSRect(x: p.x, y: p.y, width: size.width + 20, height: 26)
    NSColor.black.withAlphaComponent(0.7).setFill()
    NSBezierPath(roundedRect: r, xRadius: 13, yRadius: 13).fill()
    (s as NSString).draw(at: NSPoint(x: r.minX + 10, y: r.minY + 5), withAttributes: [.font: f, .foregroundColor: NSColor.white])
}

/// Magnified (nearest-neighbour) inset of a region so the grain is visible on GitHub.
func zoomInset(_ rep: NSBitmapImageRep, from src: CGRect, to dst: NSRect) {
    let crop = rep.cgImage!.cropping(to: src)!
    draw(into: rep) { ctx in
        NSColor.white.setFill(); dst.insetBy(dx: -3, dy: -3).fill()
        ctx.interpolationQuality = .none
        ctx.saveGState()
        ctx.translateBy(x: dst.minX, y: dst.maxY); ctx.scaleBy(x: 1, y: -1)   // un-flip for the image
        ctx.draw(crop, in: CGRect(origin: .zero, size: dst.size))
        ctx.restoreGState()
        label("4× zoom", at: NSPoint(x: dst.minX + 8, y: dst.minY + 8))
    }
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
    print("wrote docs/\(name)")
}

let full = NSRect(x: 0, y: 0, width: W, height: H)

// 1) demo.png: before/after split with Classic Matte at the default intensity.
let split = bitmap(W, H)
draw(into: split) { ctx in
    drawScene(ctx)
    drawOverlay(ctx, NSRect(x: W / 2, y: 0, width: W / 2, height: H), preset: .matte, intensity: 0.4, tint: 0)
    NSColor.white.setFill(); NSRect(x: W / 2 - 1, y: 0, width: 2, height: H).fill()
    label("Off", at: NSPoint(x: 16, y: H - 42))
    label("Kozo · Classic Matte", at: NSPoint(x: W / 2 + 16, y: H - 42))
}
zoomInset(split, from: CGRect(x: 640, y: 300, width: 60, height: 40), to: NSRect(x: 700, y: 360, width: 240, height: 160))
save(split, "demo.png")

// 2) presets.png: 2×2 grid, one tile per texture (tint 0.4 so the colour veils show).
let grid = bitmap(W, H)
let scene = bitmap(W, H); draw(into: scene) { drawScene($0) }
draw(into: grid) { ctx in
    for (i, p) in TexturePreset.allCases.enumerated() {
        let cell = NSRect(x: (i % 2) * W / 2, y: (i / 2) * H / 2, width: W / 2, height: H / 2)
        // Crop the article region of the scene into this cell at 1:1 (no scaling, grain intact).
        let src = scene.cgImage!.cropping(to: CGRect(x: 300, y: 70, width: W / 2, height: H / 2))!
        ctx.saveGState(); ctx.translateBy(x: cell.minX, y: cell.maxY); ctx.scaleBy(x: 1, y: -1)
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: W / 2, height: H / 2)); ctx.restoreGState()
        drawOverlay(ctx, cell, preset: p, intensity: 0.5, tint: 0.4)
        label(p.title, at: NSPoint(x: cell.maxX - 140, y: cell.minY + 14))
    }
    NSColor.white.setFill()
    NSRect(x: W / 2 - 1, y: 0, width: 2, height: H).fill(); NSRect(x: 0, y: H / 2 - 1, width: W, height: 2).fill()
}
save(grid, "presets.png")

// 3) demo.gif: off → each texture, then an intensity sweep on Classic Matte.
var frames: [(NSBitmapImageRep, Double)] = []
func frame(_ preset: TexturePreset?, intensity: CGFloat, tint: CGFloat, caption: String, delay: Double) {
    let f = bitmap(W, H)
    draw(into: f) { ctx in
        drawScene(ctx)
        if let preset { drawOverlay(ctx, full, preset: preset, intensity: intensity, tint: tint) }
        label(caption, at: NSPoint(x: 16, y: H - 42))
    }
    frames.append((f, delay))
}
frame(nil, intensity: 0, tint: 0, caption: "Off", delay: 1.4)
for p in TexturePreset.allCases {
    frame(p, intensity: 0.5, tint: p == .paper || p == .eink ? 0.5 : 0, caption: p.title, delay: 1.6)
}
for i in stride(from: 0.0, through: 1.0, by: 0.2) {
    frame(.matte, intensity: i, tint: 0, caption: "Classic Matte · intensity \(Int(i * 100))%", delay: 0.5)
}
let gifURL = outDir.appendingPathComponent("demo.gif") as CFURL
let dest = CGImageDestinationCreateWithURL(gifURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (f, d) in frames {
    CGImageDestinationAddImage(dest, f.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: d]] as CFDictionary)
}
CGImageDestinationFinalize(dest)
print("wrote docs/demo.gif")
