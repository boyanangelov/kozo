import AppKit
import Combine

/// Owns one overlay window per screen and keeps them in sync with settings.
final class OverlayController {
    private let settings: Settings
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var suppressed = false   // true while an excluded app is frontmost

    init(settings: Settings) {
        self.settings = settings
        settings.changed
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.apply(animated: true) }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
    }

    /// Recreates windows for the current set of screens.
    func rebuild() {
        let screens = NSScreen.screens
        let ids = Set(screens.compactMap(\.displayID))
        for (id, w) in windows where !ids.contains(id) {
            w.orderOut(nil)
            windows[id] = nil
        }
        for screen in screens {
            guard let id = screen.displayID else { continue }
            let w = windows[id] ?? OverlayWindow(screen: screen)
            w.setFrame(screen.frame, display: false)
            windows[id] = w
        }
        apply(animated: false)
    }

    func setSuppressed(_ value: Bool) {
        guard value != suppressed else { return }
        suppressed = value
        apply(animated: true)
    }

    private func apply(animated: Bool) {
        let preset = settings.preset
        let tint = TextureGenerator.tintColor(for: preset)

        for (id, w) in windows {
            let screen = NSScreen.screens.first { $0.displayID == id }
            let scale = screen?.backingScaleFactor ?? 2
            let view = w.textureView
            view.texture = TextureGenerator.image(for: preset, scale: scale)
            view.tintColor = tint
            // Keep the tint subtle: full slider = 22% opacity colour wash.
            view.tintAlpha = CGFloat(settings.tint) * 0.22
            // Grain: full slider = 60% of the texture's own alpha.
            view.grainAlpha = CGFloat(settings.intensity) * 0.6

            let visible = settings.enabled && !suppressed && !settings.disabledDisplays.contains(id)
            setVisible(w, visible, animated: animated)
        }
    }

    private func setVisible(_ w: OverlayWindow, _ visible: Bool, animated: Bool) {
        if visible {
            if !w.isVisible { w.alphaValue = animated ? 0 : 1; w.orderFrontRegardless() }
            fade(w, to: 1, animated: animated, completion: nil)
        } else if w.isVisible {
            fade(w, to: 0, animated: animated) { [weak w] in
                // Only hide if nothing re-enabled it during the fade.
                guard let w, w.alphaValue == 0 else { return }
                w.orderOut(nil)
            }
        }
    }

    private func fade(_ w: NSWindow, to alpha: CGFloat, animated: Bool, completion: (() -> Void)?) {
        guard animated else { w.alphaValue = alpha; completion?(); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            w.animator().alphaValue = alpha
        }, completionHandler: completion)
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var displayName: String { localizedName }
}
