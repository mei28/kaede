import Testing
@testable import KaedeCore

/// The engine deciding from Jev's answers when to switch the word to azooKey.
@Suite struct SwitchEngineDecisionTests {
    let t0 = ContinuousClock.now

    private func ms(_ milliseconds: Int) -> ContinuousClock.Instant {
        t0 + .milliseconds(milliseconds)
    }

    private func judgment(_ answer: Answer, _ confidence: Double) -> Judgment {
        Judgment(answer: answer, confidence: confidence)
    }

    @Test func aConfidentAnswerSwitchesTheWordAsReadInItsLayout() {
        let engine = SwitchEngine()
        let question = engine.type("jaj", at: t0)[0]
        let reaction = engine.receive(judgment(.japaneseEbi, 0.95), to: question.id, at: ms(100))
        #expect(reaction.switchOrder == SwitchOrder(answer: .japaneseEbi, deleteCount: 3, romaji: "tat"))
    }

    @Test func anAnswerAfterTheWordEndedIsDropped() {
        let engine = SwitchEngine()
        let question = engine.type("jaj ", at: t0)[0]
        #expect(engine.receive(judgment(.japaneseEbi, 0.95), to: question.id, at: ms(100)) == Reaction())
    }

    @Test func anAnswerAboutKeysNoLongerTypedIsDropped() {
        let engine = SwitchEngine()
        let question = engine.type("jaj", at: t0)[0]
        _ = engine.handle(.backspace, source: .roman, at: t0)
        engine.type("k", at: t0)
        #expect(engine.receive(judgment(.japaneseEbi, 0.95), to: question.id, at: ms(100)) == Reaction())
    }

    @Test func aLateAnswerAboutTheWordsStartIsUsed() {
        let engine = SwitchEngine()
        let questions = engine.type("jajs", at: t0)
        let reaction = engine.receive(judgment(.japaneseEbi, 0.95), to: questions[0].id, at: ms(100))
        #expect(reaction.switchOrder == SwitchOrder(answer: .japaneseEbi, deleteCount: 4, romaji: "tato"))
    }

    @Test func aLayoutTheWholeWordNoLongerReadsInDoesNotSwitch() {
        let engine = SwitchEngine()
        let questions = engine.type("jajs", at: t0)
        // jajs cannot become romaji in QWERTY any more
        #expect(engine.receive(judgment(.japaneseQwerty, 0.95), to: questions[0].id, at: ms(100)) == Reaction())
    }

    @Test func aPauseOnTheLatestAnswerSwitchesAtTheDeadline() {
        let engine = SwitchEngine()
        let question = engine.type("jaj", at: t0)[0]
        #expect(engine.deadline == nil)
        #expect(engine.receive(judgment(.japaneseEbi, 0.6), to: question.id, at: ms(100)) == Reaction())
        #expect(engine.deadline == ms(350))
        #expect(engine.tick(at: ms(349)) == Reaction())
        #expect(engine.tick(at: ms(350)).switchOrder?.romaji == "tat")
    }

    @Test func anOpposingAnswerPutsTheDeadlineFurtherAway() {
        let engine = SwitchEngine()
        let questions = engine.type("jaja", at: t0)
        _ = engine.receive(judgment(.english, 0.6), to: questions[0].id, at: ms(100))
        _ = engine.receive(judgment(.japaneseEbi, 0.95), to: questions[1].id, at: ms(100))
        #expect(engine.deadline == ms(700))
    }

    @Test func aKeyAfterTheAnswerWaitsForAnAnswerAboutTheWholeWord() {
        let engine = SwitchEngine()
        let question = engine.type("jaj", at: t0)[0]
        _ = engine.receive(judgment(.japaneseEbi, 0.6), to: question.id, at: ms(100))
        let next = engine.type("a", at: ms(200))[0]
        #expect(engine.deadline == nil)
        _ = engine.receive(judgment(.japaneseEbi, 0.6), to: next.id, at: ms(300))
        #expect(engine.deadline == ms(550))
    }

    @Test func nothingMoreIsDecidedOnceTheWordIsSwitching() {
        let engine = SwitchEngine()
        let questions = engine.type("jaja", at: t0)
        #expect(engine.receive(judgment(.japaneseEbi, 0.95), to: questions[0].id, at: ms(100)).switchOrder != nil)
        #expect(engine.receive(judgment(.japaneseEbi, 0.95), to: questions[1].id, at: ms(100)) == Reaction())
        #expect(engine.deadline == nil)
        #expect(engine.tick(at: ms(2000)) == Reaction())
    }

    @Test func anAnswerFreesItsSlot() {
        let engine = SwitchEngine()
        let asked = engine.type("jajsd/a", at: t0)
        #expect(asked.count == 4)
        _ = engine.receive(judgment(.keep, 0.9), to: asked[0].id, at: ms(100))
        #expect(engine.type("k", at: ms(200)).map(\.keys) == ["jajsd/ak"])
    }
}
