/// A key-down event as the tap sees it, stripped of AppKit types.
public struct RawKey: Equatable, Sendable {
    public var keyCode: UInt16
    /// The character the event types under the current input source, if any.
    public var character: Character?
    public var shift: Bool
    /// Right Shift specifically (the device-dependent flag bit).
    public var rightShift: Bool
    public var command: Bool
    public var control: Bool
    public var option: Bool
    /// Posted by Kaede itself (marked through `kCGEventSourceUserData`).
    public var isKaedeEvent: Bool

    public init(
        keyCode: UInt16, character: Character?,
        shift: Bool = false, rightShift: Bool = false,
        command: Bool = false, control: Bool = false, option: Bool = false,
        isKaedeEvent: Bool = false
    ) {
        self.keyCode = keyCode
        self.character = character
        self.shift = shift
        self.rightShift = rightShift
        self.command = command
        self.control = control
        self.option = option
        self.isKaedeEvent = isKaedeEvent
    }
}

extension RawKey {
    /// The character the key types, unless it is a control character (editing keys) or a
    /// private-use one (function keys).
    var printableCharacter: Character? {
        guard let character, character.unicodeScalars.allSatisfy({ scalar in
            ![.control, .privateUse].contains(scalar.properties.generalCategory)
        }) else { return nil }
        return character
    }

    /// The custom keyboard sends ? : < > from its symbol layer with right Shift. The built-in
    /// keyboard's right Shift sets the same bit, so only these four keys honor it.
    func isSymbolLayer(at position: KeyPosition) -> Bool {
        rightShift && [.semicolon, .comma, .period, .slash].contains(position)
    }
}

/// macOS virtual key codes of the keys with their own rules.
enum KeyCode {
    static let backspace: UInt16 = 51
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    /// Return and keypad Enter.
    static let enter: Set<UInt16> = [36, 76]
    /// Keys that move the caret or leave the text: Tab, Escape, and the four arrows.
    static let resettingRun: Set<UInt16> = [48, 53, 123, 124, 125, 126]
}
