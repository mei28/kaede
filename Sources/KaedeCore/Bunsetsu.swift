/// A phrase of converted Japanese (文節) and the reading it was converted from.
public struct Bunsetsu: Equatable, Sendable {
    /// In hiragana.
    public var reading: String
    public var text: String

    public init(reading: String, text: String) {
        self.reading = reading
        self.text = text
    }
}
