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
    Assembler.assemble(segments, style: style) { clause in
        guard let converted = kanji[clause] else {
            Issue.record("no conversion for \(clause)")
            return clause
        }
        return converted
    }
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
