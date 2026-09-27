/// Judges a word from the dictionary and the readings alone, without Jev. Kaede only logs how
/// often it agrees with Jev, to see whether a mode without Jev would be worth building.
public struct DictionaryRule: Sendable {
    let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon) {
        self.lexicon = lexicon
    }

    /// English while the letters are on their way to a known word; otherwise Japanese in the
    /// first layout whose reading can become romaji; English when none can.
    public func judge(_ word: Run) -> Answer {
        let qwerty = word.reading(in: .qwerty)
        if lexicon.containsWord(startingWith: qwerty) {
            return .english
        }
        if RomajiParser.isPlainRomajiPrefix(qwerty) {
            return .japaneseQwerty
        }
        if RomajiParser.isPlainRomajiPrefix(word.reading(in: .ebi)) {
            return .japaneseEbi
        }
        return .english
    }
}
