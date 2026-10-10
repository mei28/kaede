import Foundation
import KaedeCore

/// Converts the form's text off the main thread, with azooKey for the romaji.
///
/// azooKey's converter is made inside the actor and never leaves it. Clauses already converted
/// are kept, so converting the text again after each key only asks azooKey about what changed.
public actor ConversionWorker {
    private let dictionaryDirectory: URL
    private let memoryDirectory: URL
    private let converter: TextConverter
    /// Made on first use: it loads the whole dictionary, about a second.
    private lazy var azooKey = AzooKeyConverter(dictionaryDirectory: dictionaryDirectory, memoryDirectory: memoryDirectory)
    private var clauses: [String: [Bunsetsu]] = [:]

    public init(dictionaryDirectory: URL, memoryDirectory: URL, lexicon: EnglishLexicon) {
        self.dictionaryDirectory = dictionaryDirectory
        self.memoryDirectory = memoryDirectory
        converter = TextConverter(lexicon: lexicon)
    }

    /// Loads the dictionary now, so the first preview does not wait for it.
    public func warmUp() throws {
        _ = try azooKey.convert(romaji: "kaede")
    }

    /// Throws CancellationError when the task is cancelled: a newer text has taken its place.
    public func convert(_ text: String, style: PunctuationStyle) throws -> ConvertedText {
        try Task.checkCancellation()
        return try converter.convert(text, style: style) { clause in
            try Task.checkCancellation()
            return try kanji(for: clause)
        }
    }

    private func kanji(for clause: String) throws -> [Bunsetsu] {
        if let known = clauses[clause] {
            return known
        }
        if clauses.count >= Self.clauseLimit {
            clauses.removeAll()
        }
        let converted = try azooKey.convert(romaji: clause)
        clauses[clause] = converted
        return converted
    }

    /// Enough for every clause of a long draft; dropping them all past it keeps the memory small.
    private static let clauseLimit = 2000
}
