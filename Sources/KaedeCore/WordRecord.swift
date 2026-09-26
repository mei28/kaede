/// How Kaede settled one word, for the opt-in record of typed words.
public struct WordRecord: Equatable, Sendable {
    /// The word's keys as they show in QWERTY.
    public var typed: String
    /// The question asked about it, if any ("language: …" or "spacing: …").
    public var question: String?
    /// Jev's answer to that question, if any.
    public var answer: String?
    /// What happened: "as typed", "replaced: <reading>" or "handed to azooKey: <reading>",
    /// with romaji left as romaji.
    public var outcome: String

    public init(typed: String, question: String?, answer: String?, outcome: String) {
        self.typed = typed
        self.question = question
        self.answer = answer
        self.outcome = outcome
    }
}
