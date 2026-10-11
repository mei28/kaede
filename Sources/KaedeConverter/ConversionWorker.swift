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
    private let lexicon: EnglishLexicon
    private let wordCover: WordCover
    /// Made on first use: it loads the whole dictionary, about a second.
    private lazy var azooKey = AzooKeyConverter(dictionaryDirectory: dictionaryDirectory, memoryDirectory: memoryDirectory)
    private var clauses: [String: [Bunsetsu]] = [:]
    private var readingCandidates: [String: [String]] = [:]

    public init(dictionaryDirectory: URL, memoryDirectory: URL, lexicon: EnglishLexicon) {
        self.dictionaryDirectory = dictionaryDirectory
        self.memoryDirectory = memoryDirectory
        converter = TextConverter(lexicon: lexicon)
        self.lexicon = lexicon
        wordCover = WordCover(lexicon: lexicon)
    }

    /// Loads the dictionary now, so the first preview does not wait for it.
    public func warmUp() throws {
        _ = try azooKey.convert(romaji: "kaede")
    }

    /// Throws CancellationError when the task is cancelled: a newer text has taken its place.
    public func convert(
        _ text: String, style: PunctuationStyle, layout: KeyboardLayout = .qwerty, choices: ConversionChoices = ConversionChoices()
    ) throws -> ConvertedText {
        try Task.checkCancellation()
        return try converter.convert(text, style: style, layout: layout, choices: choices) { clause in
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

    /// What a unit can become.
    /// - A phrase: its reading's candidates; then, for its keys read the other way (as typed in
    ///   QWERTY, or through the layout) when that reads as other romaji, those candidates; then
    ///   its keys as English, last, so ↑ from the first candidate reaches them as in azooKey
    ///   (weare, we are).
    /// - English: as it shows, its keys as typed, the Japanese of whichever reading is romaji
    ///   (sake → 酒, has typed in Ebi → 顔), and the word the layout reads.
    /// - Parameters:
    ///   - readingInClause: where a phrase's reading sits in its clause's reading.
    ///   - layout: the layout the user types Japanese with.
    public func candidates(for unit: ConversionUnit, readingInClause: Range<Int>?, layout: KeyboardLayout = .qwerty) throws -> [ConversionCandidate] {
        var candidates: [ConversionCandidate]
        switch unit.kind {
        case let .bunsetsu(clause, _):
            candidates = try japaneseCandidates(reading: unit.reading)
            guard let readingInClause, let range = azooKey.letterRange(of: clause, reading: readingInClause) else {
                return candidates
            }
            let letters = String(Array(clause)[range])
            let keys = String(Array(unit.typed)[range])
            for other in [keys, layout.read(keys)] where other != letters && RomajiParser.isPlainRomaji(other) {
                candidates += try japaneseCandidates(reading: kana(of: other))
            }
            candidates += englishForms(of: keys, layout: layout)
        case let .english(shown):
            candidates = [ConversionCandidate(shown, .english), ConversionCandidate(unit.typed, .english)]
            for reading in [unit.typed, layout.read(unit.typed)] where RomajiParser.isPlainRomaji(reading) {
                candidates += try japaneseCandidates(reading: kana(of: reading))
            }
            if lexicon.contains(layout.read(unit.typed)) {
                candidates.append(ConversionCandidate(layout.read(unit.typed), .english))
            }
        }
        return candidates.reduce(into: []) { unique, candidate in
            if !unique.contains(candidate) {
                unique.append(candidate)
            }
        }
    }

    /// The keys as typed, the word the layout reads them as, then split into English words when
    /// they make more than one: the words come last, where ↑ from the first candidate lands.
    private func englishForms(of keys: String, layout: KeyboardLayout) -> [ConversionCandidate] {
        var forms = [keys]
        if lexicon.contains(layout.read(keys)) {
            forms.append(layout.read(keys))
        }
        if let words = wordCover.englishWords(keys), words.count > 1 {
            forms.append(words.joined(separator: " "))
        }
        return forms.map { ConversionCandidate($0, .english) }
    }

    private func kana(of romaji: String) throws -> String {
        try kanji(for: romaji).map(\.reading).joined()
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
