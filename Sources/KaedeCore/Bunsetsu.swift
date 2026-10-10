/// A phrase of converted Japanese (文節) and the reading it was converted from.
public struct Bunsetsu: Equatable, Sendable {
    /// In hiragana.
    public var reading: String
    public var text: String
    /// English when the user chose the letters as English (weare → we are).
    public var language: Language

    public init(reading: String, text: String, language: Language = .japanese) {
        self.reading = reading
        self.text = text
        self.language = language
    }
}
