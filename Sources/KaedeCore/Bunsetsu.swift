/// A phrase of converted Japanese (文節) and the reading it was converted from.
public struct Bunsetsu: Equatable, Sendable {
    /// In hiragana.
    public var reading: String
    public var text: String
    /// English when the user chose the letters as English (weare → we are).
    public var language: Language
    /// How many letters of its clause's romaji it was converted from; nil when its border falls
    /// inside a spelling (てん | き of tenki, where the k settles ん).
    public var letterCount: Int?
    /// The user picked its candidate or moved its border.
    public var isChosen: Bool

    public init(reading: String, text: String, language: Language = .japanese, letterCount: Int?, isChosen: Bool = false) {
        self.reading = reading
        self.text = text
        self.language = language
        self.letterCount = letterCount
        self.isChosen = isChosen
    }
}
