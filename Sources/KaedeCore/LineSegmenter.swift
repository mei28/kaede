/// A part of a line, ready to be converted and put together.
public struct Segment: Equatable, Sendable {
    public enum Content: Equatable, Sendable {
        /// Words as read, joined by one space, with the keys that typed them.
        case english(Spelling)
        /// A clause of romaji, with the digits next to it, to convert as one sentence.
        case romaji(Clause)
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

    /// - Parameter layout: the layout the user types Japanese with, which keys may be read through.
    public func segments(of line: Substring, layout: KeyboardLayout = .qwerty) -> [Segment] {
        let units = Tokenizer.tokens(of: line).flatMap { self.units(of: $0, layout: layout) }
        return segments(of: resolvingAmbiguousWords(in: resolvingCrossReadings(in: separatingWordsBeforeParticles(in: units))))
    }

    // MARK: Words

    private func units(of token: TypedToken, layout: KeyboardLayout) -> [Unit] {
        let kinds: [Unit.Kind] = switch token.token {
        case let .keys(run): kinds(ofRun: run, layout: layout)
        default: kinds(of: token.token)
        }
        return kinds.enumerated().map { index, kind in
            Unit(kind: kind, spaceBefore: index == 0 && token.spaceBefore)
        }
    }

    /// A run of keys read through the layout where that reads better (jajsd/a as tatoeba in Ebi),
    /// else in QWERTY as before.
    private func kinds(ofRun run: String, layout: KeyboardLayout) -> [Unit.Kind] {
        guard !layout.isQwerty else {
            return KeyRun.qwertyTokens(run).flatMap(kinds(of:))
        }
        if run.contains("-") {
            // ra-men typed with the layout's fingering, when QWERTY reads it as no romaji
            let reading = layout.read(run)
            if !RomajiParser.isPlainRomaji(run), RomajiParser.isPlainRomaji(reading) {
                return [.romaji(Spelling(text: reading, typed: run, fingering: .layout))]
            }
            return KeyRun.qwertyTokens(run).flatMap(kinds(of:))
        }
        guard let pieces = KeyRunCover(lexicon: lexicon, layout: layout).cover(run), pieces.contains(where: \.readsThroughLayout) else {
            let qwerty = KeyRun.qwertyTokens(run).flatMap(kinds(of:))
            // Letters left as unknown English that the layout reads as a word: world typed as usiwm
            if qwerty == [.english(qwerty: [run])], !lexicon.contains(run), lexicon.contains(layout.read(run)) {
                return [.english(words: [layout.read(run)], typed: run, fingering: .layout)]
            }
            return qwerty
        }
        // Read wholly through the layout, yet QWERTY English spells it too
        if pieces.allSatisfy(\.readsThroughLayout), !RomajiParser.isPlainRomaji(run), let words = wordCover.englishWords(run) {
            // has, which Ebi reads as かお: the words around decide
            if pieces.count == 1, case let .romaji(spelling) = pieces[0] {
                return [.crossReading(english: words, romaji: spelling)]
            }
            // far, which Ebi reads as いあ。: the layout's punctuation makes it no Japanese
            return KeyRun.qwertyTokens(run).flatMap(kinds(of:))
        }
        return pieces.map(Unit.Kind.init)
    }

    private func kinds(of token: Token) -> [Unit.Kind] {
        switch token {
        case .keys:
            preconditionFailure("runs of keys are read before their tokens are classified")
        case let .letters(letters): kinds(of: letters)
        case let .digits(digits): [.digits(digits)]
        case let .punctuation(character): [.punctuation(character)]
        case let .mark(mark): [.mark(mark)]
        case let .verbatim(text, language): [.verbatim(text, language)]
        }
    }

    private func kinds(of letters: String) -> [Unit.Kind] {
        if letters.contains("-") {
            return RomajiParser.isPlainRomaji(letters) ? [.romaji(qwerty: letters)] : [.english(qwerty: [letters])]
        }
        if RomajiParser.isPlainRomaji(letters) {
            return lexicon.contains(letters) ? [.ambiguous(letters)] : [.romaji(qwerty: letters)]
        }
        if let pieces = wordCover.cover(letters) {
            return pieces.map(Unit.Kind.init)
        }
        // A capitalised word is English whole (Kaede, not Kae | de)
        if letters.first?.isUppercase == false, let pieces = wordCover.unknownStem(letters) {
            return pieces.map(Unit.Kind.init)
        }
        return [.english(qwerty: [letters])]
    }

    /// Romaji that ends in a particle after an English word of three letters or more, right
    /// before English, gives the word back to English (apinoerror → api | no | error): the word
    /// reads as romaji, so the cover kept it Japanese.
    private func separatingWordsBeforeParticles(in units: [Unit]) -> [Unit] {
        var result: [Unit] = []
        for (index, unit) in units.enumerated() {
            guard case let .romaji(spelling) = unit.kind, spelling.fingering == .qwerty, index + 1 < units.count,
                  case .english = units[index + 1].kind,
                  case let text = spelling.text,
                  let particle = FunctionWords.particlesLongestFirst.first(where: { particle in
                      text.hasSuffix(particle) && text.count - particle.count >= 3 && lexicon.contains(text.dropLast(particle.count))
                  })
            else {
                result.append(unit)
                continue
            }
            result.append(Unit(kind: .english(qwerty: [String(text.dropLast(particle.count))]), spaceBefore: unit.spaceBefore))
            result.append(Unit(kind: .romaji(qwerty: particle), spaceBefore: false))
        }
        return result
    }

    // MARK: Context

    /// Decides the words QWERTY English and the layout's romaji both spell by the fingering
    /// around them: the nearest word before and after count +1 when typed in QWERTY and -1 when
    /// read through the layout, and the word is English when the sum is 0 or more (has alone,
    /// watashiha good desu), else romaji (hsid and lsid: これ あげ それ).
    private func resolvingCrossReadings(in units: [Unit]) -> [Unit] {
        var units = units
        for index in units.indices {
            guard case let .crossReading(words, romaji) = units[index].kind else { continue }
            let before = units[..<index].reversed().prefix { !$0.endsSentence }.lazy.compactMap(\.fingering).first
            let after = units[(index + 1)...].prefix { !$0.endsSentence }.lazy.compactMap(\.fingering).first
            let score = [before, after].compactMap { $0 }.map { $0 == .qwerty ? 1 : -1 }.reduce(0, +)
            units[index].kind = score >= 0 ? .english(words: words, typed: romaji.typed, fingering: .qwerty) : .romaji(romaji)
        }
        return units
    }

    /// Decides the words that are both romaji and English by the words around them.
    ///
    /// A spaced "no" is English only after two English words (python no bug → の). Other such
    /// words are decided a run at a time: what comes before counts +2 for two English words, +1
    /// for one, -1 for Japanese; what comes after (past a lone particle) +1 or -1; and the run is
    /// English when the sum reaches 1, or 2 for a run of short words like "to" alone.
    private func resolvingAmbiguousWords(in units: [Unit]) -> [Unit] {
        var units = units
        for index in units.indices where units[index].kind == .ambiguous("no") {
            units[index].kind = before(index, in: units) == 2 ? .english(qwerty: ["no"]) : .romaji(qwerty: "no")
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
                units[index].kind = english ? .english(qwerty: [word]) : .romaji(qwerty: word)
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
            if case let .romaji(spelling) = unit.kind, FunctionWords.particles[spelling.text] != nil {
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
        func appendRomaji(_ spelling: Spelling, spaceBefore: Bool) {
            if case var .romaji(clause)? = segments.last?.content {
                clause.append(spelling)
                segments[segments.count - 1].content = .romaji(clause)
            } else {
                segments.append(Segment(content: .romaji(Clause([spelling])), spaceBefore: spaceBefore))
            }
        }
        for (index, unit) in units.enumerated() {
            let content: Segment.Content
            switch unit.kind {
            case let .romaji(spelling):
                appendRomaji(spelling, spaceBefore: unit.spaceBefore)
                continue
            case let .digits(digits) where digitsTouchRomaji(at: index, in: units):
                appendRomaji(Spelling(qwerty: digits), spaceBefore: unit.spaceBefore)
                continue
            case let .digits(digits):
                content = .digits(digits)
            case let .english(words, typed, fingering):
                content = .english(Spelling(text: words.joined(separator: " "), typed: typed, fingering: fingering))
            case let .punctuation(character):
                content = .punctuation(character, language(ofPunctuationAt: index, in: units))
            case let .mark(mark):
                content = .mark(mark)
            case let .verbatim(text, .japanese):
                content = .japaneseText(text)
            case let .verbatim(text, .english):
                content = .english(Spelling(qwerty: text))
            case .ambiguous, .crossReading:
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
        case romaji(Spelling)
        /// The English words of one token, as read, with the keys that typed them.
        case english(words: [String], typed: String, fingering: Fingering)
        /// Reads as romaji and is an English word; decided by the words around it.
        case ambiguous(String)
        /// QWERTY English, and romaji when read through the layout; decided by the fingering around it.
        case crossReading(english: [String], romaji: Spelling)
        case digits(String)
        case punctuation(Character)
        case mark(String)
        case verbatim(String, Language)

        static func romaji(qwerty text: String) -> Kind {
            .romaji(Spelling(qwerty: text))
        }

        static func english(qwerty words: [String]) -> Kind {
            .english(words: words, typed: words.joined(), fingering: .qwerty)
        }

        init(_ piece: Piece) {
            switch piece {
            case let .romaji(text): self = .romaji(qwerty: text)
            case let .english(words): self = .english(qwerty: words)
            }
        }

        init(_ piece: RunPiece) {
            switch piece {
            case let .romaji(spelling): self = .romaji(spelling)
            case let .english(words): self = .english(qwerty: words)
            case let .punctuation(character, _): self = .punctuation(character)
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
        case let .english(words, _, _): Array(repeating: .english, count: words.count)
        case let .verbatim(_, language): [language]
        case .ambiguous, .crossReading, .digits, .punctuation, .mark: []
        }
    }

    /// Which fingering typed its words; none for numbers, marks and undecided readings.
    var fingering: Fingering? {
        switch kind {
        case let .romaji(spelling): spelling.fingering
        case let .english(_, _, fingering): fingering
        case .ambiguous, .verbatim: .qwerty
        case .crossReading, .digits, .punctuation, .mark: nil
        }
    }

    var endsSentence: Bool {
        if case let .punctuation(character) = kind { ".?!".contains(character) } else { false }
    }
}
