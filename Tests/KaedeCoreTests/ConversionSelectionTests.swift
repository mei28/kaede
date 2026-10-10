import Testing
@testable import KaedeCore

/// 今日は天気が google (line 0) and 酒 (line 1), as the converter would mark them.
private let units = [
    ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkiga", index: 0), text: "今日は", reading: "きょうは", range: 0..<3, line: 0),
    ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkiga", index: 1), text: "天気が", reading: "てんきが", range: 3..<6, line: 0),
    ConversionUnit(kind: .english("google"), text: "google", reading: "google", range: 7..<13, line: 0),
    ConversionUnit(kind: .bunsetsu(clause: "sake", index: 0), text: "酒", reading: "さけ", range: 14..<15, line: 1),
]

private func japanese(_ texts: String...) -> [ConversionCandidate] {
    texts.map { ConversionCandidate($0, .japanese) }
}

@Suite struct ConversionSelectionTests {
    @Test func startsAtTheFirstUnitOfTheLine() throws {
        #expect(try #require(ConversionSelection(units: units, line: 1, choices: ConversionChoices())).selectedUnit == units[3])
        #expect(try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices())).selectedUnit == units[0])
    }

    @Test func startsAtTheLastUnitBeforeALineWithoutUnits() throws {
        #expect(try #require(ConversionSelection(units: units, line: 5, choices: ConversionChoices())).selectedUnit == units[3])
    }

    @Test func hasNothingToSelectWithoutUnits() {
        #expect(ConversionSelection(units: [], line: 0, choices: ConversionChoices()) == nil)
    }

    @Test func movesBetweenUnitsAndStopsAtTheEnds() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        let moves = [-1, 1, 1, 1, 1].map { selection.move(by: $0) }
        #expect(moves == [false, true, true, true, false])
        #expect(selection.selectedUnit == units[3])
    }

    @Test func pointsAtTheShownTextAmongTheCandidates() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.show(candidates: japanese("強は", "今日は", "きょうは"))
        #expect(selection.candidateIndex == 1)
    }

    @Test func stepsThroughTheCandidatesAroundTheEnds() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.show(candidates: japanese("今日は", "強は", "きょうは"))
        let steps = [1, 1, 1, -1].map { selection.stepCandidate(by: $0)?.text }
        #expect(steps == ["強は", "きょうは", "今日は", "きょうは"])
    }

    @Test func picksACandidateByItsNumber() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.show(candidates: japanese("今日は", "強は"))
        let picks = [2, 3].map { selection.pickCandidate(number: $0)?.text }
        #expect(picks == ["強は", nil])
    }

    @Test func choosesAPhraseOfItsClause() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.move(by: 1)
        let choices = selection.choices(ConversionChoices(), choosing: ConversionCandidate("天気画", .japanese))
        #expect(choices.clauses["kyouhatenkiga"] == [Bunsetsu(reading: "きょうは", text: "今日は"), Bunsetsu(reading: "てんきが", text: "天気画")])
    }

    @Test func turnsEnglishJapaneseAndBack() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.move(by: 2)
        let japanese = selection.choices(ConversionChoices(), choosing: ConversionCandidate("ごおgぇ", .japanese))
        #expect(japanese.english["google"] == "ごおgぇ")
        #expect(selection.choices(japanese, choosing: ConversionCandidate("google", .english)).english["google"] == nil)
    }

    @Test func givesThePhrasesOfTheSelectedClause() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.move(by: 1)
        #expect(selection.clausePhrases == [Bunsetsu(reading: "きょうは", text: "今日は"), Bunsetsu(reading: "てんきが", text: "天気が")])
    }

    @Test func keepsTheSelectedPhraseWhenTheUnitsChange() throws {
        var selection = try #require(ConversionSelection(units: units, line: 0, choices: ConversionChoices()))
        selection.move(by: 1)
        // The first phrase was split: the selected one moved along
        let resized = [
            ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkiga", index: 0), text: "今日", reading: "きょう", range: 0..<2, line: 0),
            ConversionUnit(kind: .bunsetsu(clause: "kyouhatenkiga", index: 1), text: "葉天気が", reading: "はてんきが", range: 2..<6, line: 0),
        ]
        selection.update(units: resized)
        #expect(selection.selectedUnit == resized[1])
    }

    @Test func remembersTheChoicesItStartedWith() throws {
        var start = ConversionChoices()
        start.english["sake"] = "酒"
        #expect(try #require(ConversionSelection(units: units, line: 0, choices: start)).choicesAtStart == start)
    }
}
