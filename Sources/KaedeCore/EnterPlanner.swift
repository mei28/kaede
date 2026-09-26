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
        let pieces = Self.pieces(of: run.reading(in: .ebi))
        let allRomaji = pieces.allSatisfy { piece in
            if case let .romaji(chunk) = piece { RomajiParser.isRomaji(chunk) } else { true }
        }
        return allRomaji ? .convert(pieces) : .pass
    }

    /// Guards against Ebi misreadings of real English, such as "and" read as "age".
    private func isEnglish(_ run: Run) -> Bool {
        run.screenText.split(separator: " ").allSatisfy { lexicon.contains(String($0)) }
    }

    /// Splits a reading into space-free chunks and the spaces between them, in order.
    private static func pieces(of reading: String) -> [ConversionPiece] {
        var pieces: [ConversionPiece] = []
        var current = ""
        for character in reading {
            if !current.isEmpty, (character == " ") != (current.last == " ") {
                pieces.append(piece(current))
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty {
            pieces.append(piece(current))
        }
        return pieces
    }

    private static func piece(_ text: String) -> ConversionPiece {
        text.first == " " ? .verbatim(text) : .romaji(text)
    }
}
