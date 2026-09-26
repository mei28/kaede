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

    @Test func keepsAnEnglishWordNextToJapanese() {
        // "and" read in Ebi is "age", but as a known English word it stays as typed
        #expect(planner.plan(Run(typing: "and jajsd/a")) == .convert([
            .verbatim("and "), .romaji("tatoeba"),
        ]))
    }

    @Test func passesAnEmptyRun() {
        #expect(planner.plan(Run()) == .pass)
    }

    @Test func convertsJapaneseTypedInQwerty() {
        #expect(planner.plan(Run(typing: "watashino")) == .convert([.romaji("watashino")]))
    }

    @Test func splitsKnownQwertyEnglishFromEbiJapaneseInOneToken() {
        // "api" typed in QWERTY, then "hamadate" typed with Ebi fingering, no space between
        let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "api\n"))
        #expect(planner.plan(Run(typing: "api;a,amajd")) == .convert([.verbatim("api"), .romaji("hamadate")]))
    }
}
