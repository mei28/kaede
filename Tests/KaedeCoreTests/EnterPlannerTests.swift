import Testing
@testable import KaedeCore

@Suite struct EnterPlannerTests {
    let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "and\nthe\ncat\n"))

    @Test func convertsTatoeba() {
        #expect(planner.plan(Run(typing: "jajsd/a")) == .convert([.romaji("tatoeba")]))
    }

    @Test func passesAnEnglishWordEvenThoughItsEbiReadingIsRomaji() {
        // "and" read in Ebi is "age"
        #expect(planner.plan(Run(typing: "and")) == .pass)
    }

    @Test func passesTwoStrokesOrFewerEvenWhenReadable() {
        // "kf" read in Ebi is "ni"
        #expect(planner.plan(Run(typing: "kf")) == .pass)
    }

    @Test func passesWhenAnyChunkIsNotRomaji() {
        #expect(planner.plan(Run(typing: "jajsd/a qqq")) == .pass)
    }

    @Test func splitsChunksOnSpacesAndKeepsTheSpacesAsTyped() {
        #expect(planner.plan(Run(typing: " jajsd/a  hskkkahakk.fmd ")) == .convert([
            .verbatim(" "),
            .romaji("tatoeba"),
            .verbatim("  "),
            .romaji("konnnakannjide"),
            .verbatim(" "),
        ]))
    }

    @Test func passesEnglishWords() {
        #expect(planner.plan(Run(typing: "the cat")) == .pass)
    }

    @Test func passesWhenADigitSitsInsideAChunk() {
        #expect(planner.plan(Run(typing: "jajsd/a2")) == .pass)
    }

    @Test func convertsEveryChunkUnlessTheWholeRunIsEnglish() {
        // The lexicon rule looks at the whole run, so "and" next to Japanese is read in Ebi too
        #expect(planner.plan(Run(typing: "and jajsd/a")) == .convert([
            .romaji("age"), .verbatim(" "), .romaji("tatoeba"),
        ]))
    }

    @Test func passesAnEmptyRun() {
        #expect(planner.plan(Run()) == .pass)
    }

    @Test func convertsJapaneseTypedInQwerty() {
        #expect(planner.plan(Run(typing: "watashino")) == .convert([.romaji("watashino")]))
    }
}
