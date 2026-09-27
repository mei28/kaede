import AppKit
import KaedeCore

/// Kaede's window for writing: opened over the app in front, it puts its text into that app.
///
/// The panel never activates Kaede. The app in front stays in front, so hiding the panel gives
/// the keys back to it, and the event tap judges the keys typed into the panel as anywhere else.
@MainActor
final class InputForm {
    private let keys: FormKeys
    private let tap: EventTap
    private let inserter = TextInserter()
    private let panel: FormPanel
    private let textView: NSTextView
    private var insertMonitor: Any?
    /// The app in front when the form opened: the text goes there.
    private var target: NSRunningApplication?
    private var inserting = false

    init(keys: FormKeys, tap: EventTap) {
        self.keys = keys
        self.tap = tap
        panel = FormPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 220),
            // A panel made non-activating later keeps taking the keys from WindowServer's view,
            // so the style is set here, at creation
            styleMask: [.nonactivatingPanel, .titled, .resizable, .utilityWindow],
            backing: .buffered, defer: false
        )
        panel.title = "Kaede（\(keys.insert) で入れる、\(keys.open) で閉じる）"
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
        panel.contentView = scrollView

        // Before the key window and the input method see the key, so it works mid-conversion
        insertMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let keyCode = event.keyCode
            let windowNumber = event.windowNumber
            let taken = MainActor.assumeIsolated {
                self?.takeInsertKey(keyCode: keyCode, windowNumber: windowNumber) ?? false
            }
            return taken ? nil : event
        }
    }

    /// Inserts when the key is the insert key pressed in the form; returns whether it was.
    private func takeInsertKey(keyCode: UInt16, windowNumber: Int) -> Bool {
        guard windowNumber == panel.windowNumber, keys.insert.matches(keyCode: keyCode, modifiers: Self.heldModifiers()) else {
            return false
        }
        insert()
        return true
    }

    /// The open key: shows the form over the app in front, or hides it keeping the draft.
    func toggle() {
        guard !inserting else { return }
        guard !tap.isSwitching else {
            // Kaede is typing into the app in front; the panel would take those keys
            log.info("The form waits: Kaede is switching a word.")
            NSSound.beep()
            return
        }
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        guard let front = NSWorkspace.shared.frontmostApplication else {
            log.error("No app is in front to put the form's text into.")
            NSSound.beep()
            return
        }
        target = front
        tap.caretMoved()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        log.info("The form opened.")
    }

    private func hide() {
        panel.orderOut(nil)
        tap.caretMoved()
        log.info("The form closed; the draft stays.")
    }

    private func insert() {
        guard !inserting, let target else { return }
        guard !tap.isSwitching else {
            log.info("The form waits: Kaede is switching a word.")
            NSSound.beep()
            return
        }
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
        let pieces: [TypingPiece]
        do {
            pieces = try TypingPlan.pieces(for: textView.string)
        } catch {
            fail("The form's text cannot be typed: \(error)")
            return
        }
        guard !pieces.isEmpty else {
            hide()
            return
        }
        panel.orderOut(nil)
        tap.caretMoved()
        do {
            try await inserter.type(pieces, into: target.processIdentifier, tap: tap)
        } catch {
            fail("Putting the form's text into the app failed: \(error)")
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(textView)
            return
        }
        textView.string = ""
    }

    private func fail(_ message: String) {
        log.error("\(message, privacy: .public)")
        NSSound.beep()
    }

    private static let frameName = "KaedeInputForm"

    /// Plain text with nothing that changes words behind Kaede's back: Kaede deletes a word by
    /// counting its keys, so a corrected word would throw the count off.
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
        NSApp.mainMenu = menu
    }
}

/// A panel that takes the keys without activating Kaede.
private final class FormPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    /// Escape cancels azooKey's conversion; it must not close the form.
    override func cancelOperation(_ sender: Any?) {}
}
