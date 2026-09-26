/// A piece of the text that replaces the run.
public enum ConversionPiece: Equatable, Sendable {
    /// Romaji to convert to kana-kanji.
    case romaji(String)
    /// Spaces, typed out as they were.
    case verbatim(String)
}

/// What to do with an Enter press.
public enum EnterDecision: Equatable, Sendable {
    /// Let Enter through unchanged.
    case pass
    /// Stop Enter and replace the run with these pieces, converted.
    case convert([ConversionPiece])
}

/// Decides, from rules alone, whether a run is Japanese typed with Ebi fingering.
/// A language an ambiguous word can be settled to.
public enum Language: Sendable {
    case japanese
    case english
}

public struct EnterPlanner: Sendable {
    /// Too few strokes to tell Japanese from a stray key.
    static let minimumStrokes = 3

    let segmenter: Segmenter

    public init(lexicon: EnglishLexicon) {
        segmenter = Segmenter(lexicon: lexicon)
    }

    /// With a preference, ambiguous words (see `isAmbiguous`) are read in that language.
    public func plan(_ run: Run, preferring language: Language? = nil) -> EnterDecision {
        if run.strokeCount < Self.minimumStrokes {
            return .pass
        }
        let items = Self.items(of: run)
        return Self.decision(items: items, segments: segments(of: items, preferring: language))
    }

    /// Distinct plans for a run that converts: the plan itself first, then plans that differ from
    /// it in one token, using that token's 2nd to `perToken`-th segmentation. Empty when the
    /// run passes. They become candidates the user can step through after a conversion.
    public func alternatives(for run: Run, perToken: Int) -> [[ConversionPiece]] {
        guard case .convert = plan(run) else { return [] }
        let items = Self.items(of: run)
        var alternatives: [[ConversionPiece]] = []
        for choice in choices(of: items, perToken: perToken) {
            if case let .convert(pieces) = Self.decision(items: items, segments: choice), !alternatives.contains(pieces) {
                alternatives.append(pieces)
            }
        }
        return alternatives
    }

    /// How to hand the run to azooKey: everything before its last Japanese part is settled, and
    /// that part (consecutive Japanese segments, whatever their layout) goes to azooKey.
    /// Nil when the run does not end in Japanese, or is too short to convert.
    public func handOff(for run: Run, preferring language: Language? = nil) -> HandOff? {
        guard run.strokeCount >= Self.minimumStrokes else { return nil }
        let items = Self.items(of: run)
        var segments = segments(of: items, preferring: language)
        guard case .token = items.last, let last = segments.indices.last else { return nil }
        let tailCount = segments[last].reversed().prefix { $0.kind.isJapanese }.count
        guard tailCount > 0 else { return nil }
        let tail = segments[last].suffix(tailCount)
        segments[last].removeLast(tailCount)
        var romaji: [ConversionPiece] = []
        for segment in tail {
            romaji.appendRomaji(segment.text)
        }
        guard case let .romaji(text) = romaji.first else {
            preconditionFailure("Japanese segments always assemble into one romaji piece")
        }
        let typed = run.screenText
        return HandOff(
            typed: typed,
            settled: Self.assemble(items: items, segments: segments).pieces,
            romaji: text,
            // One screen character per key, so the tail's length in keys is its segments' length
            typedTail: String(typed.suffix(tail.map(\.text.count).reduce(0, +)))
        )
    }

    /// Whether the rules cannot settle the run's language: one of its words is a known English
    /// word as typed and also reads, whole, as romaji in QWERTY or Ebi ("are" or あれ, "has" or
    /// Ebi かお). Partial readings do not count; almost every word has some.
    public func isAmbiguous(_ run: Run) -> Bool {
        guard run.strokeCount >= Self.minimumStrokes else { return false }
        return Self.items(of: run).contains { item in
            guard case let .token(token) = item else { return false }
            return isAmbiguous(token)
        }
    }

    private func isAmbiguous(_ token: Token) -> Bool {
        segmenter.lexicon.contains(token.qwerty)
            && (RomajiParser.isRomaji(token.qwerty) || RomajiParser.isRomaji(token.ebi))
    }

    /// The best segments, except that ambiguous words follow `language`: English keeps them as
    /// typed; Japanese reads them whole as romaji, in QWERTY when the letters on screen already
    /// are romaji, otherwise in Ebi.
    private func segments(of items: [RunItem], preferring language: Language?) -> [[Segment]] {
        guard let language else { return bestSegments(of: items) }
        return zip(items, bestSegments(of: items)).map { item, best in
            guard case let .token(token) = item, isAmbiguous(token) else { return best }
            switch language {
            case .english:
                return [Segment(kind: .qwertyEnglish, text: token.qwerty)]
            case .japanese:
                return RomajiParser.isRomaji(token.qwerty)
                    ? [Segment(kind: .qwertyJapanese, text: token.qwerty)]
                    : [Segment(kind: .ebiJapanese, text: token.ebi)]
            }
        }
    }

    /// The best segments for each item (separators get an empty list).
    private func bestSegments(of items: [RunItem]) -> [[Segment]] {
        items.map { item in
            if case let .token(token) = item { segmentsOrAsTyped(token) } else { [] }
        }
    }

    /// The best segments for every item, then choices that differ from it in one token, using
    /// that token's 2nd to `perToken`-th segmentation.
    private func choices(of items: [RunItem], perToken: Int) -> [[[Segment]]] {
        let options: [[[Segment]]] = items.map { item in
            guard case let .token(token) = item else { return [[]] }
            let top = segmenter.topSegmentations(of: token, count: perToken)
            return top.isEmpty ? [segmentsOrAsTyped(token)] : top
        }
        let best = options.map { $0[0] }
        var choices = [best]
        for (index, tokenOptions) in options.enumerated() {
            for option in tokenOptions.dropFirst() {
                var choice = best
                choice[index] = option
                choices.append(choice)
            }
        }
        return choices
    }

    /// A token nothing can read stays as typed.
    private func segmentsOrAsTyped(_ token: Token) -> [Segment] {
        segmenter.segments(of: token) ?? [Segment(kind: .qwertyEnglish, text: token.qwerty)]
    }

    /// Assembles the pieces for the run, given the segments chosen for each of its tokens
    /// (separators get an empty list).
    private static func decision(items: [RunItem], segments: [[Segment]]) -> EnterDecision {
        let (pieces, changesScreen) = assemble(items: items, segments: segments)
        return changesScreen ? .convert(pieces) : .pass
    }

    /// The pieces for the items and their chosen segments, and whether any segment reads
    /// differently from what the keys already put on screen.
    private static func assemble(items: [RunItem], segments: [[Segment]]) -> (pieces: [ConversionPiece], changesScreen: Bool) {
        var pieces: [ConversionPiece] = []
        for (item, segments) in zip(items, segments) {
            if case let .separator(text) = item {
                pieces.appendVerbatim(text)
            }
            for segment in segments {
                if segment.kind.isJapanese {
                    pieces.appendRomaji(segment.text)
                } else {
                    pieces.appendVerbatim(segment.text)
                }
            }
        }
        // Adjacent verbatim text merges, so a run left as typed assembles into its screen text alone
        let screen = items.map { item in
            switch item {
            case let .separator(text): text
            case let .token(token): token.qwerty
            }
        }.joined()
        return (pieces, pieces != (screen.isEmpty ? [] : [.verbatim(screen)]))
    }

    /// Splits the run into tokens of layout keys and the literals between them, in order.
    /// Literals (space, digits, "-") are kept as typed: no layout or romaji reading applies to them.
    static func items(of run: Run) -> [RunItem] {
        let qwerty = Array(run.reading(in: .qwerty))
        let ebi = Array(run.reading(in: .ebi))
        let isStroke = run.elements.map { if case .stroke = $0 { true } else { false } }
        var items: [RunItem] = []
        var start = 0
        while start < qwerty.count {
            var end = start
            while end < qwerty.count, isStroke[end] == isStroke[start] {
                end += 1
            }
            items.append(isStroke[start]
                ? .token(Token(qwerty: String(qwerty[start..<end]), ebi: String(ebi[start..<end])))
                : .separator(String(qwerty[start..<end])))
            start = end
        }
        return items
    }
}

private extension [ConversionPiece] {
    /// Appends text to the last piece when it is verbatim too, so text kept as typed stays in one piece.
    mutating func appendVerbatim(_ text: String) {
        if case let .verbatim(previous) = last {
            self[count - 1] = .verbatim(previous + text)
        } else {
            append(.verbatim(text))
        }
    }

    /// Joins Japanese typed in different layouts into one piece: conversion does not depend on
    /// the layout, and converting the whole phrase at once gives the converter more context.
    mutating func appendRomaji(_ text: String) {
        if case let .romaji(previous) = last {
            self[count - 1] = .romaji(Self.hatsuonKept(previous, before: text) + text)
        } else {
            append(.romaji(text))
        }
    }

    /// A segment ending in a lone "n" meant ん. Joined to text starting with a vowel, y or n,
    /// the IME would read the n with that text instead ("hon" + "nihon" as ほんいほん), so spell it "nn".
    private static func hatsuonKept(_ romaji: String, before next: String) -> String {
        let trailingNs = romaji.reversed().prefix { $0 == "n" }.count
        guard trailingNs % 2 == 1, let first = next.first, "aiueoyn".contains(first) else {
            return romaji
        }
        return romaji + "n"
    }
}
