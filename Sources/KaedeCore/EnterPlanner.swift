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
public struct EnterPlanner: Sendable {
    /// Too few strokes to tell Japanese from a stray key.
    static let minimumStrokes = 3

    let segmenter: Segmenter

    public init(lexicon: EnglishLexicon) {
        segmenter = Segmenter(lexicon: lexicon)
    }

    public func plan(_ run: Run) -> EnterDecision {
        if run.strokeCount < Self.minimumStrokes {
            return .pass
        }
        let items = Self.items(of: run)
        let segments: [[Segment]] = items.map { item in
            if case let .token(token) = item { segmentsOrAsTyped(token) } else { [] }
        }
        return Self.decision(items: items, segments: segments)
    }

    /// A token nothing can read stays as typed.
    private func segmentsOrAsTyped(_ token: Token) -> [Segment] {
        segmenter.segments(of: token) ?? [Segment(kind: .qwertyEnglish, text: token.qwerty)]
    }

    /// Assembles the pieces for the run, given the segments chosen for each of its tokens
    /// (separators get an empty list).
    private static func decision(items: [RunItem], segments: [[Segment]]) -> EnterDecision {
        var pieces: [ConversionPiece] = []
        // Whether any segment reads differently from what the keys already put on screen
        var changesScreen = false
        for (item, segments) in zip(items, segments) {
            if case let .separator(text) = item {
                pieces.appendVerbatim(text)
            }
            for segment in segments {
                changesScreen = changesScreen || segment.kind != .qwertyEnglish
                if segment.kind.isJapanese {
                    pieces.appendRomaji(segment.text)
                } else {
                    pieces.appendVerbatim(segment.text)
                }
            }
        }
        return changesScreen ? .convert(pieces) : .pass
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
