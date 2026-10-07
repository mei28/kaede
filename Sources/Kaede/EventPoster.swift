import CoreGraphics
import KaedeCore

/// Posts keyboard events.
struct EventPoster {
    private static let returnKeyCode: CGKeyCode = 36
    /// The key code Unicode text events carry. Not 0: Hammerspoon's Ebi remapping rebuilds a
    /// key-0 event as a bare "a" and drops the text. espanso uses Space too.
    private static let unicodeKeyCode: CGKeyCode = 49

    private let privateSource: CGEventSource

    init() {
        // A private state keeps the user's held modifiers out of the posted events.
        guard let source = CGEventSource(stateID: .privateState) else {
            terminate("Could not create an event source.")
        }
        privateSource = source
    }

    /// Types one piece of text (at most `TypingPlan.maxUnitsPerPiece` UTF-16 units) as a
    /// Unicode key event.
    func typePiece(_ text: String) {
        let units = Array(text.utf16)
        precondition(units.count <= TypingPlan.maxUnitsPerPiece, "a piece longer than a key event carries")
        for keyDown in [true, false] {
            let event = makeEvent(Self.unicodeKeyCode, keyDown: keyDown, flags: [])
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            event.post(tap: .cgSessionEventTap)
        }
    }

    /// A line break chat apps and Claude Code do not take for sending: Shift+Enter.
    func newline() {
        postKey(Self.returnKeyCode, flags: .maskShift)
    }

    /// Presses and releases a command key alone, as the user does to switch with Hammerspoon:
    /// left for English with its Ebi remapping off, right for azooKey with it on.
    func tapCommand(right: Bool) {
        let keyCode: CGKeyCode = right ? 0x36 : 0x37
        for (keyDown, flags) in [(true, CGEventFlags.maskCommand), (false, [])] {
            let event = makeEvent(keyCode, keyDown: keyDown, flags: flags)
            event.type = .flagsChanged
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        for keyDown in [true, false] {
            makeEvent(keyCode, keyDown: keyDown, flags: flags).post(tap: .cgSessionEventTap)
        }
    }

    private func makeEvent(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: privateSource, virtualKey: keyCode, keyDown: keyDown) else {
            terminate("Could not create a keyboard event.")
        }
        event.flags = flags
        return event
    }
}
