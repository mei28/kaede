import AppKit
import KaedeCore

extension KeyCombo.Modifiers {
    /// The modifiers a key combo can hold, out of an event's flags; marks such as function and
    /// keypad, which macOS puts on arrow keys, are left out.
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
    }
}
