/// Splits English typed without spaces ("allyouneedisattention") into words.
///
/// Only common words are used: with every dictionary word, rare ones break good splits
/// ("nee dis" instead of "need is") and a fifth of Japanese romaji reads as English words.
public struct EnglishSplitter: Sendable {
    let commonWords: EnglishLexicon

    public init(commonWords: EnglishLexicon) {
        self.commonWords = commonWords
    }

    /// The fewest common words that spell `letters`, as typed; nil unless there are two or more.
    public func split(_ letters: String) -> [String]? {
        let characters = Array(letters)
        // fewest[i]: the fewest words spelling the first i characters, as the end of the last one
        var fewest: [(count: Int, previous: Int)?] = Array(repeating: nil, count: characters.count + 1)
        fewest[0] = (0, 0)
        for start in characters.indices {
            guard let reached = fewest[start] else { continue }
            for end in (start + 1)...characters.count {
                guard commonWords.contains(String(characters[start..<end])) else { continue }
                if fewest[end] == nil || reached.count + 1 < fewest[end]!.count {
                    fewest[end] = (reached.count + 1, start)
                }
            }
        }
        guard let last = fewest[characters.count], last.count >= 2 else { return nil }
        var words: [String] = []
        var end = characters.count
        while end > 0, let step = fewest[end] {
            words.append(String(characters[step.previous..<end]))
            end = step.previous
        }
        return words.reversed()
    }
}
