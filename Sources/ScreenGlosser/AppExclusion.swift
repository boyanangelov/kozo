import AppKit
import Combine

/// Watches the frontmost app and reports whether the overlay should be suppressed.
/// macOS can't cut the overlay out around a single window, so an excluded app hides the
/// overlay on every screen while it is frontmost.
final class AppExclusion {
    private let settings: Settings
    private let onChange: (Bool) -> Void
    private var cancellables = Set<AnyCancellable>()

    /// Most recent frontmost app other than Screen Glosser itself. Opening our menu doesn't
    /// change it, so "Exclude current app" targets the app the user was actually using.
    private(set) var lastForegroundApp: NSRunningApplication?

    init(settings: Settings, onChange: @escaping (Bool) -> Void) {
        self.settings = settings
        self.onChange = onChange
        lastForegroundApp = NSWorkspace.shared.frontmostApplication

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.lastForegroundApp = app
            self?.evaluate()
        }
        settings.changed
            .sink { [weak self] in self?.evaluate() }
            .store(in: &cancellables)
        evaluate()
    }

    func isExcluded(_ app: NSRunningApplication?) -> Bool {
        guard let id = app?.bundleIdentifier else { return false }
        return settings.excludedBundleIDs.contains(id)
    }

    private func evaluate() {
        onChange(isExcluded(lastForegroundApp))
    }
}
