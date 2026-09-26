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

    @Test func rewritesEnglishTypedWithEbiFingeringToItsEbiReading() {
        // "world" typed with Ebi fingering shows "usiwm" on screen
        let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "world\n"))
        #expect(planner.plan(Run(typing: "usiwm")) == .convert([.verbatim("world")]))
    }

    @Test func keepsATokenNoSegmentationCoversAsTyped() {
        // "/" is neither a letter nor romaji, so nothing reads "a/b"
        #expect(planner.plan(Run(typing: "jajsd/a a/b")) == .convert([.romaji("tatoeba"), .verbatim(" a/b")]))
    }

    @Test(arguments: ["zenzai", "azookey"])
    func keepsRomajiLookingProperNounsAsTyped(typed: String) throws {
        let lexicon = try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists)
        #expect(EnterPlanner(lexicon: lexicon).plan(Run(typing: typed)) == .pass)
    }

    @Test func alternativesStartWithThePlanAndVaryOneTokenAtATime() {
        let run = Run(typing: "jajsd/a watashinoiflsgjdhfkf;a")
        let alternatives = planner.alternatives(for: run, perToken: 3)
        guard case let .convert(best) = planner.plan(run) else {
            Issue.record("expected the run to convert")
            return
        }
        #expect(alternatives.first == best)
        #expect(alternatives.contains([.romaji("tatoeba"), .verbatim(" "), .romaji("watashinoiisoutekiniha")]))
        #expect(Set(alternatives.map { "\($0)" }).count == alternatives.count)
    }

    @Test func handOffKeepsTheTypedTextOfTheLastJapanesePart() {
        let planner = EnterPlanner(lexicon: EnglishLexicon(wordList: "api\nqwerty\n"))
        #expect(planner.handOff(for: Run(typing: "api;a,amajd")) == HandOff(
            typed: "api;a,amajd", settled: [.verbatim("api")], romaji: "hamadate", typedTail: ";a,amajd"
        ))
        #expect(planner.handOff(for: Run(typing: "kf;skknsqwertyjs")) == HandOff(
            typed: "kf;skknsqwertyjs", settled: [.romaji("nihonngo"), .verbatim("qwerty")], romaji: "to", typedTail: "js"
        ))
        // QWERTY "watashino" and Ebi "risoutekiniha" join into the one part handed off
        #expect(planner.handOff(for: Run(typing: "watashinoiflsgjdhfkf;a")) == HandOff(
            typed: "watashinoiflsgjdhfkf;a", settled: [], romaji: "watashinorisoutekiniha", typedTail: "watashinoiflsgjdhfkf;a"
        ))
    }

    @Test func noHandOffWhenTheRunDoesNotEndInJapanese() {
        #expect(planner.handOff(for: Run(typing: "jajsd/athe")) == nil)
        #expect(planner.handOff(for: Run(typing: "the cat")) == nil)
    }

    // MARK: Words the rules cannot settle

    let wordsPlanner = EnterPlanner(lexicon: EnglishLexicon(wordList: "are\nand\nhas\nthe\ncat\n"))

    @Test(arguments: [
        ("are", true),  // English "are", or あれ typed in QWERTY
        ("jajsd/a", false),  // every reading is Japanese
        ("the cat", false),  // no reading is Japanese
    ])
    func aWordIsAmbiguousWhenItsReadingsDisagreeOnLanguage(typed: String, ambiguous: Bool) {
        #expect(wordsPlanner.isAmbiguous(Run(typing: typed)) == ambiguous)
    }

    @Test func englishKeepsAnAmbiguousWordAsTyped() {
        #expect(wordsPlanner.plan(Run(typing: "are"), preferring: .english) == .pass)
        #expect(wordsPlanner.handOff(for: Run(typing: "are"), preferring: .english) == nil)
    }

    @Test(arguments: [
        ("are", "are"),  // QWERTY romaji あれ
        ("has", "kao"),  // Ebi fingering of かお
    ])
    func japaneseReadsAnAmbiguousWordAsRomaji(typed: String, romaji: String) {
        #expect(wordsPlanner.plan(Run(typing: typed), preferring: .japanese) == .convert([.romaji(romaji)]))
        #expect(wordsPlanner.handOff(for: Run(typing: typed), preferring: .japanese) == HandOff(
            typed: typed, settled: [], romaji: romaji, typedTail: typed
        ))
    }

    // MARK: English typed without spaces

    func respacingPlanner() throws -> EnterPlanner {
        EnterPlanner(
            lexicon: try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists),
            commonWords: try EnglishLexicon(contentsOfFiles: bundledWordLists)
        )
    }

    @Test(arguments: [
        ("allyouneedisattention.", "all you need is attention."),
        ("thankyou", "thank you"),
        ("ThankYou", "Thank You"),
    ])
    func putsSpacesIntoEnglishTypedWithoutThem(typed: String, respaced: String) throws {
        let plan = try respacingPlanner().plan(Run(typing: typed))
        #expect(plan == .convert([.verbatim(respaced)]))
    }

    @Test func leavesKnownWordsAndRomajiAlone() throws {
        let planner = try respacingPlanner()
        #expect(planner.plan(Run(typing: "keyboard")) == .pass)
        #expect(planner.plan(Run(typing: "tomodachi")) == .convert([.romaji("tomodachi")]))
    }

    @Test func respacesOnlyWithCommonWordsGiven() throws {
        let planner = EnterPlanner(lexicon: try EnglishLexicon(contentsOfFiles: ["/usr/share/dict/words"] + bundledWordLists))
        #expect(planner.plan(Run(typing: "thankyou")) != .convert([.verbatim("thank you")]))
    }

    // MARK: Questions for Jev

    @Test func asksWhetherToRespaceEnglishTypedWithoutSpaces() throws {
        #expect(try respacingPlanner().question(for: Run(typing: "localhost")) == .spacing(respaced: "local host"))
    }

    @Test(arguments: [
        ("are", "are (English)"),  // an English word that also reads whole as romaji
        ("watashino", "watashino (Japanese romaji)"),  // romaji typed in QWERTY
        ("api;a,amajd", "api (English) + hamadate (Japanese romaji)"),  // English and Japanese in one word
    ])
    func asksTheLanguageWithTheRulesReading(typed: String, reading: String) throws {
        #expect(try respacingPlanner().question(for: Run(typing: typed)) == .language(ruleReading: reading))
    }

    @Test(arguments: ["jajsd/a", "the", "keyboard"])
    func asksNothingAboutClearWords(typed: String) throws {
        // Ebi-fingered Japanese, and known English that does not read as romaji
        #expect(try respacingPlanner().question(for: Run(typing: typed)) == nil)
    }

    // MARK: Following Jev's answers

    @Test(arguments: [
        ("watashino", EnterDecision.pass, EnterDecision.convert([.romaji("watashino")])),
        ("api;a,amajd", EnterDecision.pass, EnterDecision.convert([.verbatim("api"), .romaji("hamadate")])),
    ])
    func englishKeepsADoubtfulWordAsTypedAndJapaneseKeepsTheRulesReading(
        typed: String, english: EnterDecision, japanese: EnterDecision
    ) throws {
        let planner = try respacingPlanner()
        #expect(planner.plan(Run(typing: typed), preferring: .english) == english)
        #expect(planner.plan(Run(typing: typed), preferring: .japanese) == japanese)
    }

    @Test func spacingAnswersDecideWhetherToRespace() throws {
        let planner = try respacingPlanner()
        #expect(planner.plan(Run(typing: "localhost"), spacing: .keepAsTyped) == .pass)
        #expect(planner.plan(Run(typing: "localhost"), spacing: .respace) == .convert([.verbatim("local host")]))
        #expect(planner.plan(Run(typing: "localhost")) == .convert([.verbatim("local host")]))
    }

    @Test func respacesLongEnglishWithAWordStillBeingTyped() throws {
        #expect(try respacingPlanner().plan(Run(typing: "explanationisallyouneedbuttheexpl")) == .convert([
            .verbatim("explanation is all you need but the expl"),
        ]))
    }

    @Test func anEnglishAnswerRespacesWhatSplits() throws {
        // "behere" reads as romaji, so the rules read it as Japanese; English means "be here"
        let planner = try respacingPlanner()
        #expect(planner.plan(Run(typing: "behere")) == .convert([.romaji("behere")]))
        #expect(planner.plan(Run(typing: "behere"), preferring: .english) == .convert([.verbatim("be here")]))
        // Romaji splits into junk ("to mod a chi"), so English keeps it as typed
        #expect(planner.plan(Run(typing: "tomodachi"), preferring: .english) == .pass)
    }
}
