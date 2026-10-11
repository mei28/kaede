/// The form's text once converted, with the parts whose conversion can be chosen.
public struct ConvertedText: Equatable, Sendable {
    public var text: String
    /// In the order they appear.
    public var units: [ConversionUnit]
}

/// A part of the converted text whose conversion can be chosen: a phrase of a romaji clause, or
/// English.
public struct ConversionUnit: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The phrase at `index` of a clause, the clause named by its romaji.
        case bunsetsu(clause: String, index: Int)
        /// English words as typed.
        case english(String)
    }

    public var kind: Kind
    /// As it shows now.
    public var text: String
    /// The hiragana of a phrase; English as typed.
    public var reading: String
    /// Where it sits in the converted text, in UTF-16 offsets as AppKit counts them.
    public var range: Range<Int>
    /// Which line of the text it is on, from 0.
    public var line: Int
    /// The keys that typed it as QWERTY typed them: a phrase's whole clause, one for one with the
    /// clause's romaji; English's own keys.
    public var typed: String
    /// The language it counts in now: a phrase turned English, or English turned Japanese.
    public var language: Language
    /// A phrase's letters of its clause's romaji, when known (see `Bunsetsu.letterCount`).
    public var letterCount: Int?
    /// A phrase the user picked or moved the border of.
    public var isChosen: Bool

    /// - Parameters:
    ///   - typed: by default, the clause or the English, as typed in QWERTY.
    ///   - language: by default, Japanese for a phrase and English for English.
    ///   - letterCount, isChosen: a phrase's, as its `Bunsetsu` has them.
    public init(
        kind: Kind, text: String, reading: String, range: Range<Int>, line: Int, typed: String? = nil, language: Language? = nil,
        letterCount: Int? = nil, isChosen: Bool = false
    ) {
        self.kind = kind
        self.text = text
        self.reading = reading
        self.range = range
        self.line = line
        self.letterCount = letterCount
        self.isChosen = isChosen
        switch kind {
        case let .bunsetsu(clause, _):
            self.typed = typed ?? clause
            self.language = language ?? .japanese
        case let .english(english):
            self.typed = typed ?? english
            self.language = language ?? .english
        }
    }

    func shifted(by offset: Int, line: Int) -> ConversionUnit {
        ConversionUnit(
            kind: kind, text: text, reading: reading, range: (range.lowerBound + offset)..<(range.upperBound + offset), line: line,
            typed: typed, language: language, letterCount: letterCount, isChosen: isChosen
        )
    }
}
