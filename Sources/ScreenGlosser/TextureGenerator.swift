import AppKit

/// Procedurally generates seamless, tileable grain textures.
///
/// macOS composites separate windows with plain "source-over", so the overlay cannot use
/// multiply/overlay blending against other apps. Instead the texture encodes the grain in
/// alpha: dark specks are translucent black, light specks are translucent white. The net
/// effect matches what a matte or paper surface does to the image underneath.
enum TextureGenerator {
    private static var cache: [String: NSImage] = [:]

    static func image(for preset: TexturePreset, scale: CGFloat) -> NSImage {
        let key = "\(preset.rawValue)@\(scale)"
        if let img = cache[key] { return img }
        let img = make(preset: preset, scale: scale)
        cache[key] = img
        return img
    }

    /// Tint colour drawn underneath the grain; its alpha is controlled by the tint slider.
    static func tintColor(for preset: TexturePreset) -> NSColor {
        switch preset {
        case .paper: return NSColor(srgbRed: 0.98, green: 0.90, blue: 0.74, alpha: 1)  // warm cream
        case .matte: return NSColor(srgbRed: 0.93, green: 0.94, blue: 0.95, alpha: 1)  // cool haze
        case .eink:  return NSColor(srgbRed: 0.80, green: 0.79, blue: 0.75, alpha: 1)  // e-paper grey
        }
    }

    // MARK: - Generation

    private struct Params {
        var grain: Float       // per-pixel noise amplitude
        var grainSize: Int     // pixels per grain cell
        var cloud: Float       // low-frequency mottling amplitude
        var cloudCells: Int    // lattice cells across the tile for mottling
        var fibers: Int        // number of paper fibres
    }

    private static func params(_ p: TexturePreset) -> Params {
        switch p {
        case .paper: return Params(grain: 0.55, grainSize: 1, cloud: 0.45, cloudCells: 8, fibers: 220)
        case .matte: return Params(grain: 0.45, grainSize: 1, cloud: 0.12, cloudCells: 16, fibers: 0)
        case .eink:  return Params(grain: 0.35, grainSize: 2, cloud: 0.25, cloudCells: 12, fibers: 0)
        }
    }

    private static func make(preset: TexturePreset, scale: CGFloat) -> NSImage {
        let size = 512                       // pixels; tile repeats seamlessly
        let p = params(preset)
        // Fixed seeds: String.hashValue is randomised per launch, so it can't be used here.
        let seed: UInt64 = preset == .paper ? 0x5EED_0001 : preset == .matte ? 0x5EED_0002 : 0x5EED_0003
        var rng = SplitMix64(seed: seed)

        // Signed noise field in roughly -1...1.
        var field = [Float](repeating: 0, count: size * size)

        // 1) Fine grain.
        let g = p.grainSize
        for y in stride(from: 0, to: size, by: g) {
            for x in stride(from: 0, to: size, by: g) {
                let v = (rng.nextFloat() * 2 - 1) * p.grain
                for dy in 0..<g where y + dy < size {
                    for dx in 0..<g where x + dx < size { field[(y + dy) * size + x + dx] += v }
                }
            }
        }

        // 2) Low-frequency mottling: wrap-around value noise (two octaves) so it tiles.
        if p.cloud > 0 {
            for (cells, amp) in [(p.cloudCells, Float(1.0)), (p.cloudCells * 2, Float(0.5))] {
                var lattice = [Float](repeating: 0, count: cells * cells)
                for i in lattice.indices { lattice[i] = rng.nextFloat() * 2 - 1 }
                let cellSize = Float(size) / Float(cells)
                for y in 0..<size {
                    let fy = Float(y) / cellSize
                    let y0 = Int(fy) % cells, y1 = (y0 + 1) % cells
                    let ty = smooth(fy - Float(Int(fy)))
                    for x in 0..<size {
                        let fx = Float(x) / cellSize
                        let x0 = Int(fx) % cells, x1 = (x0 + 1) % cells
                        let tx = smooth(fx - Float(Int(fx)))
                        let a = lerp(lattice[y0 * cells + x0], lattice[y0 * cells + x1], tx)
                        let b = lerp(lattice[y1 * cells + x0], lattice[y1 * cells + x1], tx)
                        field[y * size + x] += lerp(a, b, ty) * p.cloud * amp
                    }
                }
            }
        }

        // 3) Paper fibres: short, slightly curved strokes, wrapped at the edges.
        for _ in 0..<p.fibers {
            var x = rng.nextFloat() * Float(size)
            var y = rng.nextFloat() * Float(size)
            var angle = rng.nextFloat() * .pi * 2
            let length = 8 + Int(rng.nextFloat() * 30)
            let v: Float = (rng.nextFloat() < 0.6 ? 1 : -1) * (0.25 + rng.nextFloat() * 0.35)
            for _ in 0..<length {
                let ix = (Int(x) % size + size) % size
                let iy = (Int(y) % size + size) % size
                field[iy * size + ix] += v
                angle += (rng.nextFloat() - 0.5) * 0.3
                x += cos(angle); y += sin(angle)
            }
        }

        // Encode as premultiplied RGBA: positive → white, negative → black, |v| → alpha.
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let v = max(-1, min(1, field[i]))
            let a = UInt8(min(255, abs(v) * 255))
            let c: UInt8 = v > 0 ? a : 0   // premultiplied: white = (a,a,a,a), black = (0,0,0,a)
            pixels[i * 4 + 0] = c
            pixels[i * 4 + 1] = c
            pixels[i * 4 + 2] = c
            pixels[i * 4 + 3] = a
        }

        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let cg = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: size * 4, space: cs,
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false,
                         intent: .defaultIntent)!
        // Point size = pixels / backing scale, so one texture pixel maps to one screen pixel.
        let pt = CGFloat(size) / max(scale, 1)
        return NSImage(cgImage: cg, size: NSSize(width: pt, height: pt))
    }

    private static func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }
    private static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
}

/// Small deterministic PRNG so each preset always looks the same.
struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextFloat() -> Float { Float(next() >> 40) / Float(1 << 24) }
}
