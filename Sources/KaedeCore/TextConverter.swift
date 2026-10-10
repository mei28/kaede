/// Converts what was typed in the form: English stays, romaji becomes Japanese, line by line.
public struct TextConverter: Sendable {
    private let segmenter: LineSegmenter

    public init(lexicon: EnglishLexicon) {
        segmenter = LineSegmenter(lexicon: lexicon)
    }

    /// - Parameters:
    ///   - choices: conversions the user chose, used in place of `kanji`.
    ///   - kanji: converts a clause of romaji (with digits) into Japanese phrases.
    public func convert(_ text: String, style: PunctuationStyle, choices: ConversionChoices = ConversionChoices(), kanji: (String) throws -> [Bunsetsu]) rethrows -> ConvertedText {
        var converted = ConvertedText(text: "", units: [])
        func append(_ line: ConvertedText, number: Int) {
            let offset = converted.text.utf16.count
            converted.units += line.units.map { $0.shifted(by: offset, line: number) }
            converted.text += line.text
        }
        var lineStart = text.startIndex
        var number = 0
        for index in text.indices where text[index].isNewline {
            append(try convertLine(text[lineStart..<index], style: style, choices: choices, kanji: kanji), number: number)
            converted.text.append(text[index])
            lineStart = text.index(after: index)
            number += 1
        }
        append(try convertLine(text[lineStart...], style: style, choices: choices, kanji: kanji), number: number)
        return converted
    }

    private func convertLine(_ line: Substring, style: PunctuationStyle, choices: ConversionChoices, kanji: (String) throws -> [Bunsetsu]) rethrows -> ConvertedText {
        try Assembler.assemble(segmenter.segments(of: line), style: style, japaneseForEnglish: choices.english) { clause in
            if let chosen = choices.clauses[clause] {
                return chosen
            }
            // On its own a particle or verb ending has no sentence to choose its kanji by (の would
            // be 野, した 下)
            if let kana = FunctionWords.kana(of: clause) {
                return [Bunsetsu(reading: kana, text: kana)]
            }
            return try kanji(clause)
        }
    }
}
