import AppKit
import KaedeConverter
import KaedeCore
import SwiftUI

/// Kaede's window for writing: opened over the app in front, it puts its text into that app.
/// English and romaji are typed as they come; the converted text shows under them.
///
/// Kaede is the active app while the form is open: the input method reads the keys of the active
/// app only, so a panel that left the other app in front got plain letters where azooKey should
/// have composed. Closing the form hands the activation back to the app the text goes to.
@MainActor
final class InputForm {
    private var keys: FormKeys
    private let handler: FormKeyHandler
    let worker: ConversionWorker
    private(set) var style: PunctuationStyle
    /// Converts the text as it is now; a newer change cancels it.
    private var previewTask: Task<Void, Never>?
    /// The last conversion that finished, and what it converted.
    var preview: Preview?
    /// What the user chose in place of the first candidates, until the text goes into the app.
    var choices = ConversionChoices()
    /// Choosing conversions with Tab, or nil while writing.
    var selection: ConversionSelection?
    /// Tab was pressed and the preview is catching up: keys already belong to choosing.
    var isBeginningToChoose = false
    /// The last step of choosing; the next waits for it, so keys act in their order.
    var choosingStep: Task<Void, Never>?
    private let inserter = TextInserter()
    private let poster = EventPoster()
    private let panel: FormPanel
    let textView: NSTextView
    let model: FormModel
    /// The app in front when the form opened: the text goes there.
    private var target: NSRunningApplication?
    /// azooKey was selected (by hand, with Hammerspoon's Ebi remapping) when the form opened, and
    /// comes back when it closes.
    private var restoresManualAzooKey = false
    private var inserting = false

    init(keys: FormKeys, fontSize: Double, style: PunctuationStyle, handler: FormKeyHandler, worker: ConversionWorker) {
        self.keys = keys
        self.style = style
        self.handler = handler
        self.worker = worker
        panel = FormPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 320),
            styleMask: [.borderless, .resizable],
            backing: .buffered, defer: false
        )
        // The rounded, translucent content draws the window; the shadow follows its shape
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 380, height: 220)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        if !panel.setFrameUsingName(Self.frameName) {
            panel.center()
        }
        panel.setFrameAutosaveName(Self.frameName)

        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            preconditionFailure("a scrollable text view holds a text view")
        }
        self.textView = textView
        Self.makePlain(textView)
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 6)

        model = FormModel(insertSymbols: keys.insert.symbols, openSymbols: keys.open.symbols, fontSize: fontSize)
        textView.font = .systemFont(ofSize: model.fontSize)
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        let content = NSHostingView(rootView: FormView(model: model, editor: scrollView))
        content.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            content.topAnchor.constraint(equalTo: background.topAnchor),
            content.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        panel.contentView = background

        model.close = { [weak self] in self?.toggle() }
        // The text storage changes with the text being composed too, which NSText's change
        // notification leaves out until it is committed
        NotificationCenter.default.addObserver(forName: NSTextStorage.didProcessEditingNotification, object: textView.textStorage, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.textChanged() }
        }
        handler.formWindow = panel
        // Before the input method sees the key, so it works mid-conversion
        handler.interceptor = { [weak self] event in
            self?.take(event) ?? false
        }
    }

    /// Takes the insert key, Tab and the keys of choosing; returns whether it took the key.
    private func take(_ event: NSEvent) -> Bool {
        if keys.insert.matches(keyCode: event.keyCode, modifiers: Self.heldModifiers()) {
            insert()
            return true
        }
        if selection != nil || isBeginningToChoose {
            return takeChoosingKey(event)
        }
        if event.keyCode == Self.tabKeyCode, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            beginChoosing()
            return true
        }
        return false
    }

    /// Settings changed in the panel take effect at once.
    func apply(keys: FormKeys) {
        self.keys = keys
        model.insertSymbols = keys.insert.symbols
        model.openSymbols = keys.open.symbols
    }

    func apply(fontSize: Double) {
        model.fontSize = fontSize
        textView.font = .systemFont(ofSize: fontSize)
    }

    func apply(style: PunctuationStyle) {
        self.style = style
        convertForPreview()
    }

    var openSettings: (() -> Void)? {
        get { model.openSettings }
        set { model.openSettings = newValue }
    }

    /// The open key: shows the form over the app in front, or hides it keeping the draft.
    func toggle() {
        guard !inserting else { return }
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        guard let front = NSWorkspace.shared.frontmostApplication, front != .current else {
            log.error("No app is in front to put the form's text into.")
            NSSound.beep()
            return
        }
        target = front
        let source = InputSourceGuard.current()
        restoresManualAzooKey = source == .azooKey
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        Task { await expectActive() }
        log.info("The form opened.")
        if source != .roman {
            // The form starts in English. Left cmd, as the user would press it, also turns
            // Hammerspoon's Ebi remapping off, which selecting the source directly would leave on
            poster.tapCommand(right: false)
            Task { await expectRoman() }
        }
    }

    private func hide() {
        putAway()
        log.info("The form closed; the draft stays.")
        Task { await restoreSource() }
    }

    /// The app gets back the input mode it had: azooKey selected by hand, or English (azooKey may
    /// have been selected in the form).
    private func restoreSource() async {
        if restoresManualAzooKey {
            restoreManualAzooKey()
            return
        }
        guard InputSourceGuard.current() != .roman else { return }
        guard await InputSourceSwitcher.select(InputSourceGuard.romanID) else {
            fail("Selecting the Roman source after the form failed.")
            return
        }
    }

    /// Hides the form and hands the activation back to the app the text goes to.
    private func putAway() {
        panel.orderOut(nil)
        if let target {
            NSApp.yieldActivation(to: target)
            target.activate(from: .current, options: [])
        }
    }

    /// macOS may turn an activation request down; without it the input method ignores the form.
    private func expectActive() async {
        let clock = ContinuousClock()
        let started = clock.now
        while clock.now - started < Self.switchTimeout {
            if NSApp.isActive {
                return
            }
            await InputSourceSwitcher.pause(.milliseconds(10))
        }
        fail("Kaede could not become the active app, so the form cannot use the input method.")
        putAway()
    }

    /// The form's keys go through Hammerspoon's left cmd; without Hammerspoon nothing switches.
    private func expectRoman() async {
        let clock = ContinuousClock()
        let started = clock.now
        while clock.now - started < Self.switchTimeout {
            if InputSourceGuard.current() == .roman {
                return
            }
            await InputSourceSwitcher.pause(.milliseconds(10))
        }
        fail("Left cmd did not select the Roman source; is Hammerspoon running?")
    }

    /// Back to the azooKey the user had selected, the way they select it: right cmd, which also
    /// turns Hammerspoon's Ebi remapping on again.
    private func restoreManualAzooKey() {
        guard restoresManualAzooKey else { return }
        restoresManualAzooKey = false
        poster.tapCommand(right: true)
    }

    private func insert() {
        guard !inserting, let target else { return }
        inserting = true
        Task {
            defer { inserting = false }
            await insert(into: target)
        }
    }

    private func insert(into target: NSRunningApplication) async {
        // Keep what the text view shows, conversion included, and let azooKey drop its own state
        if textView.hasMarkedText() {
            textView.unmarkText()
            textView.inputContext?.discardMarkedText()
            await InputSourceSwitcher.pause(.milliseconds(10))
            guard !textView.hasMarkedText() else {
                fail("Text being converted could not be settled.")
                return
            }
        }
        guard let converted = await currentConversion()?.text else {
            return
        }
        let pieces: [TypingPiece]
        do {
            pieces = try TypingPlan.pieces(for: converted)
        } catch {
            fail("The form's text cannot be typed: \(error)")
            return
        }
        guard !pieces.isEmpty else {
            hide()
            return
        }
        putAway()
        do {
            try await inserter.type(pieces, into: target.processIdentifier)
        } catch {
            fail("Putting the form's text into the app failed: \(error)")
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(textView)
            return
        }
        endChoosing()
        textView.string = ""
        textChanged()
        // After the app has taken the text in the Roman source
        await InputSourceSwitcher.pause(Self.restoreDelay)
        restoreManualAzooKey()
    }

    private func textChanged() {
        model.isEmpty = textView.textStorage?.length == 0
        if model.isEmpty {
            // A new draft starts from the first candidates
            choices = ConversionChoices()
        }
        convertForPreview()
    }

    /// Converts the text after a short pause, dropping a conversion the next change makes stale.
    func convertForPreview() {
        previewTask?.cancel()
        model.previewIsCurrent = false
        let request = Preview.Request(text: textView.string, style: style, choices: choices)
        previewTask = Task { [worker] in
            do {
                // Keys typed in a burst need one conversion, after the last
                try await Task.sleep(for: Self.previewPause)
                let converted = try await worker.convert(request.text, style: request.style, choices: request.choices)
                show(Preview(request: request, converted: converted))
            } catch is CancellationError {
                // A newer change converts instead
            } catch {
                fail("Converting the form's text failed: \(error)")
            }
        }
    }

    /// The conversion of the text as it is now, with the choices: the preview when it is
    /// current, else converted now. Nil when converting failed, which beeps.
    func currentConversion() async -> ConvertedText? {
        let request = Preview.Request(text: textView.string, style: style, choices: choices)
        if let preview, preview.request == request {
            return preview.converted
        }
        do {
            let converted = try await worker.convert(request.text, style: request.style, choices: request.choices)
            show(Preview(request: request, converted: converted))
            return converted
        } catch {
            fail("Converting the form's text failed: \(error)")
            return nil
        }
    }

    private func show(_ preview: Preview) {
        self.preview = preview
        model.preview = preview.converted.text
        model.previewIsCurrent = true
        followSelection(to: preview.converted.units)
    }

    func fail(_ message: String) {
        log.error("\(message, privacy: .public)")
        NSSound.beep()
    }

    private static let frameName = "KaedeInputForm"
    private static let cornerRadius: CGFloat = 16

    /// A stretchable mask with rounded corners for the translucent background.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
    /// How long Hammerspoon may take to switch after a command key, and macOS to activate Kaede.
    private static let switchTimeout: Duration = .milliseconds(300)
    /// How long before manual azooKey comes back, after the app has taken the text.
    private static let restoreDelay: Duration = .milliseconds(200)
    private static let previewPause: Duration = .milliseconds(30)
    private static let tabKeyCode: UInt16 = 48

    /// Plain text with nothing that changes words behind the user's back: spelling correction
    /// and completion would rewrite romaji as English.
    private static func makePlain(_ textView: NSTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: 15)
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.inlinePredictionType = .no
        textView.mathExpressionCompletionType = .no
        textView.writingToolsBehavior = .none
    }

    /// The modifiers held now. The event's own flags cannot be trusted: Hammerspoon turns
    /// cmd+Enter into Enter while Discord or Claude Desktop is in front.
    private static func heldModifiers() -> KeyCombo.Modifiers {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        return modifiers
    }

    /// Kaede shows no menu bar, but the menu's key equivalents give the form cmd+C, V, X, A, Z.
    static func installEditMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApplication.shared.mainMenu = menu
    }
}

/// The form's panel: borderless, floating over the app the text goes to.
private final class FormPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    /// Escape cancels azooKey's conversion; it must not close the form.
    override func cancelOperation(_ sender: Any?) {}
}

/// A conversion of the form's text and what it was asked with.
struct Preview {
    struct Request: Equatable {
        var text: String
        var style: PunctuationStyle
        var choices: ConversionChoices
    }

    var request: Request
    var converted: ConvertedText
}
