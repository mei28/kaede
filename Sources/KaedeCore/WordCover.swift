import Foundation

/// A part of a run of letters: romaji, or English words.
public enum Piece: Equatable, Sendable {
    case romaji(String)
    /// The words as typed.
    case english([String])
}

/// Finds which letters of a run typed without spaces are romaji and which are English words
/// (kyouhagoogledekensaku → kyouha | google | dekensaku).
public struct WordCover: Sendable {
    private let lexicon: EnglishLexicon
    /// log N for the unigram cost of a word of rank r: log(r · log N), as wordninja prices words.
    private let logWordCount: Double

    public init(lexicon: EnglishLexicon) {
        self.lexicon = lexicon
        logWordCount = log(Double(max(lexicon.count, 2)))
    }

    /// The cheapest way to read every letter as romaji syllables or English words, or nil when
    /// some letters are neither.
    ///
    /// Ways are compared by the rules they break, then by how many pieces they make (fewer
    /// switches between the languages), then by how uncommon their English words are. The rules:
    /// - An English word that reads as romaji does not touch romaji: Japanese keeps the letters
    ///   at a border (sikasinoato | all you…, not sikasino | a to all you…).
    /// - A particle or verb ending is English only after two English words in the same piece
    ///   (python | no | bug, but there is no bug).
    /// - English does not end in "a" or "i" (deploy | sita, not deploy sit a).
    public func cover(_ letters: String) -> [Piece]? {
        let characters = Array(letters)
        var best: [[State: Step]] = Array(repeating: [:], count: characters.count + 1)
        best[0][State.start] = Step(cost: Cost(), previous: nil)
        for position in characters.indices {
            for (state, step) in best[position] {
                for end in RomajiParser.syllableEnds(in: characters, from: position) {
                    let (next, cost) = state.addingRomaji(to: step.cost)
                    relax(&best[end], next, Step(cost: cost, previous: (position, state)))
                }
                for end in position + 1...characters.count {
                    let word = String(characters[position..<end])
                    guard let rank = lexicon.rank(of: word) else { continue }
                    let price = log(Double(rank) * logWordCount)
                    let (next, cost) = state.addingEnglish(word, price: price, to: step.cost)
                    relax(&best[end], next, Step(cost: cost, previous: (position, state)))
                }
            }
        }
        let finished = best[characters.count].map { state, step in (state, step.cost.finishing(state)) }
        guard let (last, _) = finished.min(by: { $0.1 < $1.1 }) else {
            return nil
        }
        return pieces(characters, best, endingIn: last)
    }

    /// The most common English words that spell all the letters, as typed, or nil when some
    /// letters are no word. For letters the user wants as English even though they read as
    /// romaji (weare → we are).
    public func englishWords(_ letters: String) -> [String]? {
        let characters = Array(letters)
        // The cheapest words to each position, and where the last word starts
        var best: [(price: Double, start: Int)?] = Array(repeating: nil, count: characters.count + 1)
        best[0] = (0, 0)
        for start in characters.indices {
            guard let reached = best[start] else { continue }
            for end in start + 1...characters.count {
                guard let rank = lexicon.rank(of: String(characters[start..<end])) else { continue }
                let price = reached.price + log(Double(rank) * logWordCount)
                if best[end].map({ price < $0.price }) ?? true {
                    best[end] = (price, start)
                }
            }
        }
        guard best[characters.count] != nil else { return nil }
        var words: [String] = []
        var end = characters.count
        while end > 0, let (_, start) = best[end] {
            words.insert(String(characters[start..<end]), at: 0)
            end = start
        }
        return words
    }

    /// An unknown word followed by romaji that starts with a particle (grokga → grok | ga), or nil.
    /// The romaji is the longest end that reads as romaji; the word before it must have three
    /// letters or more.
    public func unknownStem(_ letters: String) -> [Piece]? {
        let characters = Array(letters)
        guard let start = characters.indices.dropFirst(3).first(where: { RomajiParser.isPlainRomaji(String(characters[$0...])) }) else {
            return nil
        }
        let romaji = String(characters[start...])
        guard FunctionWords.particles.keys.contains(where: romaji.hasPrefix) else {
            return nil
        }
        return [.english([String(characters[..<start])]), .romaji(romaji)]
    }

    private func relax(_ states: inout [State: Step], _ state: State, _ step: Step) {
        if let known = states[state], known.cost <= step.cost {
            return
        }
        states[state] = step
    }

    /// Follows the steps back from the end and joins syllables and words into pieces.
    private func pieces(_ characters: [Character], _ best: [[State: Step]], endingIn last: State) -> [Piece] {
        var spans: [(kind: State.Kind, text: String)] = []
        var position = characters.count
        var state = last
        while let (previousPosition, previousState) = best[position][state]?.previous {
            guard let kind = state.kind else {
                preconditionFailure("only the start has no kind, and nothing comes before it")
            }
            spans.insert((kind, String(characters[previousPosition..<position])), at: 0)
            position = previousPosition
            state = previousState
        }
        var pieces: [Piece] = []
        for span in spans {
            switch (span.kind, pieces.last) {
            case let (.romaji, .romaji(text)?):
                pieces[pieces.count - 1] = .romaji(text + span.text)
            case (.romaji, _):
                pieces.append(.romaji(span.text))
            case let (.english, .english(words)?):
                pieces[pieces.count - 1] = .english(words + [span.text])
            case (.english, _):
                pieces.append(.english([span.text]))
            }
        }
        return pieces
    }

}

extension WordCover {
    /// Where a way of reading has got to: what the last piece is, and what the rules need to
    /// know about its English words.
    struct State: Hashable {
        enum Kind: Hashable {
            case romaji
            case english
        }

        var kind: Kind?
        /// English words so far in the current English piece, up to 2.
        var englishWords = 0
        var lastWordReadsAsRomaji = false
        var lastWordIsAOrI = false

        static let start = State(kind: nil)

        func addingRomaji(to cost: Cost) -> (State, Cost) {
            var cost = cost
            if kind != .romaji {
                cost.pieces += 1
            }
            if kind == .english {
                cost.violations += (lastWordReadsAsRomaji ? 1 : 0) + (lastWordIsAOrI ? 1 : 0)
            }
            return (State(kind: .romaji), cost)
        }

        func addingEnglish(_ word: String, price: Double, to cost: Cost) -> (State, Cost) {
            var cost = cost
            let readsAsRomaji = RomajiParser.isPlainRomaji(word)
            let wordsBefore = kind == .english ? englishWords : 0
            if kind != .english {
                cost.pieces += 1
            }
            if kind == .romaji, readsAsRomaji {
                cost.violations += 1
            }
            if FunctionWords.all.contains(word.lowercased()), wordsBefore < 2 {
                cost.violations += 1
            }
            cost.english += price
            let next = State(
                kind: .english,
                englishWords: min(wordsBefore + 1, 2),
                lastWordReadsAsRomaji: readsAsRomaji,
                lastWordIsAOrI: ["a", "i"].contains(word.lowercased())
            )
            return (next, cost)
        }
    }

    struct Cost: Comparable {
        var violations = 0
        var pieces = 0
        var english = 0.0

        static func < (lhs: Cost, rhs: Cost) -> Bool {
            (lhs.violations, lhs.pieces, lhs.english) < (rhs.violations, rhs.pieces, rhs.english)
        }

        /// English cannot end in "a" or "i" at the end of the letters either.
        func finishing(_ state: State) -> Cost {
            var cost = self
            if state.kind == .english, state.lastWordIsAOrI {
                cost.violations += 1
            }
            return cost
        }
    }

    struct Step {
        var cost: Cost
        var previous: (position: Int, state: State)?
    }
}
