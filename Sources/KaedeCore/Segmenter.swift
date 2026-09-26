/// Which layout a segment's keys were typed for, and which language they spell.
enum SegmentKind: CaseIterable, Sendable {
    case qwertyEnglish
    case ebiEnglish
    case qwertyJapanese
    case ebiJapanese

    var isJapanese: Bool {
        self == .qwertyJapanese || self == .ebiJapanese
    }

    var isEbi: Bool {
        self == .ebiEnglish || self == .ebiJapanese
    }
}

/// A stretch of a token read in one layout as one language.
struct Segment: Equatable {
    var kind: SegmentKind
    /// The keys read in the segment's layout.
    var text: String
}

/// Splits a token into segments by layout and language, taking the cheapest split.
///
/// The search runs over (position, kind) states. Japanese advances one syllable at a time and
/// English one whole word at a time, so the work grows linearly with the token length.
struct Segmenter: Sendable {
    /// Costs per stroke. Known English is cheaper than Japanese so that words such as "and"
    /// stay English even though their Ebi reading ("age") is romaji.
    static let japaneseStroke = 1.0
    static let knownEnglishStroke = 0.5
    /// Unknown QWERTY words are allowed, as typed, but cost more than any Japanese reading.
    static let unknownEnglishStroke = 2.0
    /// English typed with Ebi fingering is rare, and Ebi is mostly Japanese: known words only,
    /// and dearer than Japanese so a romaji reading wins.
    static let ebiEnglishStroke = 1.5
    /// Charged each time the kind changes inside a token, so a split needs a reason.
    static let switchCost = 4.0

    let lexicon: EnglishLexicon

    /// The cheapest segmentation, or nil when no segmentation covers the whole token.
    func segments(of token: Token) -> [Segment]? {
        topSegmentations(of: token, count: 1).first
    }

    /// Up to `count` distinct segmentations, cheapest first. Ties keep the order the search
    /// finds them in, which switches kind at the earliest point.
    func topSegmentations(of token: Token, count: Int) -> [[Segment]] {
        let readings = Readings(qwerty: Array(token.qwerty), ebi: Array(token.ebi))
        let length = readings.qwerty.count
        let kinds = SegmentKind.allCases
        // Different syllable splits can spell the same segmentation, so for several results keep
        // a wider beam and drop duplicates at the end. One result needs only the best per state,
        // which keeps the tap's own planning as fast as a plain cheapest-path search.
        let beam = count == 1 ? 1 : count * 10
        // best[position][kind]: the cheapest ways to reach position with a segment of kind ending there
        var best = Array(repeating: [[Arrival]](repeating: [], count: kinds.count), count: length + 1)

        for start in 0..<length {
            for arrival in start == 0 ? [From(kind: nil, rank: 0, cost: 0)] : arrivals(at: best[start]) {
                for (index, kind) in kinds.enumerated() {
                    // Two English words need a space between them, which would end the token
                    if arrival.kind == kind && !kind.isJapanese { continue }
                    let switchCost = arrival.kind == nil || arrival.kind == kind ? 0 : Self.switchCost
                    for step in steps(of: kind, from: start, in: readings) {
                        let candidate = Arrival(
                            cost: arrival.cost + switchCost + step.cost,
                            start: start,
                            previousKind: arrival.kind,
                            previousRank: arrival.rank
                        )
                        Self.insert(candidate, into: &best[step.end][index], keeping: beam)
                    }
                }
            }
        }

        var results: [[Segment]] = []
        for end in arrivals(at: best[length]).sorted(by: { $0.cost < $1.cost }) {
            let segments = segments(backtrackingFrom: end, best: best, readings: readings)
            if !results.contains(segments) {
                results.append(segments)
            }
            if results.count == count { break }
        }
        return results
    }

    /// Where the search can continue from a position, rank by rank so that the best ways are
    /// extended first and keep their place among later ties.
    private func arrivals(at position: [[Arrival]]) -> [From] {
        let kinds = SegmentKind.allCases
        let deepest = position.map(\.count).max() ?? 0
        return (0..<deepest).flatMap { rank in
            kinds.indices.compactMap { index in
                rank < position[index].count ? From(kind: kinds[index], rank: rank, cost: position[index][rank].cost) : nil
            }
        }
    }

    /// Inserts after every arrival of equal or lower cost, so earlier finds win ties.
    private static func insert(_ arrival: Arrival, into list: inout [Arrival], keeping limit: Int) {
        let index = list.firstIndex { $0.cost > arrival.cost } ?? list.count
        guard index < limit else { return }
        list.insert(arrival, at: index)
        if list.count > limit {
            list.removeLast()
        }
    }

    private struct Readings {
        var qwerty: [Character]
        var ebi: [Character]

        func of(_ kind: SegmentKind) -> [Character] {
            kind.isEbi ? ebi : qwerty
        }
    }

    private struct Arrival {
        var cost: Double
        var start: Int
        var previousKind: SegmentKind?
        /// Which of the previous state's arrivals this one extends.
        var previousRank: Int
    }

    /// A state the search extends: a kind (nil at the token start), its rank there, and its cost.
    private struct From {
        var kind: SegmentKind?
        var rank: Int
        var cost: Double
    }

    private struct Step {
        var end: Int
        var cost: Double
    }

    private func steps(of kind: SegmentKind, from start: Int, in readings: Readings) -> [Step] {
        let reading = readings.of(kind)
        if kind.isJapanese {
            return RomajiParser.syllableEnds(in: reading, from: start).map { end in
                Step(end: end, cost: Double(end - start) * Self.japaneseStroke)
            }
        }
        var steps: [Step] = []
        var end = start
        while end < reading.count, reading[end].isLetter {
            end += 1
            let isKnown = lexicon.contains(String(reading[start..<end]))
            if kind.isEbi && !isKnown { continue }
            let perStroke = kind.isEbi ? Self.ebiEnglishStroke
                : isKnown ? Self.knownEnglishStroke
                : Self.unknownEnglishStroke
            steps.append(Step(end: end, cost: Double(end - start) * perStroke))
            // "," and "." after a word are English punctuation, not 、 and 。
            var punctuated = end
            while punctuated < reading.count, ",.".contains(reading[punctuated]) {
                punctuated += 1
                steps.append(Step(end: punctuated, cost: Double(punctuated - start) * perStroke))
            }
        }
        return steps
    }

    private func segments(backtrackingFrom end: From, best: [[[Arrival]]], readings: Readings) -> [Segment] {
        let kinds = SegmentKind.allCases
        var ranges: [(kind: SegmentKind, range: Range<Int>)] = []
        var position = best.count - 1
        var current: (kind: SegmentKind, rank: Int)? = end.kind.map { ($0, end.rank) }
        while let (kind, rank) = current {
            let arrival = best[position][kinds.firstIndex(of: kind)!][rank]
            ranges.append((kind, arrival.start..<position))
            position = arrival.start
            current = arrival.previousKind.map { ($0, arrival.previousRank) }
        }
        // Consecutive Japanese steps of one kind are syllables of the same segment
        var segments: [Segment] = []
        for (kind, range) in ranges.reversed() {
            let text = String(readings.of(kind)[range])
            if let last = segments.last, last.kind == kind {
                segments[segments.count - 1].text += text
            } else {
                segments.append(Segment(kind: kind, text: text))
            }
        }
        return segments
    }
}
