import AppKit
import Combine
import ServiceManagement

/// Preferences window, built in plain AppKit so the app compiles with only the
/// Command Line Tools (SwiftUI's property-wrapper macros need Xcode).
final class PreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let settings: Settings
    private var cancellables = Set<AnyCancellable>()

    private let enabledBox = NSButton(checkboxWithTitle: "Enabled  (⌃⌥⌘P)", target: nil, action: nil)
    private let presetPopup = NSPopUpButton()
    private let intensitySlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let tintSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let table = NSTableView()
    private let removeButton = NSButton(title: "Remove", target: nil, action: nil)
    private let loginBox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let loginError = NSTextField(wrappingLabelWithString: "")

    init(settings: Settings) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        for (b, a) in [(enabledBox, #selector(enabledChanged)), (loginBox, #selector(loginChanged)),
                       (removeButton, #selector(removeApp))] as [(NSButton, Selector)] {
            b.target = self; b.action = a
        }
        presetPopup.addItems(withTitles: TexturePreset.allCases.map(\.title))
        presetPopup.target = self; presetPopup.action = #selector(presetChanged)
        for s in [intensitySlider, tintSlider] {
            s.target = self; s.action = #selector(sliderChanged(_:)); s.isContinuous = true
        }

        let column = NSTableColumn(identifier: .init("app"))
        column.title = "Excluded apps"
        table.addTableColumn(column)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true

        let addButton = NSButton(title: "Add App…", target: self, action: #selector(addApp))
        loginError.textColor = .systemRed
        loginError.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        loginError.isHidden = true

        let grid = NSGridView(views: [
            [label("Texture:"), enabledBox],
            [label("Style:"), presetPopup],
            [label("Intensity:"), intensitySlider],
            [label("Tint:"), tintSlider],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowSpacing = 10
        intensitySlider.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let hint = NSTextField(wrappingLabelWithString: "The texture fades out while one of these apps is in front.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [
            grid, separator(),
            label("Excluded apps", bold: true), hint, scroll,
            NSStackView(views: [addButton, removeButton]),
            separator(), loginBox, loginError,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        stack.widthAnchor.constraint(equalToConstant: 420).isActive = true
        view = stack

        settings.changed
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
        refresh()
    }

    private func refresh() {
        enabledBox.state = settings.enabled ? .on : .off
        presetPopup.selectItem(at: TexturePreset.allCases.firstIndex(of: settings.preset) ?? 0)
        intensitySlider.doubleValue = settings.intensity
        tintSlider.doubleValue = settings.tint
        loginBox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        table.reloadData()
        removeButton.isEnabled = table.selectedRow >= 0
    }

    // MARK: - Actions

    @objc private func enabledChanged() { settings.enabled = enabledBox.state == .on }

    @objc private func presetChanged() {
        settings.preset = TexturePreset.allCases[presetPopup.indexOfSelectedItem]
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        if sender === intensitySlider { settings.intensity = sender.doubleValue }
        else { settings.tint = sender.doubleValue }
    }

    @objc private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier, !settings.excludedBundleIDs.contains(id) {
                settings.excludedBundleIDs.append(id)
            }
        }
    }

    @objc private func removeApp() {
        let row = table.selectedRow
        guard settings.excludedBundleIDs.indices.contains(row) else { return }
        settings.excludedBundleIDs.remove(at: row)
    }

    @objc private func loginChanged() {
        do {
            if loginBox.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError.isHidden = true
        } catch {
            loginError.stringValue = "Couldn't update the login item: \(error.localizedDescription). "
                + "Move the app to /Applications and try again."
            loginError.isHidden = false
            loginBox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { settings.excludedBundleIDs.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = settings.excludedBundleIDs[row]
        let cell = NSTableCellView()
        let text = NSTextField(labelWithString: appName(for: id))
        let icon = NSImageView()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            icon.image = NSWorkspace.shared.icon(forFile: url.path)
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon); cell.addSubview(text)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16), icon.heightAnchor.constraint(equalToConstant: 16),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        removeButton.isEnabled = table.selectedRow >= 0
    }

    // MARK: - Helpers

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func label(_ s: String, bold: Bool = false) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        if bold { l.font = .boldSystemFont(ofSize: NSFont.systemFontSize) }
        return l
    }

    private func separator() -> NSBox {
        let b = NSBox(); b.boxType = .separator
        return b
    }
}
