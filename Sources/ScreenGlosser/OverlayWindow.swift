import AppKit

/// A borderless, transparent, click-through window that covers one screen.
final class OverlayWindow: NSWindow {
    let textureView = TextureView()

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true                 // clicks and scrolls go to the apps below
        level = .screenSaver                      // above menu bar and Dock; cursor stays on top
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        sharingType = .none                       // keep the overlay out of screenshots/recordings
        animationBehavior = .none
        contentView = textureView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Draws a translucent tint plus a tiled grain texture. It only redraws when settings change,
/// so it costs essentially nothing while idle.
final class TextureView: NSView {
    var texture: NSImage? { didSet { if texture !== oldValue { needsDisplay = true } } }
    var tintColor: NSColor = .clear { didSet { needsDisplay = true } }
    var tintAlpha: CGFloat = 0 { didSet { if tintAlpha != oldValue { needsDisplay = true } } }
    var grainAlpha: CGFloat = 0 { didSet { if grainAlpha != oldValue { needsDisplay = true } } }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)

        if tintAlpha > 0 {
            tintColor.withAlphaComponent(tintAlpha).setFill()
            dirtyRect.fill()
        }
        if grainAlpha > 0, let texture {
            ctx.saveGState()
            ctx.setAlpha(grainAlpha)
            NSGraphicsContext.current?.patternPhase = .zero
            NSColor(patternImage: texture).setFill()
            dirtyRect.fill(using: .sourceOver)
            ctx.restoreGState()
        }
    }
}
