import Testing
@testable import KaedeCore

private let lexicon = EnglishLexicon(wordList: """
    this
    is
    a
    pen
    python
    bug
    no
    push
    commit
    """)

private let kanji: [String: String] = [
    "kyouha": "今日は",
    "kyouhatenkigaii": "今日は天気がいい",
]

@Suite struct TextConverterTests {
    let converter = TextConverter(lexicon: lexicon)

    private func convert(_ text: String) -> String {
        converter.convert(text, style: .touten) { clause in
            guard let converted = kanji[clause] else {
                Issue.record("asked to convert \(clause)")
                return []
            }
            return [Bunsetsu(reading: clause, text: converted, letterCount: clause.count)]
        }.text
    }

    @Test func convertsEachLineAndKeepsTheLineBreaks() {
        #expect(convert("kyouha\nthisisapen.") == "今日は\nthis is a pen.")
        #expect(convert("kyouha\r\n\r\nkyouha") == "今日は\r\n\r\n今日は")
    }

    @Test func dropsSpacesAroundALine() {
        #expect(convert("  kyouha tenkiga ii  ") == "今日は天気がいい")
    }

    @Test func writesALoneParticleWithoutTheConverter() {
        // On its own azooKey may well write の as 野
        #expect(convert("python no bug") == "python の bug")
        #expect(convert("pythonnobug") == "python の bug")
    }

    @Test func writesALoneVerbEndingWithoutTheConverter() {
        // On its own azooKey writes した as 下
        #expect(convert("pushshita") == "push した")
        #expect(convert("commit site push simasu") == "commit して push します")
    }

    @Test func convertsNothingToNothing() {
        #expect(convert("") == "")
    }
}

@Suite struct ConvertedUnitTests {
    let converter = TextConverter(lexicon: EnglishLexicon(wordList: "google\n"))

    private func convert(_ text: String) -> ConvertedText {
        converter.convert(text, style: .touten) { clause in
            switch clause {
            case "kyouhatenkigaii":
                [
                    Bunsetsu(reading: "きょうは", text: "今日は", letterCount: 6), Bunsetsu(reading: "てんきが", text: "天気が", letterCount: 7),
                    Bunsetsu(reading: "いい", text: "いい", letterCount: 2),
                ]
            case "kyouha":
                [Bunsetsu(reading: "きょうは", text: "今日は", letterCount: 6)]
            default:
                []
            }
        }
    }

    @Test func marksEachPhraseOfAClause() {
        #expect(convert("kyouhatenkigaii").units == [
            ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkigaii", index: 0), text: "今日は", reading: "きょうは", range: 0..<3, line: 0, letterCount: 6),
            ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkigaii", index: 1), text: "天気が", reading: "てんきが", range: 3..<6, line: 0, letterCount: 7),
            ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkigaii", index: 2), text: "いい", reading: "いい", range: 6..<8, line: 0, letterCount: 2),
        ])
    }

    @Test func marksEnglishAfterTheSpaceBeforeIt() {
        #expect(convert("kyouha google").units == [
            ConversionUnit(kind: .bunsetsu(clause: "kyouha", index: 0), text: "今日は", reading: "きょうは", range: 0..<3, line: 0, letterCount: 6),
            ConversionUnit(kind: .english("google"), text: "google", reading: "google", range: 4..<10, line: 0),
        ])
    }

    @Test func countsRangesAcrossLinesInUTF16() {
        let converted = convert("google\nkyouha")
        #expect(converted.text == "google\n今日は")
        #expect(converted.units.map(\.range) == [0..<6, 7..<10])
        #expect(converted.units.map(\.line) == [0, 1])
    }

    @Test func countsTheLettersOfAParticleWrittenWithoutTheConverter() {
        #expect(convert("google no").units.last?.letterCount == 2)
    }

    @Test func leavesPunctuationAndDigitsOut() {
        #expect(convert("kyouha, 3").units.map(\.text) == ["今日は"])
    }
}

@Suite struct ConversionChoicesTests {
    let converter = TextConverter(lexicon: EnglishLexicon(wordList: "this\nis\nsake\n"))

    private func convert(_ text: String, _ choices: ConversionChoices) -> ConvertedText {
        converter.convert(text, style: .touten, choices: choices) { clause in
            Issue.record("asked to convert \(clause)")
            return []
        }
    }

    @Test func usesThePhrasesChosenForAClause() {
        var choices = ConversionChoices()
        choices.clauses["kyouha"] = [Bunsetsu(reading: "きょうは", text: "強は", letterCount: 6, isChosen: true)]
        #expect(convert("kyouha", choices).text == "強は")
        #expect(convert("kyouha", choices).units.map(\.isChosen) == [true])
    }

    @Test func usesThePhrasesChosenForAParticle() {
        var choices = ConversionChoices()
        choices.clauses["no"] = [Bunsetsu(reading: "の", text: "野", letterCount: 2, isChosen: true)]
        #expect(convert("no", choices).text == "野")
    }

    @Test func writesEnglishTheUserTurnedJapaneseAsJapanese() {
        var choices = ConversionChoices()
        choices.english["sake"] = ConversionCandidate("酒", .japanese)
        let converted = convert("this is sake", choices)
        #expect(converted.text == "this is 酒")
        #expect(converted.units.last == ConversionUnit(kind: .english("sake"), text: "酒", reading: "sake", range: 8..<9, line: 0, language: .japanese))
    }
}
