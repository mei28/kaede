import Testing
@testable import KaedeCore

/// Each finished word reports what the dictionary rule would have said next to what Jev settled.
@Suite struct SwitchEngineOutcomeTests {
    let t0 = ContinuousClock.now

    private func outcomes(typing text: String, _ engine: SwitchEngine) -> [WordOutcome] {
        text.compactMap { engine.handle(.typing($0), source: .roman, at: t0).1.finishedWord }
    }

    @Test func aWordThatEndsInEnglishReportsEnglishForJev() {
        let engine = SwitchEngine(rule: .forTests)
        #expect(outcomes(typing: "the watashi ab ", engine) == [
            WordOutcome(rule: .english, jev: .english),
            WordOutcome(rule: .japaneseQwerty, jev: .english),
        ])
    }

    @Test func aSwitchedWordReportsTheAnswerItSwitchedOn() {
        let engine = SwitchEngine(rule: .forTests)
        let question = engine.type("jaj", at: t0)[0]
        let reaction = engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: question.id, at: t0)
        // The rule reads jaj as the start of QWERTY romaji
        #expect(reaction.finishedWord == WordOutcome(rule: .japaneseQwerty, jev: .japaneseEbi))
        #expect(!reaction.finishedWord!.agrees)
    }

    @Test func aFailedSwitchDoesNotReportTheWordAgain() {
        let engine = SwitchEngine(rule: .forTests)
        let question = engine.type("jaj", at: t0)[0]
        _ = engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: question.id, at: t0)
        _ = engine.switchFailed()
        #expect(outcomes(typing: " ", engine).isEmpty)
    }

    @Test func aDroppedWordReportsToo() {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("think", at: t0)
        #expect(engine.caretMoved().finishedWord == WordOutcome(rule: .english, jev: .english))
    }
}
