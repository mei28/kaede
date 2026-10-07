import AppKit
import KaedeCore
import ServiceManagement
import SwiftUI

/// What the settings panel shows and changes. Each change is checked, saved to the app's
/// defaults and applied at once.
@MainActor
final class SettingsModel: ObservableObject {
    /// Which key the panel is recording, if any.
    enum Recording: Equatable {
        case open
        case insert
    }

    @Published private(set) var keys: FormKeys
    @Published private(set) var recording: Recording?
    @Published var keyMessage: String?
    @Published var fontSize: Double
    @Published private(set) var launchesAtLogin: Bool
    @Published var loginMessage: String?

    /// Called after the keys change, for the menu bar to show them.
    var keysChanged: ((FormKeys) -> Void)?
    private let form: InputForm
    private let hotKey: HotKey
    private var recorder: Any?

    init(keys: FormKeys, fontSize: Double, form: InputForm, hotKey: HotKey) {
        self.keys = keys
        self.fontSize = fontSize
        self.form = form
        self.hotKey = hotKey
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Keys

    /// Waits for the next key with its modifiers. The open key's hot key steps aside meanwhile,
    /// so it can be recorded again.
    func record(_ which: Recording) {
        stopRecording()
        recording = which
        keyMessage = nil
        hotKey.suspend()
        recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let modifiers = Self.modifiers(of: event.modifierFlags)
            MainActor.assumeIsolated { self?.recorded(keyCode: keyCode, modifiers: modifiers) }
            return nil
        }
    }

    func stopRecording() {
        if let recorder {
            NSEvent.removeMonitor(recorder)
            self.recorder = nil
        }
        recording = nil
        do {
            try hotKey.resume()
        } catch {
            keyMessage = "開くキーを登録し直せませんでした: \(error)"
        }
    }

    private func recorded(keyCode: UInt16, modifiers: KeyCombo.Modifiers) {
        guard let which = recording else { return }
        // Escape alone cancels
        if keyCode == 53, modifiers.isEmpty {
            stopRecording()
            return
        }
        guard KeyCombo.supports(keyCode: keyCode) else {
            keyMessage = "このキーは使えません。文字、数字、↩、Space、⇥ のどれかと組み合わせてください。"
            return
        }
        let combo = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        let proposed: FormKeys
        do {
            proposed = try which == .open
                ? FormKeys(open: combo, insert: keys.insert)
                : FormKeys(open: keys.open, insert: combo)
        } catch let error as FormKeysError {
            keyMessage = Self.message(for: error)
            return
        } catch {
            preconditionFailure("FormKeys throws only FormKeysError")
        }
        stopRecording()
        if which == .open {
            do {
                try hotKey.change(to: combo)
            } catch {
                keyMessage = "\(combo.symbols) はほかのアプリが使っているようです。"
                return
            }
        }
        keys = proposed
        FormSettings.save(proposed)
        form.apply(keys: proposed)
        keysChanged?(proposed)
        keyMessage = nil
    }

    private static func message(for error: FormKeysError) -> String {
        switch error {
        case .openNeedsControlOrCommand: "開くキーには ⌃ か ⌘ を含めてください。"
        case .sameKeys: "開くキーと入れるキーが同じです。"
        case .plainEnterInserts: "↩ だけでは入れるキーにできません（窓の中の改行に使うため）。"
        }
    }

    private static func modifiers(of flags: NSEvent.ModifierFlags) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
    }

    // MARK: Font size

    func setFontSize(_ size: Double) {
        fontSize = size
        FormSettings.save(fontSize: size)
        form.apply(fontSize: size)
    }

    // MARK: Login

    func setLaunchesAtLogin(_ launches: Bool) {
        do {
            if launches {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginMessage = "切り替えられませんでした: \(error.localizedDescription)"
        }
        let status = SMAppService.mainApp.status
        launchesAtLogin = status == .enabled
        if status == .requiresApproval {
            loginMessage = "システム設定の「ログイン項目」で Kaede を許可してください。"
        }
    }
}

/// The settings panel.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("キー") {
                KeyRow(label: "窓を開く・閉じる", combo: model.keys.open, isRecording: model.recording == .open) {
                    model.recording == .open ? model.stopRecording() : model.record(.open)
                }
                KeyRow(label: "元のアプリに入れる", combo: model.keys.insert, isRecording: model.recording == .insert) {
                    model.recording == .insert ? model.stopRecording() : model.record(.insert)
                }
                if let message = model.keyMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            }
            Section("見た目") {
                HStack {
                    Text("文字の大きさ")
                    Slider(value: Binding(get: { model.fontSize }, set: { model.setFontSize($0.rounded()) }), in: FormSettings.fontSizes, step: 1)
                    Text("\(Int(model.fontSize)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
            Section("起動") {
                Toggle("ログイン時に起動", isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchesAtLogin($0) }))
                if let message = model.loginMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct KeyRow: View {
    let label: String
    let combo: KeyCombo
    let isRecording: Bool
    let toggle: () -> Void

    var body: some View {
        LabeledContent(label) {
            Button(action: toggle) {
                Text(isRecording ? "キーを押してください…" : combo.symbols)
                    .font(.system(.body, design: .rounded))
                    .frame(minWidth: 120)
            }
            .help(isRecording ? "Esc でやめる" : "押して新しいキーを記録する")
        }
    }
}

/// The window that holds the settings panel.
@MainActor
final class SettingsWindow {
    private let model: SettingsModel
    private var window: NSWindow?

    init(model: SettingsModel) {
        self.model = model
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = "Kaede の設定"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
