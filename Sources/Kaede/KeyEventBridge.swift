import AppKit
import KaedeCore

/// Converts between AppKit key events and the engine's RawKey.
@MainActor
enum KeyEventBridge {
    /// NX_DEVICERSHIFTKEYMASK: the device-dependent right Shift bit in the event flags.
    private static let deviceRightShift: UInt = 0x0000_0004

    static func rawKey(from event: NSEvent) -> RawKey {
        let flags = event.modifierFlags
        return RawKey(
            keyCode: event.keyCode,
            character: event.characters.flatMap { $0.count == 1 ? $0.first : nil },
            shift: flags.contains(.shift),
            rightShift: flags.rawValue & deviceRightShift != 0,
            command: flags.contains(.command),
            control: flags.contains(.control),
            option: flags.contains(.option),
            isKaedeEvent: event.cgEvent?.getIntegerValueField(.eventSourceUserData) == EventPoster.marker
        )
    }

    /// The event with another of the 30 layout keys in its place: the key code, and the
    /// characters that key types, which is what azooKey reads.
    static func event(from event: NSEvent, keyCode: UInt16) -> NSEvent? {
        guard let position = KeyPosition(keyCode: keyCode) else {
            preconditionFailure("a remapped key outside the 30 layout keys: \(keyCode)")
        }
        let shift = event.modifierFlags.contains(.shift)
        return NSEvent.keyEvent(
            with: .keyDown,
            location: event.locationInWindow,
            modifierFlags: event.modifierFlags,
            timestamp: event.timestamp,
            windowNumber: event.windowNumber,
            context: nil,
            characters: String(Layout.qwerty.character(at: position, shift: shift)),
            charactersIgnoringModifiers: String(Layout.qwerty.character(at: position, shift: false)),
            isARepeat: event.isARepeat,
            keyCode: keyCode
        )
    }

    /// Rebuilds the flags of a key, for posting it again.
    nonisolated static func flags(of key: RawKey) -> CGEventFlags {
        var flags: CGEventFlags = []
        if key.shift { flags.insert(.maskShift) }
        if key.rightShift { flags.insert(CGEventFlags(rawValue: 0x0000_0004)) }
        if key.command { flags.insert(.maskCommand) }
        if key.control { flags.insert(.maskControl) }
        if key.option { flags.insert(.maskAlternate) }
        return flags
    }
}
