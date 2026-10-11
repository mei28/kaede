/// A short written form of how a line was segmented, for tests and the evaluation table: what
/// is English and what Japanese, and which fingering typed it, without azooKey's kanji.
///
/// `ja(watashino + L:risou)` is a clause whose second spelling was read through the layout,
/// `en(api)` English typed in QWERTY and `en/L(world)` English read through the layout.
public enum SegmentNotation {
    public static func notation(of segments: [Segment]) -> String {
        segments.map { notation(of: $0.content) }.joined(separator: " ")
    }

    private static func notation(of content: Segment.Content) -> String {
        switch content {
        case let .english(spelling):
            spelling.fingering == .layout ? "en/L(\(spelling.text))" : "en(\(spelling.text))"
        case let .romaji(clause):
            "ja(" + clause.spellings.map { ($0.fingering == .layout ? "L:" : "") + $0.text }.joined(separator: " + ") + ")"
        case let .japaneseText(text):
            "text(\(text))"
        case let .digits(digits):
            "num(\(digits))"
        case let .punctuation(character, .english):
            String(character)
        case let .punctuation(character, .japanese):
            String(japanese(character))
        case let .mark(mark):
            "mark(\(mark))"
        }
    }

    private static func japanese(_ punctuation: Character) -> Character {
        switch punctuation {
        case ",": "、"
        case ".": "。"
        case "?": "？"
        case "!": "！"
        default: preconditionFailure("the tokenizer cuts only , . ? ! as punctuation: \(punctuation)")
        }
    }
}
