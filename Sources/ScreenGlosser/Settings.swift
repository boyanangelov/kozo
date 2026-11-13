import AppKit
import Combine

enum TexturePreset: String, CaseIterable, Identifiable {
    case paper, matte, eink

    var id: String { rawValue }
    var title: String {
        switch self {
        case .paper: return "Paper"
        case .matte: return "Matte Glass"
        case .eink:  return "E-Ink"
        }
    }
}

/// App-wide settings, persisted in UserDefaults. Observers subscribe via `objectWillChange`
/// (SwiftUI) or `changed` (AppKit controllers, fired after the value is stored).
final class Settings: ObservableObject {
    static let shared = Settings()

    let changed = PassthroughSubject<Void, Never>()
    private let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { save("enabled", enabled) } }
    @Published var preset: TexturePreset { didSet { save("preset", preset.rawValue) } }
    /// 0...1 strength of the grain texture.
    @Published var intensity: Double { didSet { save("intensity", intensity) } }
    /// 0...1 strength of the colour tint (warm for paper, grey for e-ink).
    @Published var tint: Double { didSet { save("tint", tint) } }
    @Published var excludedBundleIDs: [String] { didSet { save("excludedBundleIDs", excludedBundleIDs) } }
    /// Display IDs (CGDirectDisplayID) on which the overlay is turned off.
    @Published var disabledDisplays: [UInt32] { didSet { save("disabledDisplays", disabledDisplays.map(Int.init)) } }

    private init() {
        d.register(defaults: [
            "enabled": true,
            "preset": TexturePreset.paper.rawValue,
            "intensity": 0.35,
            "tint": 0.4,
        ])
        enabled = d.bool(forKey: "enabled")
        preset = TexturePreset(rawValue: d.string(forKey: "preset") ?? "") ?? .paper
        intensity = d.double(forKey: "intensity")
        tint = d.double(forKey: "tint")
        excludedBundleIDs = d.stringArray(forKey: "excludedBundleIDs") ?? []
        disabledDisplays = (d.array(forKey: "disabledDisplays") as? [Int] ?? []).map(UInt32.init)
    }

    private func save(_ key: String, _ value: Any) {
        d.set(value, forKey: key)
        changed.send()
    }
}
