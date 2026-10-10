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
    /// The language it counts in now: a phrase turned English, or English turned Japanese.
    public var language: Language

    /// - Parameter language: by default, Japanese for a phrase and English for English.
    public init(kind: Kind, text: String, reading: String, range: Range<Int>, line: Int, language: Language? = nil) {
        self.kind = kind
        self.text = text
        self.reading = reading
        self.range = range
        self.line = line
        self.language = language ?? {
            if case .english = kind { .english } else { .japanese }
        }()
    }

    func shifted(by offset: Int, line: Int) -> ConversionUnit {
        ConversionUnit(kind: kind, text: text, reading: reading, range: (range.lowerBound + offset)..<(range.upperBound + offset), line: line, language: language)
    }
}
