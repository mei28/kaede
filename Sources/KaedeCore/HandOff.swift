/// Hands the end of a run to azooKey, so the user sees the conversion before committing it.
///
/// The run is deleted and `settled` converted and typed as final text, followed by `typedTail`
/// as typed. Then the input source switches to azooKey, `typedTail` is deleted, and `romaji` is
/// typed into azooKey followed by the Space that converts it.
public struct HandOff: Equatable, Sendable {
    /// The run's text on screen, which the hand-off deletes.
    public var typed: String
    /// Everything before the run's last Japanese part: converted and committed right away.
    public var settled: [ConversionPiece]
    /// The run's last Japanese part, typed into azooKey.
    public var romaji: String
    /// The keys of that part as they show on screen, kept when switching to azooKey fails.
    public var typedTail: String

    public init(typed: String, settled: [ConversionPiece], romaji: String, typedTail: String) {
        self.typed = typed
        self.settled = settled
        self.romaji = romaji
        self.typedTail = typedTail
    }
}
