/// What Kaede asks about a word the rules cannot settle: is it Japanese or English?
public struct LanguageQuestion: Equatable, Sendable {
    /// The word's keys as they show in QWERTY.
    public var typed: String
    /// The same keys read in the Ebi layout.
    public var ebiReading: String
    /// Recent text typed before the word in the same field, as Kaede produced it.
    public var textBefore: String
    /// How the rules read the word, part by part ("api (English) + hamadate (Japanese romaji)").
    public var ruleReading: String

    public init(typed: String, ebiReading: String, textBefore: String, ruleReading: String) {
        self.typed = typed
        self.ebiReading = ebiReading
        self.textBefore = textBefore
        self.ruleReading = ruleReading
    }
}

/// What Kaede asks about English typed without spaces: respace it, or keep it as typed?
public struct SpacingQuestion: Equatable, Sendable {
    /// The word as it shows in QWERTY ("localhost").
    public var typed: String
    /// The rules' respacing ("local host").
    public var respaced: String
    /// Recent text typed before the word in the same field.
    public var textBefore: String

    public init(typed: String, respaced: String, textBefore: String) {
        self.typed = typed
        self.respaced = respaced
        self.textBefore = textBefore
    }
}

/// The answer to a `SpacingQuestion`.
public enum SpacingAnswer: Equatable, Sendable {
    /// English prose: put the spaces in.
    case respace
    /// A name, code, a command or a URL: keep it as typed.
    case keepAsTyped
    /// No confident answer: the rules respace it.
    case undecided
    /// No answer at all: the word stays as typed.
    case failed
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
