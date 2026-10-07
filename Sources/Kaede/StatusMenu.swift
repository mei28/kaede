import AppKit
import KaedeCore

/// Kaede's icon in the menu bar: open the form, open the settings, quit.
@MainActor
final class StatusMenu: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let openFormItem: NSMenuItem
    private let openForm: () -> Void
    private let openSettings: () -> Void

    init(openKey: KeyCombo, openForm: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.openForm = openForm
        self.openSettings = openSettings
        openFormItem = NSMenuItem(title: "窓を開く", action: #selector(openFormChosen), keyEquivalent: "")
        super.init()
        guard let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Kaede") else {
            preconditionFailure("the leaf.fill symbol exists")
        }
        image.isTemplate = true
        item.button?.image = image
        let menu = NSMenu()
        openFormItem.target = self
        menu.addItem(openFormItem)
        let settings = NSMenuItem(title: "設定…", action: #selector(settingsChosen), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Kaede を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        show(openKey: openKey)
    }

    /// Shows the open key next to "窓を開く", as menus show shortcuts.
    func show(openKey: KeyCombo) {
        openFormItem.title = "窓を開く（\(openKey.symbols)）"
    }

    @objc private func openFormChosen() {
        openForm()
    }

    @objc private func settingsChosen() {
        openSettings()
    }
}
