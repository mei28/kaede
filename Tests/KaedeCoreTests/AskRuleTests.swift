import Testing
@testable import KaedeCore

@Suite struct AskRuleTests {
    @Test(arguments: [
        // Too short to tell
        ("ja", nil),
        // QWERTY ja + j and Ebi ta + t can both still become romaji
        ("jaj", [Answer.english, .japaneseQwerty, .japaneseEbi, .keep]),
        // js ends QWERTY; Ebi reads tato
        ("jajs", [.english, .japaneseEbi, .keep]),
        // Ebi reads la;ao
        ("watas", [.english, .japaneseQwerty, .keep]),
        // Neither th nor Ebi ;k, can become romaji: surely not Japanese
        ("the", nil),
    ] as [(String, [Answer]?)])
    func offersEnglishKeepAndEachLayoutThatCanStillBeRomaji(typed: String, options: [Answer]?) {
        #expect(AskRule.options(for: Run(typing: typed)) == options)
    }
}
