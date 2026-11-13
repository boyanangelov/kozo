import AppKit

/// Procedurally generates seamless, tileable, *uniform* matte textures.
///
/// The goal is an even screen-protector-like finish, not realistic dust: every texture is
/// stationary noise with no low-frequency blotches.
///
/// Grain is sized in *points*, not pixels. On a 2× Retina display each grain covers exactly
/// 2×2 device pixels, and on a 1× display it covers 1 pixel. A point is roughly the same
/// physical size on every Mac display, so the texture looks the same on a Retina laptop and a
/// standard external monitor. Upscaling is nearest-neighbour by an integer factor, so grain
/// stays crisp, with no blur or moiré.
///
/// macOS composites separate windows with plain alpha blending, so the overlay cannot multiply
/// against other apps. The grain is encoded in alpha: positive noise is translucent white and
/// negative noise is translucent black. A separate flat "veil" (drawn by TextureView) lifts the
/// blacks and dims the highlights, which gives the matte, lower-contrast feel.
enum TextureGenerator {
    private static var cache: [String: NSImage] = [:]
    private static let size = 512    // points; a power of two, so every pattern period tiles

    static func image(for preset: TexturePreset, scale: CGFloat) -> NSImage {
        let key = "\(preset.rawValue)@\(scale)"
        if let img = cache[key] { return img }
        let img = make(preset: preset, scale: scale)
        cache[key] = img
        return img
    }

    /// Colour of the flat contrast-reducing veil.
    static func veilColor(for preset: TexturePreset) -> NSColor {
        switch preset {
        case .matte: return NSColor(white: 0.55, alpha: 1)                               // neutral
        case .weave: return NSColor(srgbRed: 0.60, green: 0.58, blue: 0.55, alpha: 1)   // linen
        case .paper: return NSColor(srgbRed: 0.85, green: 0.74, blue: 0.55, alpha: 1)   // warm
        case .eink:  return NSColor(srgbRed: 0.62, green: 0.62, blue: 0.60, alpha: 1)   // e-paper
        }
    }

    // MARK: - Generation

    private static func make(preset: TexturePreset, scale: CGFloat) -> NSImage {
        let n = size
        let seed: UInt64 = [.matte: 1, .weave: 2, .paper: 3, .eink: 4][preset]! &* 0x9E37_79B9
        var rng = SplitMix64(seed: seed)

        // Even, roughly Gaussian per-pixel noise (sum of three uniforms).
        func whiteNoise() -> [Float] {
            (0..<(n * n)).map { _ in rng.nextFloat() + rng.nextFloat() + rng.nextFloat() - 1.5 }
        }

        var field: [Float]
        switch preset {
        case .matte:
            // Pure fine grain, one grain per point.
            field = whiteNoise()

        case .weave:
            // Fine grain plus a faint woven crosshatch with an 8-point period.
            field = whiteNoise()
            for y in 0..<n {
                for x in 0..<n {
                    let wx = sin(Float(x) * .pi / 4), wy = sin(Float(y) * .pi / 4)
                    // Alternate the dominant thread direction in 8×8 cells, like a plain weave.
                    let horizontal = ((x / 8) + (y / 8)) % 2 == 0
                    field[y * n + x] = field[y * n + x] * 0.7 + (horizontal ? wy : wx) * 0.45
                }
            }

        case .paper:
            // Slightly softer grain: lightly blurred noise mixed with crisp noise for tooth.
            let soft = blur(whiteNoise(), n)
            let crisp = whiteNoise()
            field = zip(soft, crisp).map { $0 * 2.2 + $1 * 0.5 }

        case .eink:
            // E-paper particles: 2×2-point cells of noise, still completely even.
            let cells = whiteNoise()
            field = (0..<(n * n)).map { i in cells[((i / n) / 2 * 2) * n + (i % n) / 2 * 2] }
        }

        normalize(&field, rms: 0.33)   // same perceived strength for every preset

        // Encode as premultiplied RGBA: positive → white, negative → black, |v| → alpha.
        // Each point-grid cell becomes an s×s block of device pixels.
        let s = max(1, Int(scale.rounded()))
        let px = n * s
        var pixels = [UInt8](repeating: 0, count: px * px * 4)
        for y in 0..<px {
            for x in 0..<px {
                let v = max(-1, min(1, field[(y / s) * n + x / s]))
                let a = UInt8(abs(v) * 255)
                let c: UInt8 = v > 0 ? a : 0
                let o = (y * px + x) * 4
                pixels[o] = c; pixels[o + 1] = c; pixels[o + 2] = c; pixels[o + 3] = a
            }
        }

        let cg = CGImage(width: px, height: px, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: px * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                         provider: CGDataProvider(data: Data(pixels) as CFData)!,
                         decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        // The image is n×n points backed by (n·s)² pixels, so it maps 1:1 onto device pixels.
        return NSImage(cgImage: cg, size: NSSize(width: n, height: n))
    }

    /// 3×3 box blur with wrap-around, so the result still tiles seamlessly.
    private static func blur(_ f: [Float], _ n: Int) -> [Float] {
        var out = [Float](repeating: 0, count: n * n)
        for y in 0..<n {
            for x in 0..<n {
                var s: Float = 0
                for dy in -1...1 {
                    for dx in -1...1 { s += f[((y + dy + n) % n) * n + (x + dx + n) % n] }
                }
                out[y * n + x] = s / 9
            }
        }
        return out
    }

    private static func normalize(_ f: inout [Float], rms target: Float) {
        let mean = f.reduce(0, +) / Float(f.count)
        let rms = (f.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Float(f.count)).squareRoot()
        guard rms > 0 else { return }
        for i in f.indices { f[i] = (f[i] - mean) / rms * target }
    }
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
