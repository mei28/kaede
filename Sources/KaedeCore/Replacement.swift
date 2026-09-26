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
        try pieces.map { piece in
            switch piece {
            case let .romaji(chunk): try converter.convert(romaji: chunk)
            case let .verbatim(text): text
            }
        }.joined()
    }
}
