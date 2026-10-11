import Testing
@testable import KaedeCore

/// The bundled word lists, so the layout's readings meet the English they really compete with.
private let segmenter = LineSegmenter(lexicon: try! EnglishLexicon(contentsOfFiles: bundledWordLists))

private func notation(_ typed: String, _ layout: KeyboardLayout = .ebi) -> String {
    SegmentNotation.notation(of: segmenter.segments(of: typed[...], layout: layout))
}

@Suite struct LayoutReadingTests {
    @Test(arguments: [
        ("jajsd/a", "ja(L:tatoeba)"),
        (";sk", "ja(L:hon)"),
        (",amd", "ja(L:made)"),
        // はいあ read in QWERTY takes more syllables than から
        ("haia", "ja(L:kara)"),
        // A hyphen after a syllable reads ー in the layout too
        ("ia-,dk", "ja(L:ra-men)"),
    ])
    func readsJapaneseTypedWithTheLayoutsFingering(typed: String, expected: String) {
        #expect(notation(typed) == expected)
    }

    @Test(arguments: [
        // Both read as romaji in the same number of syllables: QWERTY wins
        ("kaisha", "ja(kaisha)"),
        ("mada", "ja(mada)"),
    ])
    func prefersQwertyWhenBothReadAlike(typed: String, expected: String) {
        #expect(notation(typed) == expected)
    }

    @Test(arguments: [
        "kyouhagoogledekensaku", "pythonnobug", "python no bug", "sikasinoatoallyouneedislove", "thisisapen.",
        "watashinonamaeha", "kinouno are", "I want to go to the park", "how to use", "kubernetes", "grokga", "ra-men",
        "githubnipushshita", "kyouhaclaudetohanashita", "I checked the build log and the tests pass", "main.swift",
        "src/kaede", "kore,sore.", "desu.kyouha", "x64,arm64",
    ])
    func readsQwertyTypingAsWithoutTheLayout(typed: String) {
        #expect(notation(typed, .ebi) == notation(typed, .qwerty))
    }
}

@Suite struct LayoutSwitchTests {
    @Test func followsJapaneseThatChangesFingeringMidRun() {
        // The user's own line: QWERTY watashino, then Ebi risoutekinihakonnnakannjide
        #expect(notation("watashinoiflsgjdhfkf;ahskkkahakk.fmd") == "ja(watashino + L:risoutekinihakonnnakannjide)")
    }

    @Test func changesFingeringOnlyBetweenLongEnoughStretches() {
        // kaisha read whole in QWERTY, not ka in QWERTY then isha read some other way
        #expect(notation("kaisha") == "ja(kaisha)")
    }
}

@Suite struct LayoutBesideEnglishTests {
    @Test(arguments: [
        // A particle or verb ending typed with the layout right after English
        ("pythonksbug", "en(python) ja(L:no) en(bug)"),
        ("githubkfpushlfja", "en(github) ja(L:ni) en(push) ja(L:sita)"),
        ("waysks;dkhakmdlg", "en(ways) ja(L:nohenkandesu)"),
        ("spamdake", "en(spam) ja(dake)"),
    ])
    func readsQwertyEnglishBesideLayoutRomaji(typed: String, expected: String) {
        #expect(notation(typed) == expected)
    }

    @Test(arguments: [
        // Short stretches the layout happens to read as romaji do not cut English apart
        ("postgres", "en(postgres)"),
        ("json", "en(json)"),
        ("kaggle", "en(kaggle)"),
        ("naiinterface", "ja(nai) en(interface)"),
    ])
    func keepsEnglishWhole(typed: String, expected: String) {
        #expect(notation(typed) == expected)
    }
}

@Suite struct LayoutPunctuationTests {
    @Test(arguments: [
        // Ebi puts 、 and 。 on QWERTY e and r, and ? on Shift+B
        ("hsidelsid", "ja(L:kore) 、 ja(L:sore)"),
        ("mdlghaB", "ja(L:desuka) ？"),
        ("api;a,amajdfhosglfjdfkafmdlgnamsgoajjdja,dlfjdfigksmdlosghar msg.fhhsgusjs,did/affksmdlosgha",
         "en(api) ja(L:hamadateikyousiteinaidesugadouyattetamesiteirunodesyouka) 。 ja(L:doujikkouwotomerebaiinodesyouka)"),
    ])
    func readsTheLayoutsPunctuationAfterItsRomaji(typed: String, expected: String) {
        #expect(notation(typed) == expected)
    }

    @Test func keepsEnglishThatOnlyTheLayoutsPunctuationWouldMakeJapanese() {
        // Ebi reads far as いあ。
        #expect(notation("far") == "en(far)")
    }
}

@Suite struct CrossReadingTests {
    @Test(arguments: [
        // has reads かお in Ebi: alone, it stays English, the way the user types English
        ("has", "en(has)"),
        // Between words typed in Ebi, and is Ebi's あげ
        ("hsid and lsid", "ja(L:koreagesore)"),
        // Between words typed in QWERTY, good stays English
        ("watashiha good desu", "ja(watashiha) en(good) ja(desu)"),
        ("I checked the build log and the tests pass", "en(I) en(checked) en(the) en(build) en(log) en(and) en(the) en(tests) en(pass)"),
    ])
    func decidesWordsBothReadingsSpellByTheFingeringAround(typed: String, expected: String) {
        #expect(notation(typed) == expected)
    }
}

@Suite struct LayoutEnglishTests {
    @Test func readsEnglishTypedWithTheLayoutsFingering() {
        // world typed in Ebi; nothing else reads the keys
        #expect(notation("usiwm") == "en/L(world)")
        #expect(notation("hello usiwm") == "en(hello) en/L(world)")
    }

    @Test func keepsUnknownEnglishAsTyped() {
        #expect(notation("kubernetes") == "en(kubernetes)")
    }
}
