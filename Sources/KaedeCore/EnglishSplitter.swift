/// Splits English typed without spaces ("allyouneedisattention") into words.
///
/// Only common words are used: with every dictionary word, rare ones break good splits
/// ("nee dis" instead of "need is") and a fifth of Japanese romaji reads as English words.
public struct EnglishSplitter: Sendable {
    /// Common words must cover at least this share of the letters. Below it the letters are
    /// probably not English prose (English run into Ebi-fingered Japanese, say).
    static let minimumCoverage = 0.75

    let commonWords: EnglishLexicon

    public init(commonWords: EnglishLexicon) {
        self.commonWords = commonWords
    }

    /// The letters as typed, split into common words. A stretch no common word covers (a word
    /// still being typed, a typo, a rare word) joins the word before it, so "exp" + "l" stays
    /// "expl"; at the very start it is a word of its own. The
    /// split leaves the fewest letters uncovered, then uses the fewest words. Nil unless
    /// there are two or more common words covering at least `minimumCoverage` of the letters.
    public func split(_ letters: String) -> [String]? {
        let characters = Array(letters)
        guard !characters.isEmpty else { return nil }
        // best[i][state]: the best way to spell the first i letters, ending in a common word
        // (state 0) or inside an uncovered stretch (state 1)
        var best = Array(repeating: [Step?](repeating: nil, count: 2), count: characters.count + 1)
        best[0][0] = Step(cost: Cost(uncovered: 0, words: 0), start: 0, previousState: 0)
        for start in characters.indices {
            for state in 0...1 {
                guard let reached = best[start][state] else { continue }
                for end in (start + 1)...characters.count where commonWords.contains(String(characters[start..<end])) {
                    Self.keep(Step(cost: reached.cost.adding(uncovered: 0, words: 1), start: start, previousState: state), at: &best[end][0])
                }
                // An uncovered letter starts a new word only after a common word
                let extends = state == 1
                Self.keep(Step(cost: reached.cost.adding(uncovered: 1, words: extends ? 0 : 1), start: start, previousState: state), at: &best[start + 1][1])
            }
        }
        let endState = [0, 1].filter { best[characters.count][$0] != nil }
            .min { best[characters.count][$0]!.cost < best[characters.count][$1]!.cost }!
        let final = best[characters.count][endState]!
        guard Double(characters.count - final.cost.uncovered) / Double(characters.count) >= Self.minimumCoverage else {
            return nil
        }
        let parts = Self.parts(backtrackingFrom: endState, best: best, characters: characters)
        guard parts.filter({ !$0.uncovered }).count >= 2 else { return nil }
        var words: [String] = []
        for part in parts {
            if part.uncovered, !words.isEmpty {
                words[words.count - 1] += part.text
            } else {
                words.append(part.text)
            }
        }
        return words
    }

    private struct Cost: Comparable {
        var uncovered: Int
        var words: Int

        func adding(uncovered: Int, words: Int) -> Cost {
            Cost(uncovered: self.uncovered + uncovered, words: self.words + words)
        }

        static func < (lhs: Cost, rhs: Cost) -> Bool {
            (lhs.uncovered, lhs.words) < (rhs.uncovered, rhs.words)
        }
    }

    private struct Step {
        var cost: Cost
        /// Where the step's letters start: the word's start, or the single uncovered letter's.
        var start: Int
        var previousState: Int
    }

    private static func keep(_ step: Step, at slot: inout Step?) {
        if slot == nil || step.cost < slot!.cost {
            slot = step
        }
    }

    /// Common words, and runs of uncovered letters joined into one part each, in order.
    private static func parts(backtrackingFrom endState: Int, best: [[Step?]], characters: [Character]) -> [(text: String, uncovered: Bool)] {
        var parts: [(text: String, uncovered: Bool)] = []
        var end = characters.count
        var state = endState
        var uncoveredEnd: Int?
        while end > 0 {
            let step = best[end][state]!
            if state == 1 {
                uncoveredEnd = uncoveredEnd ?? end
                if step.previousState == 0 {
                    parts.append((String(characters[step.start..<uncoveredEnd!]), true))
                    uncoveredEnd = nil
                }
            } else {
                parts.append((String(characters[step.start..<end]), false))
            }
            end = step.start
            state = step.previousState
        }
        return parts.reversed()
    }
}
