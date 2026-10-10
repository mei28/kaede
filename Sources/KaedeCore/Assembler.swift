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
    /// - Parameter convert: converts a clause of romaji into its phrases.
    public static func assemble(_ segments: [Segment], style: PunctuationStyle, convert: (String) throws -> [Bunsetsu]) rethrows -> String {
        var line = ""
        var previous: Part?
        for segment in segments {
            let part = try Part(segment, style: style, convert: convert)
            if let previous, spaced(previous, part) {
                line.append(" ")
            }
            line += part.text
            previous = part
        }
        return line
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

    init(_ segment: Segment, style: PunctuationStyle, convert: (String) throws -> [Bunsetsu]) rethrows {
        spaceBefore = segment.spaceBefore
        switch segment.content {
        case let .english(text):
            (self.text, language, role) = (text, .english, .words)
        case let .romaji(clause):
            (text, language, role) = (try convert(clause).map(\.text).joined(), .japanese, .words)
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
