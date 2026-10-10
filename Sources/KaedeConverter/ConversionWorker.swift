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
    private let wordCover: WordCover
    /// Made on first use: it loads the whole dictionary, about a second.
    private lazy var azooKey = AzooKeyConverter(dictionaryDirectory: dictionaryDirectory, memoryDirectory: memoryDirectory)
    private var clauses: [String: [Bunsetsu]] = [:]
    private var readingCandidates: [String: [String]] = [:]

    public init(dictionaryDirectory: URL, memoryDirectory: URL, lexicon: EnglishLexicon) {
        self.dictionaryDirectory = dictionaryDirectory
        self.memoryDirectory = memoryDirectory
        converter = TextConverter(lexicon: lexicon)
        wordCover = WordCover(lexicon: lexicon)
    }

    /// Loads the dictionary now, so the first preview does not wait for it.
    public func warmUp() throws {
        _ = try azooKey.convert(romaji: "kaede")
    }

    /// Throws CancellationError when the task is cancelled: a newer text has taken its place.
    public func convert(_ text: String, style: PunctuationStyle, choices: ConversionChoices = ConversionChoices()) throws -> ConvertedText {
        try Task.checkCancellation()
        return try converter.convert(text, style: style, choices: choices) { clause in
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

    /// What a unit can become: a phrase's candidates for its reading, then the letters it came
    /// from as English (weare, we are); English as typed, then, when it reads as romaji, its
    /// Japanese candidates (sake → 酒).
    /// - Parameter readingInClause: where a phrase's reading sits in its clause's reading.
    public func candidates(for unit: ConversionUnit, readingInClause: Range<Int>?) throws -> [ConversionCandidate] {
        switch unit.kind {
        case let .bunsetsu(clause, _):
            var candidates = try japaneseCandidates(reading: unit.reading)
            if let readingInClause, let letters = azooKey.romaji(of: clause, reading: readingInClause) {
                // Last, so that ↑ from the first candidate reaches them, as in azooKey
                candidates += englishForms(of: letters)
            }
            return candidates
        case let .english(typed):
            guard RomajiParser.isPlainRomaji(typed) else {
                return [ConversionCandidate(typed, .english)]
            }
            let reading = try kanji(for: typed).map(\.reading).joined()
            return try [ConversionCandidate(typed, .english)] + japaneseCandidates(reading: reading)
        }
    }

    /// The letters as typed, then split into English words when they make more than one: the
    /// words come last, where ↑ from the first candidate lands.
    private func englishForms(of letters: String) -> [ConversionCandidate] {
        var forms = [letters]
        if let words = wordCover.englishWords(letters), words.count > 1 {
            forms.append(words.joined(separator: " "))
        }
        return forms.map { ConversionCandidate($0, .english) }
    }

    private func japaneseCandidates(reading: String) throws -> [ConversionCandidate] {
        try candidates(reading: reading).map { ConversionCandidate($0, .japanese) }
    }

    /// The phrases with the border after the one at `index` moved by a character, the two changed
    /// phrases converted again; the same phrases when the border cannot move.
    public func resized(_ phrases: [Bunsetsu], at index: Int, by delta: Int) throws -> [Bunsetsu] {
        guard let readings = PhraseReadings.resized(phrases.map(\.reading), at: index, by: delta) else {
            return phrases
        }
        // The next phrase either changed too or went away; phrases past it only moved
        let shift = readings.count - phrases.count
        let changed = shift < 0 ? index...index : index...(index + 1)
        return try readings.indices.map { position in
            if changed.contains(position) {
                return Bunsetsu(reading: readings[position], text: try candidates(reading: readings[position])[0])
            }
            return phrases[position < index ? position : position - shift]
        }
    }

    private func candidates(reading: String) throws -> [String] {
        if let known = readingCandidates[reading] {
            return known
        }
        if readingCandidates.count >= Self.clauseLimit {
            readingCandidates.removeAll()
        }
        let candidates = try azooKey.candidates(reading: reading)
        readingCandidates[reading] = candidates
        return candidates
    }

    /// Enough for every clause of a long draft; dropping them all past it keeps the memory small.
    private static let clauseLimit = 2000
}
