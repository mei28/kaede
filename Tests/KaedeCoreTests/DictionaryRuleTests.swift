import Testing
@testable import KaedeCore

@Suite struct DictionaryRuleTests {
    let rule = DictionaryRule(lexicon: EnglishLexicon(wordList: "the\nthink\nwater\n"))

    @Test(arguments: [
        // Letters on their way to a known word stay English
        ("thi", Answer.english),
        ("wat", .english),
        ("watashi", .japaneseQwerty),
        // QWERTY shows jajsd/a; read in Ebi it is tatoeba
        ("jajsd/a", .japaneseEbi),
        // Nothing reads it: it stays as typed
        ("qqq", .english),
    ])
    func judgesAWordByTheDictionaryThenByTheReadings(typed: String, answer: Answer) {
        #expect(rule.judge(Run(typing: typed)) == answer)
    }
}
