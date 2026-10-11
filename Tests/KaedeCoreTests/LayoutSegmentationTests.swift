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
