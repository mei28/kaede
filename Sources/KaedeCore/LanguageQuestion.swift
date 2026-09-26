/// What Kaede asks about a word the rules cannot settle: is it Japanese or English?
public struct LanguageQuestion: Equatable, Sendable {
    /// The word's keys as they show in QWERTY.
    public var typed: String
    /// The same keys read in the Ebi layout.
    public var ebiReading: String
    /// Recent text typed before the word in the same field, as Kaede produced it.
    public var textBefore: String

    public init(typed: String, ebiReading: String, textBefore: String) {
        self.typed = typed
        self.ebiReading = ebiReading
        self.textBefore = textBefore
    }
}

/// The answer to a `LanguageQuestion`.
public enum LanguageAnswer: Equatable, Sendable {
    case japanese
    case english
    /// No confident answer: the rules' own reading stands.
    case undecided
    /// No answer at all (timeout, network or API error): the word stays as typed.
    case failed
}
