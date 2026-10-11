import Foundation

/// A part of a run of keys, read in one fingering.
enum RunPiece: Equatable {
    case romaji(Spelling)
    /// English words typed in QWERTY.
    case english(words: [String])
    /// As read.
    case punctuation(Character, Fingering)

    var readsThroughLayout: Bool {
        switch self {
        case let .romaji(spelling): spelling.fingering == .layout
        case .english: false
        case let .punctuation(_, fingering): fingering == .layout
        }
    }
}

/// Reads a run of keys in QWERTY and through the user's layout at once, piece by piece: QWERTY
/// romaji and English, and romaji typed with the layout's fingering (jajsd/a as tatoeba in Ebi).
///
/// Ways of reading the run are compared by the rules they break, then the pieces they make,
/// then how often Japanese changes fingering, then how many syllables, English letters and marks
/// they take (fewer kana: から over はいあ),
/// then how many keys they read through the layout (QWERTY when both read alike), then how
/// uncommon their English words are.
struct KeyRunCover {
    let lexicon: EnglishLexicon
    let layout: KeyboardLayout
    private let logWordCount: Double

    init(lexicon: EnglishLexicon, layout: KeyboardLayout) {
        self.lexicon = lexicon
        self.layout = layout
        logWordCount = log(Double(max(lexicon.count, 2)))
    }

    /// The cheapest reading of every key, or nil when some keys fit no reading.
    func cover(_ run: String) -> [RunPiece]? {
        let keys = Keys(typed: Array(run), layout: layout)
        var best: [[State: Step]] = Array(repeating: [:], count: keys.count + 1)
        best[0][State()] = Step(cost: Cost(), previous: nil)
        for position in 0..<keys.count {
            for (state, step) in best[position] {
                for move in moves(from: state, at: position, keys: keys) {
                    let next = Step(cost: step.cost + move.cost, previous: (position, state, move.piece))
                    if let known = best[move.end][move.state], known.cost <= next.cost {
                        continue
                    }
                    best[move.end][move.state] = next
                }
            }
        }
        let finished = best[keys.count].compactMap { state, step in
            finishing(state).map { (state, step.cost + $0) }
        }
        guard let (last, _) = finished.min(by: { $0.1 < $1.1 }) else {
            return nil
        }
        return pieces(best, endingIn: last, keys: keys)
    }

    /// The typed keys and how each fingering reads them, one for one.
    private struct Keys {
        let typed: [Character]
        let layoutReading: [Character]

        init(typed: [Character], layout: KeyboardLayout) {
            self.typed = typed
            layoutReading = typed.map(layout.read)
        }

        var count: Int { typed.count }

        func reading(_ fingering: Fingering) -> [Character] {
            fingering == .qwerty ? typed : layoutReading
        }
    }

    // MARK: Moves

    private struct Move {
        var end: Int
        var state: State
        var cost: Cost
        var piece: StepPiece
    }

    /// What one step read, before the steps of one piece are joined.
    enum StepPiece: Hashable {
        case syllable(Fingering)
        case word
        case punctuation(Fingering)
    }

    private func moves(from state: State, at position: Int, keys: Keys) -> [Move] {
        syllableMoves(.qwerty, from: state, at: position, keys: keys)
            + syllableMoves(.layout, from: state, at: position, keys: keys)
            + wordMoves(from: state, at: position, keys: keys)
            + punctuationMoves(from: state, at: position, keys: keys)
            + layoutPunctuationMoves(from: state, at: position, keys: keys)
    }

    private func syllableMoves(_ fingering: Fingering, from state: State, at position: Int, keys: Keys) -> [Move] {
        if let waiting = state.sokuon, waiting != fingering {
            return []
        }
        let continuing = state.last == .romaji(fingering)
        // Japanese changes fingering only between stretches of three syllables or more, also
        // across the layout's punctuation
        let acrossPunctuation = state.last.isLayoutPunctuation && fingering == .qwerty
        let switching = !continuing && state.last.isRomaji || acrossPunctuation
        if switching, (acrossPunctuation ? state.syllablesBeforePunctuation : state.syllables) < 3 {
            return []
        }
        if !continuing, !state.layoutRomajiMayEnd(beforeEnglish: false) {
            return []
        }
        let reading = keys.reading(fingering)
        return RomajiParser.syllableEnds(in: reading, from: position).map { end in
            var cost = Cost()
            cost.syllables = 1
            if fingering == .layout {
                cost.layoutKeys = end - position
            }
            if !continuing {
                cost.pieces = 1
                cost.violations = state.violationsTouching(romajiIn: fingering)
            }
            if switching {
                cost.switches = 1
            }
            var next = continuing ? state : State()
            next.afterSwitch = continuing ? state.afterSwitch : switching
            if !continuing {
                next.afterEnglish = state.last == .english
            }
            next.last = .romaji(fingering)
            next.syllables = min((continuing ? state.syllables : 0) + 1, 3)
            // Kept while a layout piece is too short to stand beside English on its own
            next.shortText = fingering == .layout && next.syllables < 2 ? (continuing ? state.shortText ?? "" : "") + String(reading[position..<end]) : nil
            let isSokuon = end == position + 1 && !"aiueon".contains(reading[position])
            next.sokuon = isSokuon ? fingering : nil
            return Move(end: end, state: next, cost: cost, piece: .syllable(fingering))
        }
    }

    private func wordMoves(from state: State, at position: Int, keys: Keys) -> [Move] {
        guard state.sokuon == nil, state.last != .qwertyPeriod, !state.last.isLayoutPunctuation, state.romajiMayEnd, state.layoutRomajiMayEnd(beforeEnglish: true) else { return [] }
        var moves: [Move] = []
        for end in (position + 1)...min(keys.count, position + Self.longestWord) {
            let word = String(keys.typed[position..<end])
            guard word.allSatisfy(\.isLetter), let rank = lexicon.rank(of: word) else { continue }
            let readsAsRomaji = RomajiParser.isPlainRomaji(word)
            let readsAsLayoutRomaji = RomajiParser.isPlainRomaji(layout.read(word))
            let wordsBefore = state.last == .english ? state.englishWords : 0
            var cost = Cost()
            cost.englishLetters = word.count
            cost.english = log(Double(rank) * logWordCount)
            if state.last != .english {
                cost.pieces = 1
                // A word that reads as the romaji it touches: Japanese keeps the letters at a border
                if state.last == .romaji(.qwerty) && readsAsRomaji || state.last == .romaji(.layout) && readsAsLayoutRomaji {
                    cost.violations += 1
                }
            }
            if FunctionWords.all.contains(word.lowercased()), wordsBefore < 2 {
                cost.violations += 1
            }
            var next = State()
            next.last = .english
            next.englishWords = min(wordsBefore + 1, 2)
            next.lastWordReadsAsRomaji = readsAsRomaji
            next.lastWordReadsAsLayoutRomaji = readsAsLayoutRomaji
            next.lastWordIsAOrI = ["a", "i"].contains(word.lowercased())
            moves.append(Move(end: end, state: next, cost: cost, piece: .word))
        }
        return moves
    }

    private func punctuationMoves(from state: State, at position: Int, keys: Keys) -> [Move] {
        let key = keys.typed[position]
        guard ",.".contains(key), state.sokuon == nil, state.last != .qwertyPeriod, !state.last.isLayoutPunctuation, state.romajiMayEnd,
              state.layoutRomajiMayEnd(beforeEnglish: false)
        else { return [] }
        var cost = Cost()
        cost.marks = 1
        cost.violations = state.violationsEndingEnglish() + (state.last == .start ? 1 : 0)
        var next = State()
        if key == "," {
            next.last = .qwertyComma
        } else {
            // A period ends a sentence between romaji only (desu.kyouha, not main.swift)
            guard case .romaji = state.last else { return [] }
            next.last = .qwertyPeriod
        }
        return [Move(end: position + 1, state: next, cost: cost, piece: .punctuation(.qwerty))]
    }

    /// The layout's 、。？ (Ebi's e, r and Shift+B) after two syllables or more of romaji in the
    /// layout; only romaji follows it. Elsewhere those keys are letters: coffee is not cyii、e.
    private func layoutPunctuationMoves(from state: State, at position: Int, keys: Keys) -> [Move] {
        let read = keys.layoutReading[position]
        guard keys.typed[position].isLetter, ",.?".contains(read), state.last == .romaji(.layout), state.syllables >= 2,
              state.sokuon == nil, state.romajiMayEnd
        else { return [] }
        var cost = Cost()
        cost.pieces = 1
        cost.marks = 1
        cost.layoutKeys = 1
        var next = State()
        next.last = .layoutPunctuation(read)
        next.syllablesBeforePunctuation = state.syllables
        return [Move(end: position + 1, state: next, cost: cost, piece: .punctuation(.layout))]
    }

    /// The cost of ending the run in `state`, or nil when it cannot end there.
    private func finishing(_ state: State) -> Cost? {
        guard state.sokuon == nil, state.last != .qwertyPeriod, state.last != .layoutPunctuation(","), state.romajiMayEnd,
              state.layoutRomajiMayEnd(beforeEnglish: false)
        else { return nil }
        var cost = Cost()
        cost.violations = state.violationsEndingEnglish()
        return cost
    }

    /// No English word in the lexicon is longer.
    private static let longestWord = 24

    // MARK: Pieces

    private func pieces(_ best: [[State: Step]], endingIn last: State, keys: Keys) -> [RunPiece] {
        var steps: [(range: Range<Int>, piece: StepPiece)] = []
        var position = keys.count
        var state = last
        while let (previousPosition, previousState, piece) = best[position][state]?.previous {
            steps.insert((previousPosition..<position, piece), at: 0)
            position = previousPosition
            state = previousState
        }
        var pieces: [RunPiece] = []
        for (range, piece) in steps {
            switch piece {
            case let .syllable(fingering):
                let spelling = Spelling(text: String(keys.reading(fingering)[range]), typed: String(keys.typed[range]), fingering: fingering)
                if case let .romaji(last)? = pieces.last, last.fingering == fingering {
                    pieces[pieces.count - 1] = .romaji(Spelling(text: last.text + spelling.text, typed: last.typed + spelling.typed, fingering: fingering))
                } else {
                    pieces.append(.romaji(spelling))
                }
            case .word:
                let word = String(keys.typed[range])
                if case let .english(words)? = pieces.last {
                    pieces[pieces.count - 1] = .english(words: words + [word])
                } else {
                    pieces.append(.english(words: [word]))
                }
            case let .punctuation(fingering):
                pieces.append(.punctuation(keys.reading(fingering)[range.lowerBound], fingering))
            }
        }
        return pieces
    }

    // MARK: State and cost

    struct State: Hashable {
        enum Last: Hashable {
            case start
            case romaji(Fingering)
            case english
            case qwertyComma
            case qwertyPeriod
            /// 、。？ as the layout reads them.
            case layoutPunctuation(Character)

            var isRomaji: Bool {
                if case .romaji = self { true } else { false }
            }

            var isLayoutPunctuation: Bool {
                if case .layoutPunctuation = self { true } else { false }
            }
        }

        var last = Last.start
        /// Syllables of the current romaji piece, up to 3.
        var syllables = 0
        /// The current romaji piece came right after romaji in the other fingering.
        var afterSwitch = false
        /// Syllables of the romaji before the layout's punctuation, up to 3.
        var syllablesBeforePunctuation = 0
        /// The current romaji piece came right after English.
        var afterEnglish = false
        /// The current piece in the layout while under two syllables, as read.
        var shortText: String?
        /// A sokuon waiting for a syllable read the same way.
        var sokuon: Fingering?
        var englishWords = 0
        var lastWordReadsAsRomaji = false
        var lastWordReadsAsLayoutRomaji = false
        var lastWordIsAOrI = false

        /// Romaji starting right after English: a readable word at the border, or English ending
        /// in a or i.
        func violationsTouching(romajiIn fingering: Fingering) -> Int {
            guard last == .english else { return 0 }
            let readable = fingering == .qwerty ? lastWordReadsAsRomaji : lastWordReadsAsLayoutRomaji
            return (readable ? 1 : 0) + (lastWordIsAOrI ? 1 : 0)
        }

        func violationsEndingEnglish() -> Int {
            last == .english && lastWordIsAOrI ? 1 : 0
        }

        /// Romaji that changed fingering ends only after three syllables, like the stretch before it.
        var romajiMayEnd: Bool {
            !(afterSwitch && syllables < 3)
        }

        /// A piece of one syllable in the layout touches English only as a particle or verb
        /// ending right after it (python | の | bug): one syllable the layout reads by chance
        /// would otherwise cut English apart (post | う | res).
        func layoutRomajiMayEnd(beforeEnglish: Bool) -> Bool {
            guard last == .romaji(.layout), let shortText else { return true }
            guard afterEnglish || beforeEnglish else { return true }
            return afterEnglish && FunctionWords.all.contains(shortText)
        }
    }

    struct Cost: Comparable {
        var violations = 0
        var pieces = 0
        var switches = 0
        var syllables = 0
        var englishLetters = 0
        var marks = 0
        var layoutKeys = 0
        var english = 0.0

        /// Syllables, English letters and marks: fewer means fewer kana for the same keys.
        var taken: Int {
            syllables + englishLetters + marks
        }

        static func + (lhs: Cost, rhs: Cost) -> Cost {
            Cost(
                violations: lhs.violations + rhs.violations, pieces: lhs.pieces + rhs.pieces, switches: lhs.switches + rhs.switches,
                syllables: lhs.syllables + rhs.syllables, englishLetters: lhs.englishLetters + rhs.englishLetters,
                marks: lhs.marks + rhs.marks, layoutKeys: lhs.layoutKeys + rhs.layoutKeys, english: lhs.english + rhs.english
            )
        }

        static func < (lhs: Cost, rhs: Cost) -> Bool {
            (lhs.violations, lhs.pieces, lhs.switches, lhs.taken, lhs.layoutKeys, lhs.english)
                < (rhs.violations, rhs.pieces, rhs.switches, rhs.taken, rhs.layoutKeys, rhs.english)
        }
    }

    struct Step {
        var cost: Cost
        var previous: (position: Int, state: State, piece: StepPiece)?
    }
}
