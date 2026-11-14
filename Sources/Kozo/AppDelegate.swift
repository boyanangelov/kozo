import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayController!
    private var menuBar: MenuBarController!
    private var exclusion: AppExclusion!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = Settings.shared
        overlay = OverlayController(settings: settings)
        exclusion = AppExclusion(settings: settings) { [weak self] excluded in
            self?.overlay.setSuppressed(excluded)
        }
        menuBar = MenuBarController(settings: settings, exclusion: exclusion)

        // ⌃⌥⌘P toggles the overlay.
        hotKey = HotKey(keyCode: HotKey.kVK_ANSI_P, modifiers: [.control, .option, .command]) {
            settings.enabled.toggle()
        }

        overlay.rebuild()
    }
}
