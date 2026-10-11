import Testing
@testable import KaedeCore

/// What azooKey would write for the letters the tests convert afresh.
private let kanji: [String: String] = [
    "kyouhatenkigaii": "強は天気がいい",
    "tekigaii": "敵がいい",
    "kyouhatenkigai": "強は天気外",
    "kyouhasamui": "強は寒い",
    "tenkigai": "天気外",
    "tenkigaiidesune": "天気がいいですね",
    "kinouha": "昨日は",
    "gaii": "がいい",
]

private func phrase(_ reading: String, _ text: String, letters: Int?, chosen: Bool = false) -> Bunsetsu {
    Bunsetsu(reading: reading, text: text, letterCount: letters, isChosen: chosen)
}

/// 今日は chosen for 強は, the rest as azooKey wrote it.
private let todayChosen = [
    phrase("きょうは", "今日は", letters: 6, chosen: true),
    phrase("てんきがいい", "天気がいい", letters: 9),
]

/// 今日は and 天気 chosen, がいい as azooKey wrote it.
private let todayAndWeatherChosen = [
    phrase("きょうは", "今日は", letters: 6, chosen: true),
    phrase("てんき", "天気", letters: 5, chosen: true),
    phrase("がいい", "がいい", letters: 4),
]

@Suite struct CarriedChoiceTests {
    let converter = TextConverter(lexicon: EnglishLexicon(wordList: "google\n"))

    private func convert(_ text: String, _ clauses: [String: [Bunsetsu]]) -> ConvertedText {
        var choices = ConversionChoices()
        choices.clauses = clauses
        return converter.convert(text, style: .touten, choices: choices) { letters in
            guard let converted = kanji[letters] else {
                Issue.record("asked to convert \(letters)")
                return []
            }
            return [Bunsetsu(reading: letters, text: converted, letterCount: letters.count)]
        }
    }

    @Test func keepsAChosenPhraseWhenALetterAtTheEndGoes() {
        let converted = convert("kyouhatenkigai", ["kyouhatenkigaii": todayChosen])
        #expect(converted.text == "今日は天気外")
        #expect(converted.units.map(\.kind) == [.bunsetsu(clause: "kyouhatenkigai", index: 0), .bunsetsu(clause: "kyouhatenkigai", index: 1)])
        #expect(converted.units.map(\.isChosen) == [true, false])
        #expect(converted.units.map(\.letterCount) == [6, 8])
    }

    @Test func convertsTheLettersAddedWithThePhrasesNotChosen() {
        // 天気がいい was azooKey's: it is converted again with ですね
        #expect(convert("kyouhatenkigaiidesune", ["kyouhatenkigaii": todayChosen]).text == "今日は天気がいいですね")
    }

    @Test func keepsAChosenPhraseAfterTheLettersThatChanged() {
        let converted = convert("kinouhatenkigaii", ["kyouhatenkigaii": todayAndWeatherChosen])
        #expect(converted.text == "昨日は天気がいい")
        #expect(converted.units.map(\.isChosen) == [false, true, false])
    }

    @Test func dropsAChosenPhraseTheChangeRunsThrough() {
        // 天気 lost its n; 今日は stays
        let converted = convert("kyouhatekigaii", ["kyouhatenkigaii": todayAndWeatherChosen])
        #expect(converted.units.map(\.text) == ["今日は", "敵がいい"])
        #expect(converted.units.map(\.isChosen) == [true, false])
    }

    @Test func carriesNothingToAClauseThatKeepsHalfTheLettersOrFewer() {
        // kyouha and the final i: 7 of 15
        #expect(convert("kyouhasamui", ["kyouhatenkigaii": todayChosen]).text == "強は寒い")
    }

    @Test func carriesNoPhraseWithoutItsLetterCount() {
        let unplaced = [phrase("きょうは", "今日は", letters: nil, chosen: true), phrase("てんきがいい", "天気がいい", letters: nil)]
        #expect(convert("kyouhatenkigai", ["kyouhatenkigaii": unplaced]).text == "強は天気外")
    }

    @Test func carriesFromTheClauseThatKeepsTheMostLetters() {
        let rain = [phrase("きょうは", "強は", letters: 6, chosen: true), phrase("あめ", "雨", letters: 3)]
        #expect(convert("kyouhatenkigai", ["kyouhaame": rain, "kyouhatenkigaii": todayChosen]).text == "今日は天気外")
    }

    @Test func writesALeftoverParticleFromTheTable() {
        // no is not asked of azooKey, which would write 野
        #expect(convert("kyouhano", ["kyouha": [phrase("きょうは", "今日は", letters: 6, chosen: true)]]).text == "今日はの")
    }

    @Test func keepsTheClausesOwnChoiceFirst() {
        let own = [phrase("きょうはてんきがい", "京は天気がい", letters: 14, chosen: true)]
        #expect(convert("kyouhatenkigai", ["kyouhatenkigaii": todayChosen, "kyouhatenkigai": own]).text == "京は天気がい")
    }
}
