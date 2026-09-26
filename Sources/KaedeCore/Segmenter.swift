/// Which layout a segment's keys were typed for, and which language they spell.
enum SegmentKind: CaseIterable, Sendable {
    case qwertyEnglish
    case qwertyJapanese
    case ebiJapanese

    var isJapanese: Bool {
        self != .qwertyEnglish
    }

    var isEbi: Bool {
        self == .ebiJapanese
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
    /// Charged each time the kind changes inside a token, so a split needs a reason.
    static let switchCost = 4.0

    let lexicon: EnglishLexicon

    /// The cheapest segmentation, or nil when no segmentation covers the whole token.
    func segments(of token: Token) -> [Segment]? {
        let readings = Readings(qwerty: Array(token.qwerty), ebi: Array(token.ebi))
        let count = readings.qwerty.count
        let kinds = SegmentKind.allCases
        // best[position][kind]: the cheapest way to reach position with a segment of kind ending there
        var best = Array(repeating: [Arrival?](repeating: nil, count: kinds.count), count: count + 1)

        for start in 0..<count {
            let arrivals: [(kind: SegmentKind?, cost: Double)] = start == 0
                ? [(nil, 0)]
                : kinds.indices.compactMap { index in best[start][index].map { (kinds[index], $0.cost) } }
            for arrival in arrivals {
                for (index, kind) in kinds.enumerated() {
                    // Two English words need a space between them, which would end the token
                    if arrival.kind == kind && !kind.isJapanese { continue }
                    let switchCost = arrival.kind == nil || arrival.kind == kind ? 0 : Self.switchCost
                    for step in steps(of: kind, from: start, in: readings) {
                        let cost = arrival.cost + switchCost + step.cost
                        if cost < best[step.end][index]?.cost ?? .infinity {
                            best[step.end][index] = Arrival(cost: cost, start: start, previousKind: arrival.kind)
                        }
                    }
                }
            }
        }

        guard let last = kinds.indices
            .filter({ best[count][$0] != nil })
            .min(by: { best[count][$0]!.cost < best[count][$1]!.cost })
        else {
            return nil
        }
        return segments(backtrackingFrom: kinds[last], best: best, readings: readings)
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
            let perStroke = lexicon.contains(String(reading[start..<end]))
                ? Self.knownEnglishStroke
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

    private func segments(backtrackingFrom lastKind: SegmentKind, best: [[Arrival?]], readings: Readings) -> [Segment] {
        let kinds = SegmentKind.allCases
        var ranges: [(kind: SegmentKind, range: Range<Int>)] = []
        var end = best.count - 1
        var kind: SegmentKind? = lastKind
        while let current = kind {
            let arrival = best[end][kinds.firstIndex(of: current)!]!
            ranges.append((current, arrival.start..<end))
            end = arrival.start
            kind = arrival.previousKind
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
