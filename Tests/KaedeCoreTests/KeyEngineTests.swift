import Testing
@testable import KaedeCore

@Suite struct KeyEngineTests {
    let engine = KeyEngine(planner: EnterPlanner(lexicon: EnglishLexicon(wordList: "and\nthe\ncat\n")))

    @Test func recordsALayoutKeyAsAStrokeAndPassesIt() {
        #expect(engine.handle(RawKey(keyCode: 0x00, character: "a")) == .pass)
        #expect(engine.handle(RawKey(keyCode: 0x26, character: "J", shift: true)) == .pass)
        #expect(engine.run.elements == [.stroke(.a, shift: false), .stroke(.j, shift: true)])
    }

    @Test func recordsDigitsAndOtherPrintableKeysAsLiterals() {
        #expect(engine.handle(RawKey(keyCode: 0x12, character: "1")) == .pass)
        #expect(engine.handle(RawKey(keyCode: 27, character: "-")) == .pass)
        #expect(engine.run.elements == [.literal("1"), .literal("-")])
    }

    @Test func recordsRightShiftOnTheFourSymbolKeysAsSymbolLiterals() {
        // The custom keyboard's symbol layer sends ? : < > with right Shift
        _ = engine.handle(RawKey(keyCode: 0x29, character: ":", shift: true, rightShift: true))
        _ = engine.handle(RawKey(keyCode: 0x2c, character: "?", shift: true, rightShift: true))
        #expect(engine.run.elements == [.literal(":"), .literal("?")])
    }

    @Test func keepsRightShiftOnALetterKeyAsAStroke() {
        _ = engine.handle(RawKey(keyCode: 0x00, character: "A", shift: true, rightShift: true))
        #expect(engine.run.elements == [.stroke(.a, shift: true)])
    }

    @Test func backspaceRemovesTheLastElementAndPasses() {
        _ = engine.handle(RawKey(keyCode: 0x00, character: "a"))
        _ = engine.handle(RawKey(keyCode: 0x01, character: "s"))
        #expect(engine.handle(RawKey(keyCode: 51, character: "\u{8}")) == .pass)
        #expect(engine.run.elements == [.stroke(.a, shift: false)])
    }

    @Test(arguments: [123, 124, 125, 126, 48, 53] as [UInt16])
    func arrowsTabAndEscapeResetTheRunAndPass(keyCode: UInt16) {
        _ = engine.handle(RawKey(keyCode: 0x00, character: "a"))
        #expect(engine.handle(RawKey(keyCode: keyCode, character: nil)) == .pass)
        #expect(engine.run.elements.isEmpty)
    }

    @Test(arguments: [
        RawKey(keyCode: 0x08, character: "c", command: true),
        RawKey(keyCode: 0x00, character: "a", control: true),
        RawKey(keyCode: 0x01, character: "ß", option: true),
    ])
    func commandControlAndOptionCombinationsResetTheRunAndPass(key: RawKey) {
        _ = engine.handle(RawKey(keyCode: 0x00, character: "a"))
        #expect(engine.handle(key) == .pass)
        #expect(engine.run.elements.isEmpty)
    }

    @Test(arguments: [
        RawKey(keyCode: 96, character: "\u{F708}"),  // F5 carries a private-use character
        RawKey(keyCode: 117, character: "\u{7F}"),  // forward delete
        RawKey(keyCode: 115, character: nil),  // Home
    ])
    func keysWithoutAPrintableCharacterResetTheRunAndPass(key: RawKey) {
        _ = engine.handle(RawKey(keyCode: 0x00, character: "a"))
        #expect(engine.handle(key) == .pass)
        #expect(engine.run.elements.isEmpty)
    }

    @Test func discardRunEmptiesTheRunForClicksAndAppSwitches() {
        _ = engine.handle(RawKey(keyCode: 0x00, character: "a"))
        engine.discardRun()
        #expect(engine.run.elements.isEmpty)
    }

    @Test func enterThatThePlannerPassesGoesThroughAndResetsTheRun() {
        engine.type("the cat")
        #expect(engine.handle(.enter) == .pass)
        #expect(engine.run.elements.isEmpty)
    }

    @Test func enterThatConvertsIsSuppressedAndYieldsAReplacement() {
        engine.type("jajsd/ahskkkahakk.fmd")
        #expect(engine.handle(.enter) == .replace(Replacement(
            typed: "jajsd/ahskkkahakk.fmd",
            pieces: [.romaji("tatoebakonnnakannjide")]
        )))
    }

    @Test(arguments: [
        RawKey(keyCode: 36, character: "\r", command: true),
        RawKey(keyCode: 36, character: "\r", shift: true),
        RawKey(keyCode: 76, character: "\u{3}"),  // keypad Enter
    ])
    func everyEnterConverts(enter: RawKey) {
        engine.type("jajsd/a")
        #expect(engine.handle(enter) == .replace(Replacement(typed: "jajsd/a", pieces: [.romaji("tatoeba")])))
    }

    @Test func holdsKeysDuringAReplacementAndReturnsThemInOrder() {
        engine.type("jajsd/a")
        _ = engine.handle(.enter)
        let typedDuring = RawKey(keyCode: 0x00, character: "a")
        #expect(engine.handle(typedDuring) == .suppress)
        #expect(engine.handle(.enter) == .suppress)
        #expect(engine.finishReplacement(candidates: []) == [typedDuring, .enter])
    }

    @Test func handlesKeysNormallyAfterTheReplacementFinishes() {
        engine.type("jajsd/a")
        _ = engine.handle(.enter)
        _ = engine.finishReplacement(candidates: [])
        #expect(engine.run.elements.isEmpty)
        #expect(engine.handle(RawKey(keyCode: 0x00, character: "a")) == .pass)
        #expect(engine.run.elements == [.stroke(.a, shift: false)])
    }

    @Test func passesKaedesOwnEventsWithoutRecordingOrHoldingThem() {
        let own = RawKey(keyCode: 0x00, character: "a", isKaedeEvent: true)
        #expect(engine.handle(own) == .pass)
        #expect(engine.run.elements.isEmpty)

        engine.type("jajsd/a")
        _ = engine.handle(.enter)
        #expect(engine.handle(own) == .pass)
        #expect(engine.finishReplacement(candidates: []).isEmpty)
    }

    @Test func spaceAfterAConvertingWordReplacesItAndTypesTheSpaceAfterIt() {
        engine.type("jajsd/a")
        let space = RawKey(keyCode: 49, character: " ")
        // Typed with the replacement rather than replayed: a replayed space would pick the next candidate
        #expect(engine.handle(space) == .replace(Replacement(typed: "jajsd/a", pieces: [.romaji("tatoeba")], suffix: " ")))
        #expect(engine.finishReplacement(candidates: ["例えば"]).isEmpty)
    }

    @Test func spaceAfterAPassingWordPassesAndStartsANewRun() {
        engine.type("the")
        #expect(engine.handle(RawKey(keyCode: 49, character: " ")) == .pass)
        #expect(engine.run.elements.isEmpty)
        engine.type("jajsd/a")
        #expect(engine.handle(.enter) == .replace(Replacement(typed: "jajsd/a", pieces: [.romaji("tatoeba")])))
    }

    @Test func spaceWithAModifierDiscardsTheRun() {
        engine.type("jajsd/a")
        #expect(engine.handle(RawKey(keyCode: 49, character: " ", control: true)) == .pass)
        #expect(engine.run.elements.isEmpty)
    }

    // MARK: Correcting the last conversion

    let space = RawKey(keyCode: 49, character: " ")
    let shiftSpace = RawKey(keyCode: 49, character: " ", shift: true)

    /// Converts "jajsd/a" with a space and offers the candidates, leaving "例えば " on screen.
    func convertTatoeba(candidates: [String] = ["例えば", "たとえば", "喩えば"]) {
        engine.type("jajsd/a")
        _ = engine.handle(space)
        _ = engine.finishReplacement(candidates: candidates)
    }

    @Test func spaceStepsToTheNextCandidateAndShiftSpaceBackWrappingAround() {
        convertTatoeba()
        #expect(engine.handle(space) == .rewrite(deleteCount: 4, text: "たとえば "))
        #expect(engine.finishRewrite().isEmpty)
        #expect(engine.handle(space) == .rewrite(deleteCount: 5, text: "喩えば "))
        _ = engine.finishRewrite()
        #expect(engine.handle(space) == .rewrite(deleteCount: 4, text: "例えば "))
        _ = engine.finishRewrite()
        #expect(engine.handle(shiftSpace) == .rewrite(deleteCount: 4, text: "喩えば "))
    }

    @Test func escapeRestoresTheTypedTextAndEndsCorrecting() {
        convertTatoeba()
        _ = engine.handle(space)
        _ = engine.finishRewrite()
        // "たとえば " is on screen
        #expect(engine.handle(RawKey(keyCode: 53, character: "\u{1B}")) == .rewrite(deleteCount: 5, text: "jajsd/a "))
        _ = engine.finishRewrite()
        #expect(engine.handle(space) == .pass)
    }

    @Test func anotherKeySettlesTheConversionAndIsHandledAsUsual() {
        convertTatoeba()
        #expect(engine.handle(RawKey(keyCode: 0x00, character: "a")) == .pass)
        #expect(engine.run.elements == [.stroke(.a, shift: false)])
        #expect(engine.handle(space) == .pass)  // "a" is one stroke: nothing to convert, nothing to step through
    }

    @Test func enterSettlesTheConversionAndPasses() {
        convertTatoeba()
        #expect(engine.handle(.enter) == .pass)
        #expect(engine.handle(space) == .pass)
    }

    @Test func aClickOrAppSwitchSettlesTheConversion() {
        convertTatoeba()
        engine.discardRun()
        #expect(engine.handle(space) == .pass)
    }

    @Test func aFailedConversionOffersNothingToStepThrough() {
        convertTatoeba(candidates: [])
        #expect(engine.handle(space) == .pass)
    }

    @Test func keysPressedDuringARewriteAreHeldAndReturned() {
        convertTatoeba()
        _ = engine.handle(space)
        let typedDuring = RawKey(keyCode: 0x00, character: "a")
        #expect(engine.handle(typedDuring) == .suppress)
        #expect(engine.finishRewrite() == [typedDuring])
    }

    @Test func aConversionByEnterCanBeSteppedThroughWithoutASuffix() {
        engine.type("jajsd/a")
        _ = engine.handle(.enter)
        _ = engine.finishReplacement(candidates: ["例えば", "たとえば"])
        #expect(engine.handle(space) == .rewrite(deleteCount: 3, text: "たとえば"))
    }
}
