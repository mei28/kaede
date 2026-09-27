/// What the word being typed is: English as it shows on screen, or Japanese romaji typed with
/// QWERTY or Ebi fingering. `keep` leaves the decision to later keys. The raw values are the
/// options Jev chooses from.
public enum Answer: String, CaseIterable, Sendable {
    case english
    case japaneseQwerty = "japanese_qwerty"
    case japaneseEbi = "japanese_ebi"
    case keep

    /// The layout a Japanese answer reads the keys in.
    public var layout: Layout? {
        switch self {
        case .japaneseQwerty: .qwerty
        case .japaneseEbi: .ebi
        case .english, .keep: nil
        }
    }
}

/// One of Jev's answers and how sure Jev is of it (0 to 1).
public struct Judgment: Equatable, Sendable {
    public var answer: Answer
    public var confidence: Double

    public init(answer: Answer, confidence: Double) {
        self.answer = answer
        self.confidence = confidence
    }
}
