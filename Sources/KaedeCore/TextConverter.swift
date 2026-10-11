/// Converts what was typed in the form: English stays, romaji becomes Japanese, line by line.
public struct TextConverter: Sendable {
    private let segmenter: LineSegmenter

    public init(lexicon: EnglishLexicon) {
        segmenter = LineSegmenter(lexicon: lexicon)
    }

    /// - Parameters:
    ///   - layout: the layout the user types Japanese with.
    ///   - choices: conversions the user chose, used in place of `kanji`; a clause typed
    ///     differently keeps the phrases chosen in it (`CarriedChoice`).
    ///   - kanji: converts a clause of romaji (with digits) into Japanese phrases.
    public func convert(
        _ text: String, style: PunctuationStyle, layout: KeyboardLayout = .qwerty, choices: ConversionChoices = ConversionChoices(),
        kanji: (String) throws -> [Bunsetsu]
    ) rethrows -> ConvertedText {
        var converted = ConvertedText(text: "", units: [])
        func append(_ line: ConvertedText, number: Int) {
            let offset = converted.text.utf16.count
            converted.units += line.units.map { $0.shifted(by: offset, line: number) }
            converted.text += line.text
        }
        var lineStart = text.startIndex
        var number = 0
        for index in text.indices where text[index].isNewline {
            append(try convertLine(text[lineStart..<index], style: style, layout: layout, choices: choices, kanji: kanji), number: number)
            converted.text.append(text[index])
            lineStart = text.index(after: index)
            number += 1
        }
        append(try convertLine(text[lineStart...], style: style, layout: layout, choices: choices, kanji: kanji), number: number)
        return converted
    }

    private func convertLine(
        _ line: Substring, style: PunctuationStyle, layout: KeyboardLayout, choices: ConversionChoices, kanji: (String) throws -> [Bunsetsu]
    ) rethrows -> ConvertedText {
        try Assembler.assemble(segmenter.segments(of: line, layout: layout), style: style, englishChoices: choices.english) { clause in
            if let chosen = choices.clauses[clause] {
                return chosen
            }
            let carried = try CarriedChoice.phrases(for: clause, from: choices.clauses) { letters in
                try Self.fresh(letters, kanji: kanji)
            }
            return try carried ?? Self.fresh(clause, kanji: kanji)
        }
    }

    /// Converts letters nothing was chosen for.
    private static func fresh(_ letters: String, kanji: (String) throws -> [Bunsetsu]) rethrows -> [Bunsetsu] {
        // On its own a particle or verb ending has no sentence to choose its kanji by (の would be
        // 野, した 下)
        if let kana = FunctionWords.kana(of: letters) {
            return [Bunsetsu(reading: kana, text: kana, letterCount: letters.count)]
        }
        return try kanji(letters)
    }
}
