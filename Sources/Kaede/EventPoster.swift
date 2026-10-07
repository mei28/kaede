import CoreGraphics
import KaedeCore

/// Posts keyboard events, marked with `marker` as Kaede's own.
struct EventPoster {
    /// "KAED" in ASCII, stored in kCGEventSourceUserData.
    static let marker: Int64 = 0x4B41_4544

    private static let returnKeyCode: CGKeyCode = 36
    /// The key code Unicode text events carry. Not 0: Hammerspoon's Ebi remapping rebuilds a
    /// key-0 event as a bare "a" and drops the text. espanso uses Space too.
    private static let unicodeKeyCode: CGKeyCode = 49

    private let markedSource: CGEventSource

    init() {
        // A private state keeps the user's held modifiers out of the posted events.
        guard let source = CGEventSource(stateID: .privateState) else {
            terminate("Could not create an event source.")
        }
        source.userData = Self.marker
        markedSource = source
    }

    /// Types one piece of text (at most `TypingPlan.maxUnitsPerPiece` UTF-16 units) as a
    /// Unicode key event, marked.
    func typePiece(_ text: String) {
        let units = Array(text.utf16)
        precondition(units.count <= TypingPlan.maxUnitsPerPiece, "a piece longer than a key event carries")
        for keyDown in [true, false] {
            let event = makeEvent(Self.unicodeKeyCode, keyDown: keyDown, flags: [], source: markedSource)
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.post(tap: .cgSessionEventTap)
        }
    }

    /// A line break chat apps and Claude Code do not take for sending: Shift+Enter, marked.
    func newline() {
        postKey(Self.returnKeyCode, flags: .maskShift, source: markedSource)
    }

    /// Presses and releases a command key alone, as the user does to switch with Hammerspoon:
    /// left for English with its Ebi remapping off, right for azooKey with it on.
    func tapCommand(right: Bool) {
        let keyCode: CGKeyCode = right ? 0x36 : 0x37
        for (keyDown, flags) in [(true, CGEventFlags.maskCommand), (false, [])] {
            let event = makeEvent(keyCode, keyDown: keyDown, flags: flags, source: markedSource)
            event.type = .flagsChanged
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource?) {
        for keyDown in [true, false] {
            makeEvent(keyCode, keyDown: keyDown, flags: flags, source: source).post(tap: .cgSessionEventTap)
        }
    }

    private func makeEvent(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags, source: CGEventSource?) -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            terminate("Could not create a keyboard event.")
        }
        event.flags = flags
        return event
    }
}
