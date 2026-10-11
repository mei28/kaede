import Testing
@testable import KaedeCore

private let kanji: [String: String] = [
    "kyouha": "今日は",
    "dekensaku": "で検索",
    "kore": "これ",
    "sore": "それ",
    "hontou": "本当",
    "15wo": "15を",
    "kakko": "括弧",
    "ni": "に",
]

private func assemble(_ segments: [Segment], style: PunctuationStyle = .touten) -> String {
    Assembler.assemble(segments, style: style, englishChoices: [:]) { clause in
        guard let converted = kanji[clause] else {
            Issue.record("no conversion for \(clause)")
            return []
        }
        return [Bunsetsu(reading: clause, text: converted)]
    }.text
}

private func segment(_ content: Segment.Content, space: Bool = false) -> Segment {
    Segment(content: content, spaceBefore: space)
}

@Suite struct AssemblerTests {
    @Test func putsAHalfWidthSpaceBetweenJapaneseAndEnglish() {
        #expect(assemble([segment(.romaji("kyouha")), segment(.english("google")), segment(.romaji("dekensaku"))]) == "今日は google で検索")
        #expect(assemble([segment(.japaneseText("今日は")), segment(.english("google"), space: true)]) == "今日は google")
    }

    @Test func spacesEnglishAsTyped() {
        #expect(assemble([segment(.english("this is a pen")), segment(.punctuation(".", .english))]) == "this is a pen.")
        #expect(assemble([segment(.english("python")), segment(.digits("3"), space: true)]) == "python 3")
        #expect(assemble([segment(.english("hello")), segment(.punctuation(",", .english)), segment(.english("world"), space: true)]) == "hello, world")
    }

    @Test func writesJapanesePunctuationInTheChosenStyle() {
        let line = [segment(.romaji("kore")), segment(.punctuation(",", .japanese)), segment(.romaji("sore")), segment(.punctuation(".", .japanese))]
        #expect(assemble(line, style: .touten) == "これ、それ。")
        #expect(assemble(line, style: .fullWidthCommaPeriod) == "これ，それ．")
        #expect(assemble(line, style: .toutenFullWidthPeriod) == "これ、それ．")
        #expect(assemble(line, style: .fullWidthCommaKuten) == "これ，それ。")
    }

    @Test func writesJapaneseQuestionAndExclamationMarksFullWidth() {
        #expect(assemble([segment(.romaji("hontou")), segment(.punctuation("?", .japanese))]) == "本当？")
        #expect(assemble([segment(.romaji("hontou")), segment(.punctuation("!", .japanese))]) == "本当！")
    }

    @Test func addsNoSpaceNextToJapanesePunctuation() {
        #expect(assemble([segment(.romaji("kore")), segment(.punctuation(",", .japanese)), segment(.english("google"), space: true)]) == "これ、google")
    }

    @Test func spacesADigitFacingJapaneseOnlyAsTyped() {
        #expect(assemble([segment(.english("iPhone")), segment(.romaji("15wo"))]) == "iPhone15を")
        #expect(assemble([segment(.english("iPhone")), segment(.romaji("15wo"), space: true)]) == "iPhone 15を")
    }

    @Test func spacesMarksAsTyped() {
        #expect(assemble([segment(.mark("(")), segment(.romaji("kakko")), segment(.mark(")"))]) == "(括弧)")
        #expect(assemble([segment(.english("GitHub")), segment(.mark("\""), space: true), segment(.romaji("ni"))]) == "GitHub \"に")
    }

    @Test func putsNothingTogetherFromNothing() {
        #expect(assemble([]) == "")
    }
}

@Suite struct PunctuationStyleTests {
    @Test func namesItselfByItsPair() {
        #expect(PunctuationStyle.allCases.map(\.rawValue) == ["、。", "，．", "、．", "，。"])
        #expect(PunctuationStyle(rawValue: "，．") == .fullWidthCommaPeriod)
    }
}

@Suite struct EnglishPhraseTests {
    private let phrases = [
        Bunsetsu(reading: "きょうは", text: "今日は"),
        Bunsetsu(reading: "うぇあれ", text: "we are", language: .english),
    ]

    @Test func spacesAPhraseTurnedEnglishAsEnglish() {
        let line = Assembler.assemble([Segment(content: .romaji("kyouhaweare"), spaceBefore: false)], style: .touten, englishChoices: [:]) { _ in phrases }
        #expect(line.text == "今日は we are")
        #expect(line.units == [
            ConversionUnit(kind: .bunsetsu(clause: "kyouhaweare", index: 0), text: "今日は", reading: "きょうは", range: 0..<3, line: 0),
            ConversionUnit(kind: .bunsetsu(clause: "kyouhaweare", index: 1), text: "we are", reading: "うぇあれ", range: 4..<10, line: 0, language: .english),
        ])
    }
}
