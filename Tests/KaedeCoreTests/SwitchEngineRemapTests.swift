import Testing
@testable import KaedeCore

/// The engine while it switches a word to azooKey and afterwards, while azooKey takes the keys.
@Suite struct SwitchEngineRemapTests {
    let t0 = ContinuousClock.now

    /// An engine that just decided to switch "jaj" (Ebi: tat) to azooKey.
    private func switchingEngine() -> SwitchEngine {
        let engine = SwitchEngine(rule: .forTests)
        let question = engine.type("jaj", at: t0)[0]
        let reaction = engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: question.id, at: t0)
        precondition(reaction.switchOrder != nil)
        return engine
    }

    @Test func keysDuringTheSwitchAreHeldAndReturnedInOrder() {
        let engine = switchingEngine()
        #expect(engine.handle(.typing("a"), source: .roman, at: t0) == (.suppress, Reaction()))
        #expect(engine.handle(.typing("j"), source: .azooKey, at: t0) == (.suppress, Reaction()))
        // Kaede's own Backspaces and romaji go through
        var own = RawKey.backspace
        own.isKaedeEvent = true
        #expect(engine.handle(own, source: .azooKey, at: t0) == (.pass, Reaction()))
        #expect(engine.switchSucceeded() == [.typing("a"), .typing("j")])
    }

    @Test func afterTheSwitchKeysAreReadInTheWordsLayout() {
        let engine = switchingEngine()
        _ = engine.switchSucceeded()
        #expect(engine.handle(.typing("j"), source: .azooKey, at: t0) == (.remap(keyCode: KeyPosition.t.keyCode), Reaction()))
        // Ebi keeps a in place, and shortcuts are not remapped
        #expect(engine.handle(.typing("a"), source: .azooKey, at: t0) == (.pass, Reaction()))
        let copy = RawKey(keyCode: KeyPosition.c.keyCode, character: "c", command: true)
        #expect(engine.handle(copy, source: .azooKey, at: t0) == (.pass, Reaction()))
    }

    @Test func aFailedSwitchReturnsTheKeysAndLeavesTheWordAsTyped() {
        let engine = switchingEngine()
        _ = engine.handle(.typing("a"), source: .roman, at: t0)
        #expect(engine.switchFailed() == [.typing("a")])
        #expect(engine.type(" kor", at: t0).map(\.textBefore) == ["jaj "])
    }

    @Test func aKeyWithTheRomanSourceEndsTheRemappingAndStartsAWord() {
        let engine = switchingEngine()
        _ = engine.switchSucceeded()
        #expect(engine.handle(.typing("j"), source: .roman, at: t0) == (.pass, Reaction()))
        #expect(engine.type("aj", at: t0).map(\.keys) == ["jaj"])
    }

    @Test func aSwitchByAnyoneElseEndsTheRemapping() {
        let engine = switchingEngine()
        // Kaede's own switch to azooKey, even when it is reported before the switch is done
        engine.inputSourceChanged()
        _ = engine.switchSucceeded()
        #expect(engine.handle(.typing("j"), source: .azooKey, at: t0).0 == .remap(keyCode: KeyPosition.t.keyCode))
        // Left cmd then right cmd: azooKey again, now with Hammerspoon's own remapping
        engine.inputSourceChanged()
        engine.inputSourceChanged()
        #expect(engine.handle(.typing("j"), source: .azooKey, at: t0) == (.pass, Reaction()))
    }

    @Test func answersDuringAndAfterTheSwitchAreDroppedButFreeTheirSlots() {
        let engine = SwitchEngine(rule: .forTests)
        let asked = engine.type("jajsd/", at: t0)
        #expect(asked.count == 4)
        #expect(engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: asked[0].id, at: t0).switchOrder != nil)
        #expect(engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: asked[1].id, at: t0) == Reaction())
        _ = engine.switchSucceeded()
        #expect(engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: asked[2].id, at: t0) == Reaction())
        engine.questionFailed(asked[3].id)
        // Back in English, all four slots are free
        _ = engine.handle(.typing("k"), source: .roman, at: t0)
        #expect(engine.type("orekarahajimaru", at: t0).count == 4)
    }

    @Test func textTypedInAzooKeyJoinsTheTextBefore() {
        let engine = switchingEngine()
        _ = engine.switchSucceeded()
        for character in "sd/a" {
            _ = engine.handle(.typing(character), source: .azooKey, at: t0)
        }
        _ = engine.handle(.typing(" "), source: .roman, at: t0)
        #expect(engine.type("kor", at: t0).map(\.textBefore) == ["tatoeba "])
    }
}
