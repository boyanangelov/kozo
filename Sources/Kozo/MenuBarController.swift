import AppKit
import Combine

final class MenuBarController: NSObject, NSMenuDelegate {
    private let settings: Settings
    private let exclusion: AppExclusion
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var cancellables = Set<AnyCancellable>()
    private var prefsWindow: NSWindow?

    init(settings: Settings, exclusion: AppExclusion) {
        self.settings = settings
        self.exclusion = exclusion
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
        settings.changed
            .sink { [weak self] in self?.updateIcon() }
            .store(in: &cancellables)
    }

    private func updateIcon() {
        let name = settings.enabled ? "doc.text.fill" : "doc.text"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Kozo")
        img?.isTemplate = true
        statusItem.button?.image = img
    }

    // Rebuild the menu each time it opens so it always reflects current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = item(settings.enabled ? "Turn Texture Off" : "Turn Texture On", #selector(toggleEnabled))
        toggle.keyEquivalent = "p"
        toggle.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(toggle)
        menu.addItem(.separator())

        menu.addItem(header("Texture"))
        for preset in TexturePreset.allCases {
            let mi = item(preset.title, #selector(selectPreset(_:)))
            mi.representedObject = preset.rawValue
            mi.state = settings.preset == preset ? .on : .off
            menu.addItem(mi)
        }
        menu.addItem(.separator())

        menu.addItem(sliderItem(title: "Intensity", value: settings.intensity) { [weak self] in self?.settings.intensity = $0 })
        menu.addItem(sliderItem(title: "Tint", value: settings.tint) { [weak self] in self?.settings.tint = $0 })
        menu.addItem(.separator())

        if NSScreen.screens.count > 1 {
            let displays = NSMenuItem(title: "Displays", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for screen in NSScreen.screens {
                guard let id = screen.displayID else { continue }
                let mi = item(screen.displayName, #selector(toggleDisplay(_:)))
                mi.representedObject = NSNumber(value: id)
                mi.state = settings.disabledDisplays.contains(id) ? .off : .on
                sub.addItem(mi)
            }
            displays.submenu = sub
            menu.addItem(displays)
        }

        if let app = exclusion.lastForegroundApp, let name = app.localizedName {
            let excluded = exclusion.isExcluded(app)
            menu.addItem(item(excluded ? "Stop Excluding \(name)" : "Exclude \(name)", #selector(toggleExcludeCurrent)))
        }
        menu.addItem(.separator())
        let prefs = item("Preferences…", #selector(openPreferences))
        prefs.keyEquivalent = ","
        menu.addItem(prefs)
        let quit = item("Quit Kozo", #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() { settings.enabled.toggle() }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let p = TexturePreset(rawValue: raw) {
            settings.preset = p
        }
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.uint32Value else { return }
        if let i = settings.disabledDisplays.firstIndex(of: id) {
            settings.disabledDisplays.remove(at: i)
        } else {
            settings.disabledDisplays.append(id)
        }
    }

    @objc private func toggleExcludeCurrent() {
        guard let id = exclusion.lastForegroundApp?.bundleIdentifier else { return }
        if let i = settings.excludedBundleIDs.firstIndex(of: id) {
            settings.excludedBundleIDs.remove(at: i)
        } else {
            settings.excludedBundleIDs.append(id)
        }
    }

    @objc private func openPreferences() {
        if prefsWindow == nil {
            let w = NSWindow(contentViewController: PreferencesViewController(settings: settings))
            w.title = "Kozo"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            prefsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Helpers

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let mi = NSMenuItem(title: title, action: action, keyEquivalent: "")
        mi.target = self
        return mi
    }

    private func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return .sectionHeader(title: title) }
        let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        mi.isEnabled = false
        return mi
    }

    private func sliderItem(title: String, value: Double, onChange: @escaping (Double) -> Void) -> NSMenuItem {
        let mi = NSMenuItem()
        mi.view = SliderMenuView(title: title, value: value, onChange: onChange)
        return mi
    }
}

/// A labelled slider that lives inside an NSMenu.
private final class SliderMenuView: NSView {
    private let onChange: (Double) -> Void

    init(title: String, value: Double, onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 44))

        let label = NSTextField(labelWithString: title)
        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: 24, width: 200, height: 16)
        addSubview(label)

        let slider = NSSlider(value: value, minValue: 0, maxValue: 1, target: self, action: #selector(changed(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 14, y: 4, width: 212, height: 20)
        addSubview(slider)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func changed(_ sender: NSSlider) { onChange(sender.doubleValue) }
}
