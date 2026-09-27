/// Judges a word from the dictionary and the readings alone, without Jev. Kaede logs how often
/// it agrees with Jev, to see whether a mode without Jev would be worth building; the switch rule
/// uses whether an English word starts with the letters as a guard.
public struct DictionaryRule: Sendable {
    let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon) {
        self.lexicon = lexicon
    }

    /// English while the letters are on their way to a known word; otherwise Japanese in the
    /// first layout whose reading can become romaji; English when none can.
    public func judge(_ word: Run) -> Answer {
        if isEnglishStart(word) {
            return .english
        }
        let qwerty = word.reading(in: .qwerty)
        if RomajiParser.isPlainRomajiPrefix(qwerty) {
            return .japaneseQwerty
        }
        if RomajiParser.isPlainRomajiPrefix(word.reading(in: .ebi)) {
            return .japaneseEbi
        }
        return .english
    }

    /// Whether a known English word starts with the letters as they show on screen.
    public func isEnglishStart(_ word: Run) -> Bool {
        lexicon.containsWord(startingWith: word.reading(in: .qwerty))
    }
}
