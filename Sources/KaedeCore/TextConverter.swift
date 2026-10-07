/// Converts what was typed in the form: English stays, romaji becomes Japanese, line by line.
public struct TextConverter: Sendable {
    private let segmenter: LineSegmenter

    public init(lexicon: EnglishLexicon) {
        segmenter = LineSegmenter(lexicon: lexicon)
    }

    /// - Parameter kanji: converts a clause of romaji (with digits) to Japanese.
    public func convert(_ text: String, style: PunctuationStyle, kanji: (String) throws -> String) rethrows -> String {
        var converted = ""
        var lineStart = text.startIndex
        for index in text.indices where text[index].isNewline {
            converted += try convertLine(text[lineStart..<index], style: style, kanji: kanji)
            converted.append(text[index])
            lineStart = text.index(after: index)
        }
        converted += try convertLine(text[lineStart...], style: style, kanji: kanji)
        return converted
    }

    private func convertLine(_ line: Substring, style: PunctuationStyle, kanji: (String) throws -> String) rethrows -> String {
        try Assembler.assemble(segmenter.segments(of: line), style: style) { clause in
            // On its own a particle or verb ending has no sentence to choose its kanji by (の would
            // be 野, した 下)
            try FunctionWords.kana(of: clause) ?? kanji(clause)
        }
    }
}
