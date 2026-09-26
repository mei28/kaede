import Foundation

/// English words, used to tell a run typed as English from one typed as Japanese.
public struct EnglishLexicon: Sendable {
    /// Lowercased, so "The" at the start of a sentence and "tokyo" typed in lowercase both match.
    private let words: Set<String>

    /// - Parameter wordList: one word per line, as in `/usr/share/dict/words`.
    public init(wordList: String) {
        self.init(wordLists: [wordList])
    }

    /// - Parameter wordLists: lists of one word per line; a word in any of them is known.
    public init(wordLists: [String]) {
        words = Set(
            wordLists.flatMap { $0.split(separator: "\n") }
                .map { $0.lowercased() }
                .filter { $0.count > 2 || Self.shortWords.contains($0) }
        )
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

    public func contains(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }
}
