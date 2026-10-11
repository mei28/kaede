/// Which fingering typed some keys: QWERTY, or the user's layout read back from QWERTY.
public enum Fingering: Hashable, Sendable {
    case qwerty
    case layout
}

/// Text as read from typed keys, with the keys themselves, character for character.
public struct Spelling: Hashable, Sendable, ExpressibleByStringLiteral {
    /// As read: romaji, or English.
    public var text: String
    /// The keys as QWERTY typed them.
    public var typed: String
    public var fingering: Fingering

    public init(text: String, typed: String, fingering: Fingering) {
        self.text = text
        self.typed = typed
        self.fingering = fingering
    }

    /// Typed in QWERTY: the keys are the text.
    public init(qwerty text: String) {
        self.init(text: text, typed: text, fingering: .qwerty)
    }

    public init(stringLiteral text: String) {
        self.init(qwerty: text)
    }
}

/// A clause of romaji to convert as one sentence, made of spellings that may come from either
/// fingering.
public struct Clause: Hashable, Sendable, ExpressibleByStringLiteral {
    public private(set) var spellings: [Spelling]

    public init(_ spellings: [Spelling]) {
        self.spellings = []
        spellings.forEach { append($0) }
    }

    public init(stringLiteral romaji: String) {
        self.init([Spelling(qwerty: romaji)])
    }

    /// The romaji as read, which names the clause.
    public var romaji: String {
        spellings.map(\.text).joined()
    }

    /// The keys, one for one with the romaji.
    public var typed: String {
        spellings.map(\.typed).joined()
    }

    /// Adds a spelling, joining it to the last one when the same fingering typed both.
    public mutating func append(_ spelling: Spelling) {
        if let last = spellings.last, last.fingering == spelling.fingering {
            spellings[spellings.count - 1] = Spelling(text: last.text + spelling.text, typed: last.typed + spelling.typed, fingering: last.fingering)
        } else {
            spellings.append(spelling)
        }
    }
}
