import Foundation

/// English words and how common they are, for finding English among romaji.
public struct EnglishLexicon: Sendable {
    /// Each word's line in the list that has it nearest the top, from 1. Lowercased, so "The" at
    /// the start of a sentence and "tokyo" typed in lowercase both match.
    private let ranks: [String: Int]

    /// - Parameter wordList: one word per line, as in `/usr/share/dict/words`.
    public init(wordList: String) {
        self.init(wordLists: [wordList])
    }

    /// - Parameter wordLists: lists of one word per line; a word in any of them is known.
    public init(wordLists: [String]) {
        var ranks: [String: Int] = [:]
        for list in wordLists {
            let words = list.split(separator: "\n")
                .map { $0.lowercased() }
                .filter { $0.count > 2 || Self.shortWords.contains($0) }
            for (index, word) in words.enumerated() {
                ranks[word] = min(ranks[word] ?? .max, index + 1)
            }
        }
        self.ranks = ranks
    }

    /// How many words the lexicon knows.
    public var count: Int {
        ranks.count
    }

    /// Whether the letters are a whole word, in any case.
    public func contains(_ word: some StringProtocol) -> Bool {
        ranks[word.lowercased()] != nil
    }

    /// The word's place by frequency (1 is the most common), or nil when it is unknown.
    public func rank(of word: some StringProtocol) -> Int? {
        ranks[word.lowercased()]
    }

    /// The only words of one or two letters that count. Word lists also carry fragments such as
    /// "ha" and "ko", which would let English claim pieces of romaji.
    private static let shortWords: Set<String> = [
        "a", "i", "am", "an", "as", "at", "be", "by", "do", "go", "he", "hi", "if", "in", "is",
        "it", "me", "my", "no", "of", "oh", "ok", "on", "or", "so", "to", "up", "us", "we",
    ]

    public init(contentsOfFiles paths: [String]) throws {
        self.init(wordLists: try paths.map { try String(contentsOfFile: $0, encoding: .utf8) })
    }
}
