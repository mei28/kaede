import Testing
@testable import KaedeCore

@Suite struct WordTableTests {
    @Test func readsTheTextBeforeTheKeysAndTheAnswer() throws {
        let table = "# comment\n\nkore ha \tjajsd/a\tjapanese_ebi\n\tthis\tenglish\n"
        #expect(try WordTable.parse(table) == [
            WordCase(textBefore: "kore ha ", keys: "jajsd/a", answer: .japaneseEbi),
            WordCase(textBefore: "", keys: "this", answer: .english),
        ])
    }

    @Test func failsOnAMalformedLineWithItsNumber() {
        #expect(throws: WordTableError.malformedLine(2)) {
            try WordTable.parse("\tthis\tenglish\nthis english\n")
        }
    }

    @Test func failsOnAnAnswerThatIsNoWordsLanguage() {
        #expect(throws: WordTableError.unknownAnswer(line: 1, "keep")) {
            try WordTable.parse("\tthis\tkeep\n")
        }
    }
}

@Suite struct SimulationTests {
    private func answering(_ answer: Answer, _ confidence: Double, for word: WordCase) -> [String: TimedJudgment] {
        Dictionary(uniqueKeysWithValues: Simulation.questions(for: word).map {
            ($0.keys, TimedJudgment(judgment: Judgment(answer: answer, confidence: confidence), latency: .milliseconds(100)))
        })
    }

    @Test func asksAboutEachPrefixThatCanStillBeJapanese() {
        let word = WordCase(textBefore: "kore ", keys: "jajs", answer: .japaneseEbi)
        let questions = Simulation.questions(for: word)
        #expect(questions.map(\.keys) == ["jaj", "jajs"])
        #expect(questions.map(\.textBefore) == ["kore ", "kore "])
        #expect(questions[1].options == [.english, .japaneseEbi, .keep])
    }

    @Test func aConfidentAnswerSwitchesAtTheThirdKey() {
        let word = WordCase(textBefore: "", keys: "jajsd/a", answer: .japaneseEbi)
        let result = Simulation.run(word, rule: .forTests, answers: answering(.japaneseEbi, 0.95, for: word))
        #expect(result.switchedTo == .japaneseEbi)
        #expect(result.keysAtSwitch == 3)
        #expect(result.verdict == .correct)
    }

    @Test func englishAnswersLeaveTheWordAndThatIsRightForEnglish() {
        let word = WordCase(textBefore: "", keys: "watashi", answer: .english)
        let result = Simulation.run(word, rule: .forTests, answers: answering(.english, 0.95, for: word))
        #expect(result.switchedTo == nil)
        #expect(result.verdict == .correct)
        // Each prefix from the third key on is asked: wat, wata, watas, watash, watashi
        #expect(result.questionsAsked == 5)
    }

    @Test func switchingEnglishOrTheWrongLayoutIsWrongAndStayingIsMissed() {
        let english = WordCase(textBefore: "", keys: "watashi", answer: .english)
        #expect(Simulation.run(english, rule: .forTests, answers: answering(.japaneseQwerty, 0.95, for: english)).verdict == .wrongSwitch)
        let ebi = WordCase(textBefore: "", keys: "jaj", answer: .japaneseEbi)
        #expect(Simulation.run(ebi, rule: .forTests, answers: answering(.japaneseQwerty, 0.95, for: ebi)).verdict == .wrongSwitch)
        #expect(Simulation.run(ebi, rule: .forTests, answers: answering(.keep, 0.95, for: ebi)).verdict == .missed)
    }

    @Test func aPauseAtTheEndOfTheWordCanSwitchIt() {
        // 0.6 never switches at once, but the hands rest before the space
        let word = WordCase(textBefore: "", keys: "jaj", answer: .japaneseEbi)
        let result = Simulation.run(word, rule: .forTests, answers: answering(.japaneseEbi, 0.6, for: word))
        #expect(result.switchedTo == .japaneseEbi)
    }
}

@Suite struct WordEvaluationSummaryTests {
    @Test func countsEachKindOfResultAndTheRulesHits() {
        func word(_ keys: String, _ answer: Answer, switchedTo: Answer?, at keysAtSwitch: Int? = nil) -> SimulatedWord {
            SimulatedWord(word: WordCase(textBefore: "", keys: keys, answer: answer), switchedTo: switchedTo, keysAtSwitch: keysAtSwitch, questionsAsked: 2)
        }
        let summary = WordEvaluationSummary(results: [
            word("think", .english, switchedTo: nil),
            word("water", .english, switchedTo: .japaneseQwerty, at: 4),
            word("jajsd/a", .japaneseEbi, switchedTo: .japaneseEbi, at: 3),
            word("watashi", .japaneseQwerty, switchedTo: .japaneseQwerty, at: 5),
            word("jajs", .japaneseEbi, switchedTo: .japaneseQwerty, at: 3),
            word("kore", .japaneseQwerty, switchedTo: nil),
        ], rule: .forTests)
        #expect(summary.englishWords == 2)
        #expect(summary.englishSwitched == 1)
        #expect(summary.japaneseWords == 4)
        #expect(summary.japaneseSwitched == 2)
        #expect(summary.japaneseWrongLayout == 1)
        #expect(summary.japaneseMissed == 1)
        // Correct switches at 3 and 5 keys
        #expect(summary.keysToSwitch == [3, 5])
        #expect(summary.questionsAsked == 12)
        // The rule gets all six: think and water are known, jajs and jajsd/a read only in Ebi
        #expect(summary.ruleCorrect == 6)
    }
}
