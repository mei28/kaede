/// A key with the modifiers held for it, written like "ctrl+alt+k" in the settings.
public struct KeyCombo: Equatable, Sendable, CustomStringConvertible {
    public struct Modifiers: OptionSet, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt16
    public var modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Reads modifiers and one key joined by "+", in any case and order: cmd (command),
    /// ctrl (control), alt (option), shift, and a key of the 30, a digit, enter (return),
    /// space or tab.
    public init(parsing text: String) throws {
        var modifiers: Modifiers = []
        var keyCode: UInt16?
        let parts = text.lowercased().split(separator: "+").map { String($0.filter { !$0.isWhitespace }) }
        for part in parts where !part.isEmpty {
            if let modifier = Self.modifierNames[part] {
                modifiers.insert(modifier)
                continue
            }
            guard let code = Self.keyCode(named: part) else {
                throw KeyComboError.unknownPart(part)
            }
            guard keyCode == nil else {
                throw KeyComboError.twoKeys(text)
            }
            keyCode = code
        }
        guard let keyCode else {
            throw KeyComboError.noKey(text)
        }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    /// The key pressed with exactly these modifiers held.
    public func matches(keyCode: UInt16, modifiers: Modifiers) -> Bool {
        self.keyCode == keyCode && self.modifiers == modifiers
    }

    /// The settings spelling: modifiers in a fixed order, then the key.
    public var description: String {
        let names = Self.modifierOrder.filter { modifiers.contains($0.modifier) }.map(\.name)
        return (names + [Self.keyName(of: keyCode)]).joined(separator: "+")
    }

    private static let modifierNames: [String: Modifiers] = [
        "cmd": .command, "command": .command,
        "ctrl": .control, "control": .control,
        "alt": .option, "option": .option,
        "shift": .shift,
    ]

    private static let modifierOrder: [(modifier: Modifiers, name: String)] = [
        (.command, "cmd"), (.control, "ctrl"), (.option, "alt"), (.shift, "shift"),
    ]

    /// Keys outside the 30 layout keys, by name (macOS virtual key codes).
    private static let namedKeys: [(name: String, keyCode: UInt16)] = [
        ("enter", 36), ("return", 36), ("space", 49), ("tab", 48),
        ("0", 0x1D), ("1", 0x12), ("2", 0x13), ("3", 0x14), ("4", 0x15),
        ("5", 0x17), ("6", 0x16), ("7", 0x1A), ("8", 0x1C), ("9", 0x19),
    ]

    private static func keyCode(named name: String) -> UInt16? {
        if name.count == 1, let position = KeyPosition.allCases.first(where: { String($0.qwertyCharacter) == name }) {
            return position.keyCode
        }
        return namedKeys.first { $0.name == name }?.keyCode
    }

    private static func keyName(of keyCode: UInt16) -> String {
        if let position = KeyPosition(keyCode: keyCode) {
            return String(position.qwertyCharacter)
        }
        guard let named = namedKeys.first(where: { $0.keyCode == keyCode }) else {
            preconditionFailure("a key combo holds a key code it cannot name: \(keyCode)")
        }
        return named.name
    }
}

public enum KeyComboError: Error, Equatable {
    case unknownPart(String)
    case noKey(String)
    case twoKeys(String)
}

/// The keys of the input form: one opens and closes it, the other puts its text into the app.
public struct FormKeys: Equatable, Sendable {
    public static let defaultOpen = "ctrl+alt+k"
    public static let defaultInsert = "cmd+enter"

    public let open: KeyCombo
    public let insert: KeyCombo

    public init(open: KeyCombo, insert: KeyCombo) throws {
        // macOS 15 refuses hot keys with only Option or Shift
        guard !open.modifiers.isDisjoint(with: [.control, .command]) else {
            throw FormKeysError.openNeedsControlOrCommand
        }
        guard open != insert else {
            throw FormKeysError.sameKeys
        }
        // Enter makes new lines in the form
        guard !(insert.keyCode == 36 && insert.modifiers.isEmpty) else {
            throw FormKeysError.plainEnterInserts
        }
        self.open = open
        self.insert = insert
    }
}

public enum FormKeysError: Error, Equatable {
    case openNeedsControlOrCommand
    case sameKeys
    case plainEnterInserts
}
