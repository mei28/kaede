import Foundation

/// English words, used to tell a run typed as English from one typed as Japanese.
public struct EnglishLexicon: Sendable {
    /// Lowercased, so "The" at the start of a sentence and "tokyo" typed in lowercase both match.
    private let words: Set<String>
    /// The same words in order, so the words sharing a start sit next to each other.
    private let sortedWords: [String]

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
        sortedWords = words.sorted()
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

    /// Whether some word starts with `prefix` (a word starts with itself): letters typed so far
    /// may still be heading for an English word.
    public func containsWord(startingWith prefix: String) -> Bool {
        let prefix = prefix.lowercased()
        // The first word not ordered before the prefix is the first one that could start with it
        var low = 0
        var high = sortedWords.count
        while low < high {
            let middle = (low + high) / 2
            if sortedWords[middle] < prefix {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low < sortedWords.count && sortedWords[low].hasPrefix(prefix)
    }
}
