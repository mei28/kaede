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
        var pieces: [ConversionPiece] = []
        for item in Self.items(of: run) {
            switch item {
            case let .separator(text):
                pieces.appendVerbatim(text)
            case let .token(token):
                guard let segments = segmenter.segments(of: token) else { return .pass }
                for segment in segments {
                    if segment.kind.isJapanese {
                        pieces.append(.romaji(segment.text))
                    } else {
                        pieces.appendVerbatim(segment.text)
                    }
                }
            }
        }
        // A run of English only is already on screen as it should be
        let hasJapanese = pieces.contains { if case .romaji = $0 { true } else { false } }
        return hasJapanese ? .convert(pieces) : .pass
    }

    /// Splits the run into tokens and the spaces between them, in order.
    static func items(of run: Run) -> [RunItem] {
        let qwerty = Array(run.reading(in: .qwerty))
        let ebi = Array(run.reading(in: .ebi))
        var items: [RunItem] = []
        var start = 0
        while start < qwerty.count {
            let isSpace = qwerty[start] == " "
            var end = start
            while end < qwerty.count, (qwerty[end] == " ") == isSpace {
                end += 1
            }
            items.append(isSpace
                ? .separator(String(qwerty[start..<end]))
                : .token(Token(qwerty: String(qwerty[start..<end]), ebi: String(ebi[start..<end]))))
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
}
