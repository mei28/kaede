/// The comma and period Japanese text is written with, named by the pair.
public enum PunctuationStyle: String, CaseIterable, Sendable {
    case touten = "、。"
    case fullWidthCommaPeriod = "，．"
    case toutenFullWidthPeriod = "、．"
    case fullWidthCommaKuten = "，。"

    var comma: Character {
        rawValue.first!
    }

    var period: Character {
        rawValue.last!
    }
}

/// Puts a line's segments together once its romaji is converted.
///
/// English and Japanese are set apart by one half-width space (今日は google で検索), except next
/// to punctuation and where a digit faces the other language (iPhone15を), which keep the spaces
/// as typed. English keeps its own spacing; Japanese has none.
public enum Assembler {
    /// The line, and its phrases and English with their places on the line (line 0).
    /// - Parameters:
    ///   - englishChoices: what the user turned English into, by the English as it shows.
    ///   - convert: converts a clause of romaji into its phrases.
    public static func assemble(_ segments: [Segment], style: PunctuationStyle, englishChoices: [String: ConversionCandidate], convert: (String) throws -> [Bunsetsu]) rethrows -> ConvertedText {
        var line = ""
        var units: [ConversionUnit] = []
        var previous: Part?
        for segment in segments {
            for part in try Part.parts(of: segment, style: style, englishChoices: englishChoices, convert: convert) {
                if let previous, spaced(previous, part) {
                    line.append(" ")
                }
                let start = line.utf16.count
                units += part.units.map { $0.shifted(by: start, line: 0) }
                line += part.text
                previous = part
            }
        }
        return ConvertedText(text: line, units: units)
    }

    private static func spaced(_ before: Part, _ after: Part) -> Bool {
        if after.role == .punctuation {
            return false
        }
        if before.role == .punctuation, before.language == .japanese {
            return false
        }
        if before.role == .mark || after.role == .mark {
            return after.spaceBefore
        }
        switch (before.language, after.language) {
        case (.japanese, .japanese):
            return false
        case (.english, .english):
            return after.spaceBefore
        default:
            let digitFaces = before.text.last?.isNumber == true || after.text.first?.isNumber == true
            return digitFaces ? after.spaceBefore : true
        }
    }
}

/// A segment as it is written, with what the spacing rules need to know about it.
private struct Part {
    enum Role {
        case words
        case punctuation
        case mark
    }

    var text: String
    var language: Language
    var role: Role
    var spaceBefore: Bool
    /// Its choosable parts, placed from the part's start.
    var units: [ConversionUnit] = []

    private init(text: String, language: Language, role: Role, spaceBefore: Bool, units: [ConversionUnit] = []) {
        self.text = text
        self.language = language
        self.role = role
        self.spaceBefore = spaceBefore
        self.units = units
    }

    /// One part for a segment, but a clause with phrases turned English splits into its runs of
    /// Japanese and its English phrases, to be spaced apart.
    static func parts(of segment: Segment, style: PunctuationStyle, englishChoices: [String: ConversionCandidate], convert: (String) throws -> [Bunsetsu]) rethrows -> [Part] {
        guard case let .romaji(clause) = segment.content else {
            return [try Part(segment, style: style, englishChoices: englishChoices, convert: convert)]
        }
        var parts: [Part] = []
        for (index, phrase) in try convert(clause).enumerated() {
            if phrase.language == .japanese, let last = parts.last, last.language == .japanese {
                parts[parts.count - 1].append(phrase, at: index, of: clause)
            } else {
                var part = Part(text: "", language: phrase.language, role: .words, spaceBefore: parts.isEmpty && segment.spaceBefore)
                part.append(phrase, at: index, of: clause)
                parts.append(part)
            }
        }
        return parts
    }

    private mutating func append(_ phrase: Bunsetsu, at index: Int, of clause: String) {
        let start = text.utf16.count
        text += phrase.text
        units.append(ConversionUnit(
            kind: .bunsetsu(clause: clause, index: index), text: phrase.text, reading: phrase.reading,
            range: start..<text.utf16.count, line: 0, language: phrase.language
        ))
    }

    private init(_ segment: Segment, style: PunctuationStyle, englishChoices: [String: ConversionCandidate], convert: (String) throws -> [Bunsetsu]) rethrows {
        spaceBefore = segment.spaceBefore
        switch segment.content {
        case let .english(typed):
            // Turned Japanese, it is spaced as Japanese
            let chosen = englishChoices[typed] ?? ConversionCandidate(typed, .english)
            (text, language, role) = (chosen.text, chosen.language, .words)
            units = [ConversionUnit(kind: .english(typed), text: text, reading: typed, range: 0..<text.utf16.count, line: 0, language: language)]
        case .romaji:
            preconditionFailure("clauses are split into parts by parts(of:)")
        case let .japaneseText(text):
            (self.text, language, role) = (text, .japanese, .words)
        case let .digits(digits):
            (text, language, role) = (digits, .english, .words)
        case let .punctuation(character, .english):
            (text, language, role) = (String(character), .english, .punctuation)
        case let .punctuation(character, .japanese):
            (text, language, role) = (String(Self.japanese(character, style: style)), .japanese, .punctuation)
        case let .mark(mark):
            (text, language, role) = (mark, .english, .mark)
        }
    }

    private static func japanese(_ punctuation: Character, style: PunctuationStyle) -> Character {
        switch punctuation {
        case ",": style.comma
        case ".": style.period
        case "?": "？"
        case "!": "！"
        default: preconditionFailure("the tokenizer cuts only , . ? ! as punctuation: \(punctuation)")
        }
    }
}
