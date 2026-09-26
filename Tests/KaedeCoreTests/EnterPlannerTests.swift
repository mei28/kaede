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

    @Test func keepsAnUnknownWordAsTyped() {
        // Neither romaji nor a known word: leaving it as typed is the safe reading
        #expect(planner.plan(Run(typing: "jajsd/a qqq")) == .convert([.romaji("tatoeba"), .verbatim(" qqq")]))
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

    @Test func keepsADigitAfterJapaneseAsTyped() {
        #expect(planner.plan(Run(typing: "jajsd/a2")) == .convert([.romaji("tatoeba"), .verbatim("2")]))
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

    @Test func keepsCapitalizedEnglishAsTyped() {
        let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "qwerty\nebi\n"))
        #expect(planner.plan(Run(typing: "QWERTY ;afidjgjs Ebi")) == .convert([
            .verbatim("QWERTY "), .romaji("hairetuto"), .verbatim(" Ebi"),
        ]))
    }

    @Test func mergesAdjacentJapaneseSegmentsAcrossLayouts() {
        // "gamazattarieigoto" typed in QWERTY, then "nihonngo" typed with Ebi fingering
        #expect(planner.plan(Run(typing: "gamazattarieigotokf;skkns")) == .convert([
            .romaji("gamazattarieigotonihonngo"),
        ]))
    }

    @Test(arguments: [
        // QWERTY "watashino" + Ebi "risoutekiniha", not "watashinoi" + "isoutekiniha"
        ("watashinoiflsgjdhfkf;a", "watashinorisoutekiniha"),
        // Ebi "hennkann" + QWERTY "sairerukotodesu", not "hennkannoa" + "irerukotodesu"
        (";dkkhakksairerukotodesu", "hennkannsairerukotodesu"),
    ])
    func resolvesTiesInTheExampleSentence(typed: String, romaji: String) {
        #expect(planner.plan(Run(typing: typed)) == .convert([.romaji(romaji)]))
    }

    @Test func keepsALoneNAsHatsuonWhenTheNextSegmentStartsWithN() {
        // QWERTY "hon" + Ebi "nihon": joined as "honnihon" the IME would read ほんいほん
        #expect(planner.plan(Run(typing: "honkf;sk")) == .convert([.romaji("honnnihon")]))
    }

    @Test func literalsSeparateTokensAndStayAsTyped() {
        let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "ebi\nsand\nlayout\n"))
        #expect(planner.plan(Run(typing: "jajsd/a Ebi-sand layout")) == .convert([
            .romaji("tatoeba"), .verbatim(" Ebi-sand layout"),
        ]))
    }

    @Test func keepsPunctuationAfterAnEnglishWordAsTyped() {
        let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "the\ncat\nis\nhere\nyes\n"))
        #expect(planner.plan(Run(typing: "yes, the cat is here.")) == .pass)
    }

    @Test(arguments: ["has", "are", "the cat is here", "it has a name"])
    func passesOrdinaryEnglishWithTheRealWordLists(typed: String) throws {
        let lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists)
        #expect(EnterPlanner(lexicon: lexicon).plan(Run(typing: typed)) == .pass)
    }
}
