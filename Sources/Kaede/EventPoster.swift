import CoreGraphics
import KaedeCore

/// Posts keyboard events. Kaede's own events carry `marker` so its tap lets them through.
struct EventPoster {
    /// "KAED" in ASCII, stored in kCGEventSourceUserData.
    static let marker: Int64 = 0x4B41_4544

    /// CGEventKeyboardSetUnicodeString takes at most 20 UTF-16 units per event.
    private static let maxUnitsPerEvent = 20
    private static let backspaceKeyCode: CGKeyCode = 51

    private let markedSource: CGEventSource

    init() {
        // A private state keeps the user's held modifiers out of the posted events.
        guard let source = CGEventSource(stateID: .privateState) else {
            terminate("Could not create an event source.")
        }
        source.userData = Self.marker
        markedSource = source
    }

    func deleteBackward(_ count: Int) {
        for _ in 0..<count {
            postKey(Self.backspaceKeyCode, flags: [], source: markedSource)
        }
    }

    func type(_ text: String) {
        let units = Array(text.utf16)
        for start in stride(from: 0, to: units.count, by: Self.maxUnitsPerEvent) {
            let chunk = Array(units[start..<min(start + Self.maxUnitsPerEvent, units.count)])
            for keyDown in [true, false] {
                let event = makeEvent(0, keyDown: keyDown, flags: [], source: markedSource)
                event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event.post(tap: .cgSessionEventTap)
            }
        }
    }

    /// Presses the QWERTY keys that spell `romaji` (letters, "," and "."), marked, so an input
    /// method such as azooKey reads them as typed romaji.
    func typeKeys(_ romaji: String) {
        for character in romaji {
            guard let position = KeyPosition.allCases.first(where: { Layout.qwerty.character(at: $0, shift: false) == character }) else {
                preconditionFailure("romaji holds a character outside the 30 layout keys: \(character)")
            }
            postKey(CGKeyCode(position.keyCode), flags: [], source: markedSource)
        }
    }

    /// Presses a key by code, marked (Space to convert in azooKey, Return to commit).
    func press(_ keyCode: UInt16) {
        postKey(CGKeyCode(keyCode), flags: [], source: markedSource)
    }

    /// Posts a held key again, unmarked, so the tap handles it as fresh input.
    func replay(_ key: RawKey) {
        postKey(CGKeyCode(key.keyCode), flags: CGEventBridge.flags(of: key), source: nil)
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
