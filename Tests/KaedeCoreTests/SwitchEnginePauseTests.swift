import Testing
@testable import KaedeCore

/// ctrl+alt+p stops Kaede from sending anything, for a password in a terminal, say.
@Suite struct SwitchEnginePauseTests {
    let t0 = ContinuousClock.now
    let pauseKey = RawKey(keyCode: KeyPosition.p.keyCode, character: "π", control: true, option: true)

    @Test func thePauseKeyIsSwallowedAndNothingIsAskedAfterIt() {
        let engine = SwitchEngine()
        #expect(engine.handle(pauseKey, source: .roman, at: t0) == (.suppress, Reaction(paused: true)))
        #expect(engine.handle(.typing("j"), source: .roman, at: t0) == (.pass, Reaction()))
        #expect(engine.type("ajsd/a", at: t0).isEmpty)
    }

    @Test func keysTypedWhilePausedStayOutOfTheTextBefore() {
        let engine = SwitchEngine()
        engine.type("kore ", at: t0)
        _ = engine.handle(pauseKey, source: .roman, at: t0)
        engine.type("secret", at: t0)
        // Pressed again it resumes, without a sound
        #expect(engine.handle(pauseKey, source: .roman, at: t0) == (.suppress, Reaction()))
        #expect(engine.type("jaj", at: t0).map(\.textBefore) == ["kore "])
    }

    @Test func enterResumes() {
        let engine = SwitchEngine()
        _ = engine.handle(pauseKey, source: .roman, at: t0)
        engine.type("secret", at: t0)
        #expect(engine.handle(.enter, source: .roman, at: t0).0 == .pass)
        #expect(engine.type("jaj", at: t0).map(\.textBefore) == [""])
    }

    @Test func aMovedCaretResumes() {
        let engine = SwitchEngine()
        _ = engine.handle(pauseKey, source: .roman, at: t0)
        _ = engine.caretMoved()
        #expect(engine.type("jaj", at: t0).count == 1)
    }

    @Test func pausingDropsTheWordAndItsAnswers() {
        let engine = SwitchEngine()
        let question = engine.type("jaj", at: t0)[0]
        _ = engine.handle(pauseKey, source: .roman, at: t0)
        _ = engine.handle(pauseKey, source: .roman, at: t0)
        #expect(engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: question.id, at: t0) == Reaction())
    }

    @Test func thePauseKeyWorksInKaedesAzooKeyToo() {
        let engine = SwitchEngine()
        let question = engine.type("jaj", at: t0)[0]
        _ = engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: question.id, at: t0)
        _ = engine.switchSucceeded()
        #expect(engine.handle(pauseKey, source: .azooKey, at: t0) == (.suppress, Reaction(paused: true)))
        // Back in English, it stays paused
        #expect(engine.type("jaj", at: t0).isEmpty)
    }
}
