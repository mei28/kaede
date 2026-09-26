import Foundation

/// English words, used to tell a run typed as English from one typed as Japanese.
public struct EnglishLexicon: Sendable {
    /// Lowercased, so "The" at the start of a sentence and "tokyo" typed in lowercase both match.
    private let words: Set<String>

    /// - Parameter wordList: one word per line, as in `/usr/share/dict/words`.
    public init(wordList: String) {
        words = Set(wordList.split(separator: "\n").map { $0.lowercased() })
    }

    public init(contentsOfFile path: String) throws {
        self.init(wordList: try String(contentsOfFile: path, encoding: .utf8))
    }

    public func contains(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }
}
