/// A part of a line, ready to be converted and put together.
public struct Segment: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// Words as typed, joined by one space.
        case english(String)
        /// A clause of romaji, with the digits next to it, to convert as one sentence.
        case romaji(String)
        /// Text typed with an input method, kept.
        case japaneseText(String)
        /// A number next to no romaji.
        case digits(String)
        case punctuation(Character, Language)
        /// A bracket, quote, colon or semicolon, kept.
        case mark(String)
    }

    public var content: Content
    /// Whether a space came before it as typed.
    public var spaceBefore: Bool
}

/// Decides which words of a line are English and which are romaji.
///
/// Letters that read as romaji are Japanese unless they are an English word that the words
/// around call English; letters that do not are English words, found inside the word when typed
/// without spaces. Romaji next to romaji forms one clause, so azooKey converts it as a sentence.
public struct LineSegmenter: Sendable {
    private let lexicon: EnglishLexicon
    private let wordCover: WordCover

    public init(lexicon: EnglishLexicon) {
        self.lexicon = lexicon
        wordCover = WordCover(lexicon: lexicon)
    }

    public func segments(of line: Substring) -> [Segment] {
        let units = Tokenizer.tokens(of: line).flatMap(units(of:))
        return segments(of: resolvingAmbiguousWords(in: separatingWordsBeforeParticles(in: units)))
    }

    // MARK: Words

    private func units(of token: TypedToken) -> [Unit] {
        let kinds: [Unit.Kind] = switch token.token {
        case let .letters(letters): kinds(of: letters)
        case let .digits(digits): [.digits(digits)]
        case let .punctuation(character): [.punctuation(character)]
        case let .mark(mark): [.mark(mark)]
        case let .verbatim(text, language): [.verbatim(text, language)]
        }
        return kinds.enumerated().map { index, kind in
            Unit(kind: kind, spaceBefore: index == 0 && token.spaceBefore)
        }
    }

    private func kinds(of letters: String) -> [Unit.Kind] {
        if letters.contains("-") {
            return RomajiParser.isPlainRomaji(letters) ? [.romaji(letters)] : [.english([letters])]
        }
        if RomajiParser.isPlainRomaji(letters) {
            return lexicon.contains(letters) ? [.ambiguous(letters)] : [.romaji(letters)]
        }
        if let pieces = wordCover.cover(letters) {
            return pieces.map(Unit.Kind.init)
        }
        // A capitalised word is English whole (Kaede, not Kae | de)
        if letters.first?.isUppercase == false, let pieces = wordCover.unknownStem(letters) {
            return pieces.map(Unit.Kind.init)
        }
        return [.english([letters])]
    }

    /// Romaji that ends in a particle after an English word of three letters or more, right
    /// before English, gives the word back to English (apinoerror → api | no | error): the word
    /// reads as romaji, so the cover kept it Japanese.
    private func separatingWordsBeforeParticles(in units: [Unit]) -> [Unit] {
        var result: [Unit] = []
        for (index, unit) in units.enumerated() {
            guard case let .romaji(text) = unit.kind, index + 1 < units.count,
                  case .english = units[index + 1].kind,
                  let particle = Particles.romaji.first(where: { particle in
                      text.hasSuffix(particle) && text.count - particle.count >= 3 && lexicon.contains(text.dropLast(particle.count))
                  })
            else {
                result.append(unit)
                continue
            }
            result.append(Unit(kind: .english([String(text.dropLast(particle.count))]), spaceBefore: unit.spaceBefore))
            result.append(Unit(kind: .romaji(particle), spaceBefore: false))
        }
        return result
    }

    // MARK: Context

    /// Decides the words that are both romaji and English by the words around them.
    ///
    /// A spaced "no" is English only after two English words (python no bug → の). Other such
    /// words are decided a run at a time: what comes before counts +2 for two English words, +1
    /// for one, -1 for Japanese; what comes after (past a lone particle) +1 or -1; and the run is
    /// English when the sum reaches 1, or 2 for a run of short words like "to" alone.
    private func resolvingAmbiguousWords(in units: [Unit]) -> [Unit] {
        var units = units
        for index in units.indices where units[index].kind == .ambiguous("no") {
            units[index].kind = before(index, in: units) == 2 ? .english(["no"]) : .romaji("no")
        }
        var start = 0
        while start < units.count {
            guard case .ambiguous = units[start].kind else {
                start += 1
                continue
            }
            var end = start
            while end + 1 < units.count, case .ambiguous = units[end + 1].kind {
                end += 1
            }
            let words = units[start...end].compactMap(\.ambiguousWord)
            var before = before(start, in: units)
            let after = after(end, in: units)
            if after == -1 {
                before = min(before, 1)
            }
            let needed = words.map { $0.count <= 2 && $0 != "i" ? 2 : 1 }.min() ?? 1
            let english = before + after >= needed && (!words.contains("a") || before >= 1)
            for (index, word) in zip(start...end, words) {
                units[index].kind = english ? .english([word]) : .romaji(word)
            }
            start = end + 1
        }
        return units
    }

    /// +2 when the two words before are English, +1 when the one before is, -1 when it is
    /// Japanese, 0 at the start of a sentence.
    private func before(_ index: Int, in units: [Unit]) -> Int {
        var languages: [Language] = []
        for unit in units[..<index].reversed() {
            if unit.endsSentence {
                break
            }
            languages += unit.languages.reversed()
            if languages.count >= 2 {
                break
            }
        }
        switch (languages.first, languages.dropFirst().first) {
        case (.japanese?, _): return -1
        case (.english?, .english?): return 2
        case (.english?, _): return 1
        case (nil, _): return 0
        }
    }

    /// +1 when the next word is English, -1 when it is Japanese, past a lone particle (GitHub no
    /// repo: the particle says nothing about "repo").
    private func after(_ index: Int, in units: [Unit]) -> Int {
        for unit in units[(index + 1)...] {
            if unit.endsSentence {
                return 0
            }
            if case let .romaji(text) = unit.kind, Particles.kana[text] != nil {
                continue
            }
            if case .ambiguous = unit.kind {
                return 0
            }
            switch unit.languages.first {
            case .english?: return 1
            case .japanese?: return -1
            case nil: continue
            }
        }
        return 0
    }

    // MARK: Segments

    private func segments(of units: [Unit]) -> [Segment] {
        var segments: [Segment] = []
        func appendRomaji(_ text: String, spaceBefore: Bool) {
            if case let .romaji(clause)? = segments.last?.content {
                segments[segments.count - 1].content = .romaji(clause + text)
            } else {
                segments.append(Segment(content: .romaji(text), spaceBefore: spaceBefore))
            }
        }
        for (index, unit) in units.enumerated() {
            let content: Segment.Content
            switch unit.kind {
            case let .romaji(text):
                appendRomaji(text, spaceBefore: unit.spaceBefore)
                continue
            case let .digits(digits) where digitsTouchRomaji(at: index, in: units):
                appendRomaji(digits, spaceBefore: unit.spaceBefore)
                continue
            case let .digits(digits):
                content = .digits(digits)
            case let .english(words):
                content = .english(words.joined(separator: " "))
            case let .punctuation(character):
                content = .punctuation(character, language(ofPunctuationAt: index, in: units))
            case let .mark(mark):
                content = .mark(mark)
            case let .verbatim(text, .japanese):
                content = .japaneseText(text)
            case let .verbatim(text, .english):
                content = .english(text)
            case .ambiguous:
                preconditionFailure("every ambiguous word was decided")
            }
            segments.append(Segment(content: content, spaceBefore: unit.spaceBefore))
        }
        return segments
    }

    /// Digits typed right against romaji belong to its clause (10ji → 10時).
    private func digitsTouchRomaji(at index: Int, in units: [Unit]) -> Bool {
        if !units[index].spaceBefore, index > 0, case .romaji = units[index - 1].kind {
            return true
        }
        if index + 1 < units.count, !units[index + 1].spaceBefore, case .romaji = units[index + 1].kind {
            return true
        }
        return false
    }

    /// The language of the nearest word before the punctuation, else after it, else English.
    private func language(ofPunctuationAt index: Int, in units: [Unit]) -> Language {
        units[..<index].reversed().lazy.compactMap(\.languages.last).first
            ?? units[(index + 1)...].lazy.compactMap(\.languages.first).first
            ?? .english
    }
}

/// A word, number or mark of a line while the segmenter decides its language.
private struct Unit {
    enum Kind: Equatable {
        case romaji(String)
        /// The English words of one token.
        case english([String])
        /// Reads as romaji and is an English word; decided by the words around it.
        case ambiguous(String)
        case digits(String)
        case punctuation(Character)
        case mark(String)
        case verbatim(String, Language)

        init(_ piece: Piece) {
            switch piece {
            case let .romaji(text): self = .romaji(text)
            case let .english(words): self = .english(words)
            }
        }
    }

    var kind: Kind
    var spaceBefore: Bool

    var ambiguousWord: String? {
        if case let .ambiguous(word) = kind { word } else { nil }
    }

    /// The language each of its words counts as for its neighbours; none for numbers and marks.
    var languages: [Language] {
        switch kind {
        case .romaji: [.japanese]
        case let .english(words): Array(repeating: .english, count: words.count)
        case let .verbatim(_, language): [language]
        case .ambiguous, .digits, .punctuation, .mark: []
        }
    }

    var endsSentence: Bool {
        if case let .punctuation(character) = kind { ".?!".contains(character) } else { false }
    }
}
