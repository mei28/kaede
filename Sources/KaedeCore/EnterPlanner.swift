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

    let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon) {
        self.lexicon = lexicon
    }

    public func plan(_ run: Run) -> EnterDecision {
        if run.strokeCount < Self.minimumStrokes || isEnglish(run) {
            return .pass
        }
        var pieces: [ConversionPiece] = []
        for item in Self.items(of: run) {
            switch item {
            case let .separator(text):
                pieces.append(.verbatim(text))
            case let .token(token):
                guard RomajiParser.isRomaji(token.ebi) else { return .pass }
                pieces.append(.romaji(token.ebi))
            }
        }
        return .convert(pieces)
    }

    /// Guards against Ebi misreadings of real English, such as "and" read as "age".
    private func isEnglish(_ run: Run) -> Bool {
        run.screenText.split(separator: " ").allSatisfy { lexicon.contains(String($0)) }
    }

    /// A space-free stretch of the run, read in both layouts (one character per element).
    struct Token: Equatable {
        var qwerty: String
        var ebi: String
    }

    enum Item: Equatable {
        case token(Token)
        case separator(String)
    }

    /// Splits the run into tokens and the spaces between them, in order.
    static func items(of run: Run) -> [Item] {
        let qwerty = Array(run.reading(in: .qwerty))
        let ebi = Array(run.reading(in: .ebi))
        var items: [Item] = []
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
