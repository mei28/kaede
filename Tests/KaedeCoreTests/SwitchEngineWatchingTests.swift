import Testing
@testable import KaedeCore

/// The engine while the Roman source is on: it follows the word being typed and asks about it.
@Suite struct SwitchEngineWatchingTests {
    let t0 = ContinuousClock.now

    @Test func layoutKeysPassAndTheThirdOneAsks() throws {
        let engine = SwitchEngine(rule: .forTests)
        #expect(engine.handle(.typing("j"), source: .roman, at: t0) == (.pass, Reaction()))
        #expect(engine.type("a", at: t0).isEmpty)
        let (action, reaction) = engine.handle(.typing("j"), source: .roman, at: t0)
        #expect(action == .pass)
        let question = try #require(reaction.question)
        #expect(question.keys == "jaj")
        #expect(question.ebiReading == "tat")
        #expect(question.textBefore == "")
        #expect(question.options == [.english, .japaneseQwerty, .japaneseEbi, .keep])
    }

    @Test func aWordNoJapaneseReadingFitsIsNotAskedAbout() {
        #expect(SwitchEngine(rule: .forTests).type("the", at: t0).isEmpty)
    }

    @Test func theSameKeysAreNotAskedTwice() {
        let engine = SwitchEngine(rule: .forTests)
        #expect(engine.type("jaj", at: t0).count == 1)
        _ = engine.handle(.backspace, source: .roman, at: t0)
        #expect(engine.type("j", at: t0).isEmpty)
        #expect(engine.type("s", at: t0).count == 1)
    }

    @Test func atMostFourQuestionsWaitAtOnce() {
        let engine = SwitchEngine(rule: .forTests)
        // jaj jajs jajsd jajsd/ are asked; jajsd/a waits for a free slot
        let asked = engine.type("jajsd/a", at: t0)
        #expect(asked.map(\.keys) == ["jaj", "jajs", "jajsd", "jajsd/"])
        engine.questionFailed(asked[0].id)
        #expect(engine.type("k", at: t0).map(\.keys) == ["jajsd/ak"])
    }

    @Test func theTextBeforeHoldsTheFinishedWordsAndTheirSeparators() {
        let engine = SwitchEngine(rule: .forTests)
        let question = engine.type("kore ha jaj", at: t0).last!
        #expect(question.keys == "jaj")
        #expect(question.textBefore == "kore ha ")
    }

    @Test func theTextBeforeKeepsItsLast240Characters() {
        let engine = SwitchEngine(rule: .forTests)
        let long = String(repeating: "ab ", count: 90)
        let question = engine.type(long + "jaj", at: t0).last!
        #expect(question.textBefore == String(long.suffix(240)))
    }

    @Test func backspaceOnAnEmptyWordTrimsTheTextBefore() {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("kore ", at: t0)
        _ = engine.handle(.backspace, source: .roman, at: t0)
        #expect(engine.type("jaj", at: t0).last?.textBefore == "kore")
    }

    @Test func aLongWordSendsItsLast80Keys() {
        let engine = SwitchEngine(rule: .forTests)
        let word = String(repeating: "ka", count: 42) + "k"
        var last: Question?
        for character in word {
            if let question = engine.handle(.typing(character), source: .roman, at: t0).1.question {
                engine.questionFailed(question.id)
                last = question
            }
        }
        let keys = String(word.suffix(80))
        #expect(last?.keys == keys)
        #expect(last?.ebiReading == Run(typing: keys).reading(in: .ebi))
    }

    @Test func digitsAndTheSymbolLayerEndTheWord() {
        let engine = SwitchEngine(rule: .forTests)
        #expect(engine.type("ja1jaj", at: t0).map(\.textBefore) == ["ja1"])
        let questionMark = RawKey(keyCode: KeyPosition.slash.keyCode, character: "?", shift: true, rightShift: true)
        _ = engine.handle(questionMark, source: .roman, at: t0)
        #expect(engine.type("jaj", at: t0).map(\.textBefore) == ["ja1jaj?"])
    }

    @Test func aHyphenContinuesAWordButStartsNone() {
        let engine = SwitchEngine(rule: .forTests)
        #expect(engine.type("ko-", at: t0).map(\.keys) == ["ko-"])
        #expect(engine.type(" -ko", at: t0).isEmpty)
    }

    @Test func enterEndsTheWordAndClearsTheTextBefore() {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("kore ja", at: t0)
        #expect(engine.handle(.enter, source: .roman, at: t0).0 == .pass)
        #expect(engine.type("jaj", at: t0).map(\.textBefore) == [""])
    }

    @Test(arguments: [RawKey.tab, .escape, .leftArrow, .functionKey, RawKey(keyCode: KeyPosition.c.keyCode, character: "c", command: true)])
    func keysThatMayMoveTheCaretDropTheWordAndTheTextBefore(key: RawKey) {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("kore ja", at: t0)
        #expect(engine.handle(key, source: .roman, at: t0).0 == .pass)
        #expect(engine.type("j", at: t0).isEmpty)
        #expect(engine.type("aj", at: t0).map(\.textBefore) == [""])
    }

    @Test func aMovedCaretDropsTheWordAndTheTextBefore() {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("kore ja", at: t0)
        _ = engine.caretMoved()
        #expect(engine.type("jaj", at: t0).map(\.textBefore) == [""])
    }

    @Test func anotherSourcePassesEverythingAndAsksNothing() {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("kore ja", at: t0)
        for source in [InputSource.azooKey, .other] {
            #expect(engine.handle(.typing("j"), source: source, at: t0) == (.pass, Reaction()))
        }
        // The word and the text before were dropped
        #expect(engine.type("j", at: t0).isEmpty)
        #expect(engine.type("aj", at: t0).map(\.textBefore) == [""])
    }

    @Test func kaedesOwnKeysPassUnrecorded() {
        let engine = SwitchEngine(rule: .forTests)
        engine.type("ja", at: t0)
        var own = RawKey.typing("j")
        own.isKaedeEvent = true
        #expect(engine.handle(own, source: .roman, at: t0) == (.pass, Reaction()))
        #expect(engine.type("j", at: t0).map(\.keys) == ["jaj"])
    }
}
