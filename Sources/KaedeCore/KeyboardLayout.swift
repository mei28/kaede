public enum KeyboardLayoutError: Error, Equatable {
    case rowCount(Int)
    /// Rows count from 1.
    case rowLength(row: Int, length: Int)
    case notAKey(Character, row: Int)
    case repeated(Character)
}

/// A keyboard layout the user types Japanese with, written as the characters it puts on the 30
/// keys of the QWERTY rows `qwertyuiop`, `asdfghjkl;` and `zxcvbnm,./`.
///
/// The form receives what QWERTY types, so reading text through the layout recovers what the
/// user's fingers meant: Ebi's tatoeba arrives as `jajsd/a`.
public struct KeyboardLayout: Hashable, Sendable {
    public struct Preset: Sendable {
        public let name: String
        public let layout: KeyboardLayout
    }

    /// Three rows of ten characters.
    public let rows: [String]
    private let characters: [Character: Character]

    /// Spaces in a row are ignored, so the rows of a Hammerspoon layout can be pasted.
    public init(rows: [String]) throws(KeyboardLayoutError) {
        guard rows.count == 3 else {
            throw .rowCount(rows.count)
        }
        let rows = rows.map { $0.filter { !$0.isWhitespace } }
        var seen: Set<Character> = []
        for (index, row) in rows.enumerated() {
            guard row.count == 10 else {
                throw .rowLength(row: index + 1, length: row.count)
            }
            for character in row {
                guard Self.keys.contains(character) else {
                    throw .notAKey(character, row: index + 1)
                }
                guard seen.insert(character).inserted else {
                    throw .repeated(character)
                }
            }
        }
        self.rows = rows
        characters = Dictionary(uniqueKeysWithValues: zip(Self.keys, rows.joined()))
    }

    /// Typing in QWERTY: nothing reads differently.
    public var isQwerty: Bool {
        rows.joined() == String(Self.keys)
    }

    /// The character the layout puts on the key QWERTY typed `key` with. A capital reads as the
    /// layout's capital, or as its key's shifted symbol (Ebi's E as <); anything off the 30 keys
    /// reads as typed.
    public func read(_ key: Character) -> Character {
        if let character = characters[key] {
            return character
        }
        guard key.isUppercase, let lowercase = key.lowercased().first, let character = characters[lowercase] else {
            return key
        }
        return Self.shiftedSymbols[character] ?? Character(character.uppercased())
    }

    public func read(_ keys: some StringProtocol) -> String {
        String(keys.map(read))
    }

    /// The 30 keys in QWERTY row order.
    private static let keys: [Character] = KeyPosition.allCases.map(\.qwertyCharacter)
    private static let shiftedSymbols: [Character: Character] = [",": "<", ".": ">", ";": ":", "/": "?"]

    private init(validRows rows: [String]) {
        do {
            try self.init(rows: rows)
        } catch {
            preconditionFailure("a built-in layout is valid: \(error)")
        }
    }

    public static let qwerty = KeyboardLayout(validRows: ["qwertyuiop", "asdfghjkl;", "zxcvbnm,./"])
    // As in the user's dotfiles (.hammerspoon/*.lua)
    public static let ebi = KeyboardLayout(validRows: ["ql,.;fwryp", "aoeiuktnsh", "zxcv/gdmjb"])
    public static let eucalyn = KeyboardLayout(validRows: ["qw,.;mrdyp", "aoeiugtksn", "zxcvfbhjl/"])
    public static let oonishi = KeyboardLayout(validRows: ["qlu,.fwryp", "aoei/ktnsh", "zxcv;gdmjb"])
    public static let waddlier = KeyboardLayout(validRows: ["qle,.fwryp", "aoiu;ktnsh", "zxcvbgdmj/"])

    public static let presets = [
        Preset(name: "Ebi", layout: ebi),
        Preset(name: "Eucalyn", layout: eucalyn),
        Preset(name: "大西", layout: oonishi),
        Preset(name: "Waddlier", layout: waddlier),
    ]
}
