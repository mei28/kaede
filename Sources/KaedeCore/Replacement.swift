/// Replaces the run on screen: delete what it typed, then type the converted pieces and the suffix.
public struct Replacement: Equatable, Sendable {
    /// The run's text on screen, which the replacement deletes.
    public var typed: String
    public var pieces: [ConversionPiece]
    /// Typed after the converted text.
    public var suffix: String

    public init(typed: String, pieces: [ConversionPiece], suffix: String = "") {
        self.typed = typed
        self.pieces = pieces
        self.suffix = suffix
    }

    /// Backspaces to send, one per character of the run's screen text.
    public var deleteCount: Int {
        typed.count
    }

    /// The text to type in place of the run. Throws when any chunk fails to convert.
    public func text(using converter: some KanaKanjiConverting) throws -> String {
        try Self.text(of: pieces, using: converter)
    }

    /// Candidates the user can step through after the conversion, up to `limit`, without
    /// duplicates: the conversion itself; then, one chunk at a time, that chunk's 2nd and 3rd
    /// candidates; then `alternatives` (other splits of the run) with first candidates.
    public func candidates(
        using converter: some KanaKanjiConverting,
        alternatives: [[ConversionPiece]],
        limit: Int
    ) throws -> [String] {
        let firsts = try pieces.map { try Self.text(of: [$0], using: converter) }
        var candidates = [firsts.joined()]
        func add(_ candidate: String) {
            if candidates.count < limit, !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }
        for (index, piece) in pieces.enumerated() {
            guard case let .romaji(chunk) = piece else { continue }
            for other in try converter.candidates(romaji: chunk, limit: Self.candidatesPerChunk).dropFirst() {
                var texts = firsts
                texts[index] = other
                add(texts.joined())
            }
        }
        for alternative in alternatives {
            add(try Self.text(of: alternative, using: converter))
        }
        return candidates
    }

    /// The first candidate plus two others: enough to fix a wrong homophone without a long cycle.
    static let candidatesPerChunk = 3

    private static func text(of pieces: [ConversionPiece], using converter: some KanaKanjiConverting) throws -> String {
        try pieces.map { piece in
            switch piece {
            case let .romaji(chunk): try converter.convert(romaji: chunk)
            case let .verbatim(text): text
            }
        }.joined()
    }
}
