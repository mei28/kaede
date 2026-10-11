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
    @Published private(set) var punctuation: PunctuationStyle
    @Published private(set) var layout: KeyboardLayout
    /// The rows as the user edits them, before they are used.
    @Published var layoutRows: [String]
    @Published var layoutMessage: String?
    @Published private(set) var launchesAtLogin: Bool
    @Published var loginMessage: String?

    /// Called after the keys change, for the menu bar to show them.
    var keysChanged: ((FormKeys) -> Void)?
    private let form: InputForm
    private let hotKey: HotKey
    private var recorder: Any?

    init(keys: FormKeys, fontSize: Double, punctuation: PunctuationStyle, layout: KeyboardLayout, form: InputForm, hotKey: HotKey) {
        self.keys = keys
        self.fontSize = fontSize
        self.punctuation = punctuation
        self.layout = layout
        layoutRows = layout.rows
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
            let modifiers = KeyCombo.Modifiers(event.modifierFlags)
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

    // MARK: Font size

    func setFontSize(_ size: Double) {
        fontSize = size
        FormSettings.save(fontSize: size)
        form.apply(fontSize: size)
    }

    // MARK: Conversion

    func setPunctuation(_ style: PunctuationStyle) {
        punctuation = style
        FormSettings.save(punctuation: style)
        form.apply(style: style)
    }

    // MARK: Layout

    /// The choices of the layout picker: none, a preset by name, or rows of the user's own.
    static let noLayout = "なし（QWERTY だけ）"
    static let ownLayout = "自分で書く"

    var layoutChoice: String {
        if layout.isQwerty { return Self.noLayout }
        return KeyboardLayout.presets.first { $0.layout == layout }?.name ?? Self.ownLayout
    }

    func chooseLayout(_ choice: String) {
        if choice == Self.noLayout {
            use(.qwerty)
        } else if let preset = KeyboardLayout.presets.first(where: { $0.name == choice }) {
            use(preset.layout)
        }
        // For rows of one's own, the rows are edited and used with the button
    }

    /// Uses the edited rows, or says what is wrong with them.
    func useLayoutRows() {
        do {
            use(try KeyboardLayout(rows: layoutRows))
        } catch {
            layoutMessage = Self.message(for: error)
        }
    }

    private func use(_ chosen: KeyboardLayout) {
        layout = chosen
        layoutRows = chosen.rows
        layoutMessage = nil
        FormSettings.save(layout: chosen)
        form.apply(layout: chosen)
    }

    /// The QWERTY rows the layout's rows sit over, as their labels.
    static let qwertyRows = KeyboardLayout.qwerty.rows

    private static func message(for error: KeyboardLayoutError) -> String {
        switch error {
        case .rowCount: "配列は 3 行で書いてください。"
        case let .rowLength(row, length): "\(row) 行目が \(length) 文字です。10 文字にしてください。"
        case let .notAKey(character, row): "\(row) 行目の「\(character)」は使えません。英字の小文字と , . ; / だけで書いてください。"
        case let .repeated(character): "「\(character)」が 2 回あります。30 文字を 1 回ずつ使ってください。"
        }
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
            Section("変換") {
                Picker("日本語の句読点", selection: Binding(get: { model.punctuation }, set: { model.setPunctuation($0) })) {
                    ForEach(PunctuationStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
            Section("配列") {
                Picker("日本語を打つ配列", selection: Binding(get: { model.layoutChoice }, set: { model.chooseLayout($0) })) {
                    Text(SettingsModel.noLayout).tag(SettingsModel.noLayout)
                    ForEach(KeyboardLayout.presets, id: \.name) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                    Text(SettingsModel.ownLayout).tag(SettingsModel.ownLayout)
                }
                ForEach(Array(SettingsModel.qwertyRows.enumerated()), id: \.offset) { index, qwerty in
                    LabeledContent(qwerty) {
                        TextField("", text: $model.layoutRows[index])
                            .font(.system(.body, design: .monospaced))
                            .onSubmit { model.useLayoutRows() }
                    }
                }
                Button("この配列を使う") { model.useLayoutRows() }
                if let message = model.layoutMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
                Text("QWERTY の各キーの位置に来る文字を書きます。英語は QWERTY のまま、日本語はこの配列の指使いで打っても読み分けます。")
                    .font(.callout).foregroundStyle(.secondary)
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
