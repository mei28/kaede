/// Whether to ask Jev about the word being typed, and which answers to offer. The one place
/// that decides when Kaede asks.
public enum AskRule {
    /// English and keep, with Japanese in each layout whose reading can still become romaji; nil
    /// when the word is too short, or no Japanese reading fits and the word can only be English.
    public static func options(for word: Run) -> [Answer]? {
        guard word.elements.count >= Tuning.minimumStrokes else { return nil }
        let japanese = [(Answer.japaneseQwerty, Layout.qwerty), (.japaneseEbi, .ebi)]
            .filter { RomajiParser.isPlainRomajiPrefix(word.reading(in: $0.1)) }
            .map(\.0)
        guard !japanese.isEmpty else { return nil }
        return [.english] + japanese + [.keep]
    }
}
