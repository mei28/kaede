/// Converts what was typed in the form: English stays, romaji becomes Japanese, line by line.
public struct TextConverter: Sendable {
    private let segmenter: LineSegmenter

    public init(lexicon: EnglishLexicon) {
        segmenter = LineSegmenter(lexicon: lexicon)
    }

    /// - Parameter kanji: converts a clause of romaji (with digits) into Japanese phrases.
    public func convert(_ text: String, style: PunctuationStyle, kanji: (String) throws -> [Bunsetsu]) rethrows -> String {
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

    private func convertLine(_ line: Substring, style: PunctuationStyle, kanji: (String) throws -> [Bunsetsu]) rethrows -> String {
        try Assembler.assemble(segmenter.segments(of: line), style: style) { clause in
            // On its own a particle or verb ending has no sentence to choose its kanji by (の would
            // be 野, した 下)
            if let kana = FunctionWords.kana(of: clause) {
                return [Bunsetsu(reading: kana, text: kana)]
            }
            return try kanji(clause)
        }
    }
}
