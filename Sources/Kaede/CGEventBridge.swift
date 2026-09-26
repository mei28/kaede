import CoreGraphics
import KaedeCore

enum CGEventBridge {
    /// NX_DEVICERSHIFTKEYMASK: the device-dependent right Shift bit in the event flags.
    private static let deviceRightShift: UInt64 = 0x0000_0004

    static func rawKey(from event: CGEvent) -> RawKey {
        let flags = event.flags
        return RawKey(
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            character: character(of: event),
            shift: flags.contains(.maskShift),
            rightShift: flags.rawValue & deviceRightShift != 0,
            command: flags.contains(.maskCommand),
            control: flags.contains(.maskControl),
            option: flags.contains(.maskAlternate),
            isKaedeEvent: event.getIntegerValueField(.eventSourceUserData) == EventPoster.marker
        )
    }

    /// The single character the event types, or nil when it types none or several.
    private static func character(of event: CGEvent) -> Character? {
        var units = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: units.count, actualStringLength: &length, unicodeString: &units)
        let string = String(utf16CodeUnits: units, count: length)
        return string.count == 1 ? string.first : nil
    }

    /// Rebuilds the flags of a key, for posting it again.
    static func flags(of key: RawKey) -> CGEventFlags {
        var flags: CGEventFlags = []
        if key.shift { flags.insert(.maskShift) }
        if key.rightShift { flags.insert(CGEventFlags(rawValue: deviceRightShift)) }
        if key.command { flags.insert(.maskCommand) }
        if key.control { flags.insert(.maskControl) }
        if key.option { flags.insert(.maskAlternate) }
        return flags
    }
}
