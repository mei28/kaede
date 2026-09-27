import Testing
@testable import KaedeCore

/// Enter in the azooKey Kaede switched to commits the Japanese, then Kaede selects English again.
@Suite struct SwitchEngineSwitchBackTests {
    let t0 = ContinuousClock.now

    /// An engine whose word "jaj" (Ebi: tat) went to azooKey.
    private func remappingEngine() -> SwitchEngine {
        let engine = SwitchEngine(rule: .forTests)
        let question = engine.type("jaj", at: t0)[0]
        _ = engine.receive(Judgment(answer: .japaneseEbi, confidence: 0.95), to: question.id, at: t0)
        _ = engine.switchSucceeded()
        return engine
    }

    @Test func enterPassesToAzooKeyAndSwitchesBack() {
        let engine = remappingEngine()
        #expect(engine.handle(.enter, source: .azooKey, at: t0) == (.pass, Reaction(switchBack: true)))
    }

    @Test func keysUntilEnglishIsBackWaitAndThenStartAFreshLine() {
        let engine = remappingEngine()
        _ = engine.handle(.enter, source: .azooKey, at: t0)
        #expect(engine.handle(.typing("k"), source: .azooKey, at: t0) == (.suppress, Reaction()))
        #expect(engine.switchedBack() == [.typing("k")])
        // Enter ended the line, so nothing typed before it is context any more
        #expect(engine.type("jaj", at: t0).map(\.textBefore) == [""])
    }

    @Test func aFailedSwitchBackKeepsRemapping() {
        let engine = remappingEngine()
        _ = engine.handle(.enter, source: .azooKey, at: t0)
        _ = engine.handle(.typing("j"), source: .azooKey, at: t0)
        #expect(engine.switchBackFailed() == [.typing("j")])
        #expect(engine.handle(.typing("j"), source: .azooKey, at: t0).0 == .remap(keyCode: KeyPosition.t.keyCode))
    }

    @Test func enterInAzooKeySelectedByHandDoesNotSwitchBack() {
        let engine = SwitchEngine(rule: .forTests)
        #expect(engine.handle(.enter, source: .azooKey, at: t0) == (.pass, Reaction()))
    }
}
